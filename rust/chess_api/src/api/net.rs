//! LAN multiplayer bridge: mDNS discovery + a TCP/JSON session.
//!
//! Networking runs on a shared tokio runtime. `net_host`/`net_join` return a
//! `Stream<NetEvent>` (run off the UI thread); the `net_send_*` commands push
//! protocol messages to the active connection. Every incoming move is validated
//! against a local `chess_core` game; illegal/out-of-turn moves are rejected.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use chess_core::{Color, Game, GameStatus, Piece, Variant};
use chess_net::{Message, PROTOCOL_VERSION};
use flutter_rust_bridge::frb;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::tcp::OwnedWriteHalf;
use tokio::net::{TcpListener, TcpStream};
use tokio::runtime::Runtime;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

use crate::frb_generated::StreamSink;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum NetEventKind {
    Connected,
    Move,
    Resign,
    DrawOffer,
    DrawResponse,
    Chat,
    Disconnected,
    Error,
    // Bughouse (host-authoritative star).
    BugJoin,   // a player joined the host's lobby
    BugStart,  // seats assigned, match begins
    BugMove,   // a move/drop on a board
    BugPass,   // a captured piece fed to a partner's reserve
    BugResult, // the match ended
    // 4-player chess (host-authoritative star).
    FourJoin,
    FourStart,
    FourMove,
    FourResult,
}

/// A flattened event (no payload enum, so no `freezed` needed on Dart).
#[derive(Clone, Debug)]
pub struct NetEvent {
    pub kind: NetEventKind,
    pub you_are_white: bool,
    pub white_name: String,
    pub black_name: String,
    pub base_minutes: u32,
    pub increment_seconds: u32,
    pub fen: String,
    pub uci: String,
    pub white_ms: i64,
    pub black_ms: i64,
    pub draw_accepted: bool,
    pub text: String,
    /// Variant code agreed for this game (e.g. "standard", "crazyhouse").
    pub variant: String,
    // ---- Bughouse fields ----
    pub board: u32,        // 0=A, 1=B
    pub to_board: u32,     // BugPass target board
    pub to_color: u32,     // BugPass target colour (0=white, 1=black)
    pub piece: u32,        // BugPass piece (0=Pawn..4=Queen)
    pub seat: u32,         // a seat index (0..3)
    pub winning_team: u32, // BugResult (1 or 2)
    pub your_seats: Vec<u32>, // seats this client controls (BugStart)
    pub seats: Vec<String>,   // the four player names (BugStart)
}

impl NetEvent {
    fn of(kind: NetEventKind) -> NetEvent {
        NetEvent {
            kind,
            you_are_white: false,
            white_name: String::new(),
            black_name: String::new(),
            base_minutes: 0,
            increment_seconds: 0,
            fen: String::new(),
            uci: String::new(),
            white_ms: 0,
            black_ms: 0,
            draw_accepted: false,
            text: String::new(),
            variant: String::new(),
            board: 0,
            to_board: 0,
            to_color: 0,
            piece: 0,
            seat: 0,
            winning_team: 0,
            your_seats: Vec::new(),
            seats: Vec::new(),
        }
    }
}

/// Wire code → variant (the stable string sent in the Start message).
fn variant_from_code(s: &str) -> Variant {
    match s {
        "three_check" => Variant::ThreeCheck,
        "king_of_the_hill" => Variant::KingOfTheHill,
        "chess960" => Variant::Chess960,
        "atomic" => Variant::Atomic,
        "crazyhouse" => Variant::Crazyhouse,
        "bughouse" => Variant::Bughouse,
        "fog_of_war" => Variant::FogOfWar,
        _ => Variant::Standard,
    }
}

/// Build the move-validation game for `fen` with `variant` applied (the FEN may
/// be a Chess960 X-FEN that already carries it; setting it again is harmless).
fn variant_game(fen: &str, variant: Variant) -> Result<Game, String> {
    let mut pos = chess_core::parse_fen(fen).map_err(|e| e.to_string())?;
    pos.variant = variant;
    Ok(Game::from_position(pos))
}

/// A host discovered on the LAN.
#[derive(Clone, Debug)]
pub struct NetHost {
    pub name: String,
    pub addr: String,
    pub time_control: String,
}

fn runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

/// Outgoing-command sender for the active session, tagged with a generation so
/// a finishing session only clears the slot if it still owns it (a newer
/// session won't be wiped by an older one's cleanup).
/// Lock a mutex, recovering from poisoning (a prior holder panicked) instead of
/// cascading the panic. The data these mutexes protect — channel slots and seat
/// assignments — is always left in a consistent state, so recovery is safe.
fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

type CmdSlot = Mutex<Option<(u64, UnboundedSender<Message>)>>;

fn cmd_slot() -> &'static CmdSlot {
    static C: OnceLock<CmdSlot> = OnceLock::new();
    C.get_or_init(|| Mutex::new(None))
}

static SESSION_GEN: AtomicU64 = AtomicU64::new(0);

/// Signals a waiting host (parked at accept) or a prior session to stop, so a
/// new session / leave doesn't leak the old listener + mDNS advertisement.
fn session_cancel() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

static BROWSE_STOP: AtomicBool = AtomicBool::new(false);

// ---- Discovery ----------------------------------------------------------

/// Browse for LAN hosts. Streams each resolved host until `net_stop_browse`.
pub fn net_browse(sink: StreamSink<NetHost>) -> Result<(), String> {
    BROWSE_STOP.store(false, Ordering::Relaxed);
    let (browser, rx) = chess_net::browse().map_err(|e| e.to_string())?;
    loop {
        if BROWSE_STOP.load(Ordering::Relaxed) {
            break;
        }
        match rx.recv_timeout(Duration::from_millis(400)) {
            Ok(h) => {
                let ok = sink
                    .add(NetHost {
                        name: h.name,
                        addr: h.addr,
                        time_control: h.time_control,
                    })
                    .is_ok();
                if !ok {
                    break;
                }
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
        }
    }
    drop(browser);
    Ok(())
}

#[frb(sync)]
pub fn net_stop_browse() {
    BROWSE_STOP.store(true, Ordering::Relaxed);
}

// ---- Session ------------------------------------------------------------

/// Host a game: advertise on mDNS, accept one peer, then run the session.
pub fn net_host(
    name: String,
    base_minutes: u32,
    increment_seconds: u32,
    host_white: bool,
    variant: String,
    chess960_index: u32,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    session_cancel().notify_waiters(); // end any prior/waiting session first
    runtime().block_on(async move {
        match host_task(
            name,
            base_minutes,
            increment_seconds,
            host_white,
            variant,
            chess960_index,
            &sink,
        )
        .await
        {
            Ok(()) => {}
            Err(e) => {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

/// Join a host at `addr` ("ip:port").
pub fn net_join(addr: String, name: String, sink: StreamSink<NetEvent>) -> Result<(), String> {
    session_cancel().notify_waiters();
    runtime().block_on(async move {
        match join_task(addr, name, &sink).await {
            Ok(()) => {}
            Err(e) => {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn host_task(
    name: String,
    base: u32,
    inc: u32,
    host_white: bool,
    variant: String,
    chess960_index: u32,
    sink: &StreamSink<NetEvent>,
) -> Result<(), String> {
    let listener = TcpListener::bind("0.0.0.0:0").await.map_err(es)?;
    let port = listener.local_addr().map_err(es)?.port();
    let _adv = chess_net::advertise(&name, port, base, inc).map_err(|e| e.to_string())?;

    // Wait for a peer, but bail (dropping listener + mDNS) if the user cancels.
    let stream = tokio::select! {
        r = listener.accept() => r.map_err(es)?.0,
        _ = session_cancel().notified() => return Ok(()),
    };
    let (rd, mut wr) = stream.into_split();
    let mut lines = BufReader::new(rd).lines();

    // Handshake: read Hello, arbitrate, send Start.
    let hello = read_message(&mut lines).await?;
    let peer = match hello {
        Message::Hello {
            name,
            protocol_version,
            ..
        } => {
            if protocol_version != PROTOCOL_VERSION {
                let _ = wr.write_all(Message::Bye.encode().as_bytes()).await;
                return Err("incompatible protocol version".into());
            }
            name
        }
        _ => return Err("expected hello".into()),
    };

    // Assign colours from the host's choice (random is resolved to a concrete
    // value on the Dart side, so this is just a bool here).
    let (white_name, black_name) = if host_white {
        (name.clone(), peer.clone())
    } else {
        (peer.clone(), name.clone())
    };

    let var = variant_from_code(&variant);
    let fen = if var == Variant::Chess960 {
        chess_core::to_fen(&chess_core::Position::chess960(chess960_index as u16))
    } else {
        chess_core::START_FEN.to_string()
    };
    let start = Message::Start {
        white_name: white_name.clone(),
        black_name: black_name.clone(),
        you_are_white: !host_white, // from the client's perspective
        base_minutes: base,
        increment_seconds: inc,
        fen: fen.clone(),
        variant: variant.clone(),
    };
    wr.write_all(start.encode().as_bytes()).await.map_err(es)?;

    let mut connected = NetEvent::of(NetEventKind::Connected);
    connected.you_are_white = host_white;
    connected.white_name = white_name;
    connected.black_name = black_name;
    connected.base_minutes = base;
    connected.increment_seconds = inc;
    connected.fen = fen.clone();
    connected.variant = variant;
    if sink.add(connected).is_err() {
        return Ok(());
    }

    drive(lines, wr, sink, variant_game(&fen, var)?).await;
    Ok(())
}

async fn join_task(addr: String, name: String, sink: &StreamSink<NetEvent>) -> Result<(), String> {
    let stream = TcpStream::connect(&addr).await.map_err(es)?;
    let (rd, mut wr) = stream.into_split();
    let mut lines = BufReader::new(rd).lines();

    let hello = Message::Hello {
        name,
        protocol_version: PROTOCOL_VERSION,
        base_minutes: 0,
        increment_seconds: 0,
    };
    wr.write_all(hello.encode().as_bytes()).await.map_err(es)?;

    let start = read_message(&mut lines).await?;
    let (you_white, wn, bn, base, inc, fen, variant) = match start {
        Message::Start {
            white_name,
            black_name,
            you_are_white,
            base_minutes,
            increment_seconds,
            fen,
            variant,
        } => (
            you_are_white,
            white_name,
            black_name,
            base_minutes,
            increment_seconds,
            fen,
            variant,
        ),
        Message::Bye => return Err("host rejected the connection".into()),
        _ => return Err("expected start".into()),
    };

    let mut connected = NetEvent::of(NetEventKind::Connected);
    connected.you_are_white = you_white;
    connected.white_name = wn;
    connected.black_name = bn;
    connected.base_minutes = base;
    connected.increment_seconds = inc;
    connected.fen = fen.clone();
    connected.variant = variant.clone();
    if sink.add(connected).is_err() {
        return Ok(());
    }

    drive(lines, wr, sink, variant_game(&fen, variant_from_code(&variant))?).await;
    Ok(())
}

/// The connection event loop: relays commands, validates incoming moves, and
/// runs a heartbeat to detect disconnects.
async fn drive(
    mut lines: tokio::io::Lines<BufReader<tokio::net::tcp::OwnedReadHalf>>,
    mut wr: OwnedWriteHalf,
    sink: &StreamSink<NetEvent>,
    mut game: Game,
) {
    let (tx, mut cmd_rx): (UnboundedSender<Message>, UnboundedReceiver<Message>) =
        tokio::sync::mpsc::unbounded_channel();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(cmd_slot()) = Some((gen, tx));

    let mut heartbeat = tokio::time::interval(Duration::from_secs(3));
    heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut last_seen = Instant::now();

    loop {
        tokio::select! {
            _ = heartbeat.tick() => {
                if last_seen.elapsed() > Duration::from_secs(12) {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "opponent disconnected (timeout)".into();
                    let _ = sink.add(ev);
                    break;
                }
                if wr.write_all(Message::Ping { t: 0 }.encode().as_bytes()).await.is_err() {
                    break;
                }
            }
            cmd = cmd_rx.recv() => {
                let Some(msg) = cmd else { break };
                if let Message::Move { ref uci, .. } = msg {
                    if let Ok(mv) = game.pos.parse_uci(uci) {
                        game.make_move(mv);
                    }
                }
                let bye = matches!(msg, Message::Bye);
                if wr.write_all(msg.encode().as_bytes()).await.is_err() {
                    break;
                }
                if bye {
                    break;
                }
            }
            line = lines.next_line() => {
                match line {
                    Ok(Some(l)) => {
                        last_seen = Instant::now();
                        if !handle_incoming(&l, &mut game, sink, &mut wr).await {
                            break;
                        }
                    }
                    Ok(None) | Err(_) => {
                        let mut ev = NetEvent::of(NetEventKind::Disconnected);
                        ev.text = "connection closed".into();
                        let _ = sink.add(ev);
                        break;
                    }
                }
            }
            _ = session_cancel().notified() => {
                break; // a new session started or the user left
            }
        }
    }
    // Only clear the slot if this session still owns it (don't wipe a newer one).
    let mut slot = lock(cmd_slot());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
}

/// Returns false when the loop should stop (e.g. peer said Bye).
async fn handle_incoming(
    line: &str,
    game: &mut Game,
    sink: &StreamSink<NetEvent>,
    wr: &mut OwnedWriteHalf,
) -> bool {
    let msg = match Message::decode(line) {
        Ok(m) => m,
        Err(_) => {
            // Surface malformed protocol instead of silently dropping it, so a
            // desync (or a hostile/corrupt peer) becomes visible to the user
            // rather than looking like a frozen game. Line framing is intact, so
            // keep the connection alive.
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = "malformed message from peer".to_string();
            let _ = sink.add(ev);
            return true;
        }
    };
    match msg {
        Message::Move {
            uci,
            white_ms,
            black_ms,
            ..
        } => match game.pos.parse_uci(&uci) {
            Ok(mv) => {
                game.make_move(mv);
                let mut ev = NetEvent::of(NetEventKind::Move);
                ev.uci = uci;
                ev.white_ms = white_ms;
                ev.black_ms = black_ms;
                let _ = sink.add(ev);
            }
            Err(_) => {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = format!("rejected illegal/out-of-turn move: {uci}");
                let _ = sink.add(ev);
            }
        },
        Message::Resign => {
            let _ = sink.add(NetEvent::of(NetEventKind::Resign));
        }
        Message::DrawOffer => {
            let _ = sink.add(NetEvent::of(NetEventKind::DrawOffer));
        }
        Message::DrawResponse { accepted } => {
            let mut ev = NetEvent::of(NetEventKind::DrawResponse);
            ev.draw_accepted = accepted;
            let _ = sink.add(ev);
        }
        Message::Chat { text } => {
            let mut ev = NetEvent::of(NetEventKind::Chat);
            ev.text = text;
            let _ = sink.add(ev);
        }
        Message::Ping { t } => {
            let _ = wr.write_all(Message::Pong { t }.encode().as_bytes()).await;
        }
        Message::Pong { .. } => {}
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "opponent left".into();
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

async fn read_message(
    lines: &mut tokio::io::Lines<BufReader<tokio::net::tcp::OwnedReadHalf>>,
) -> Result<Message, String> {
    match lines.next_line().await.map_err(es)? {
        Some(l) => Message::decode(&l).map_err(|e| e.to_string()),
        None => Err("connection closed during handshake".into()),
    }
}

fn es<E: std::fmt::Display>(e: E) -> String {
    e.to_string()
}

// ---- Commands (sent from Dart) -----------------------------------------

fn send(msg: Message) {
    if let Some((_, tx)) = lock(cmd_slot()).as_ref() {
        let _ = tx.send(msg);
    }
}

#[frb(sync)]
pub fn net_send_move(uci: String, white_ms: i64, black_ms: i64) {
    send(Message::Move {
        uci,
        ply: 0,
        white_ms,
        black_ms,
    });
}

#[frb(sync)]
pub fn net_resign() {
    send(Message::Resign);
}

#[frb(sync)]
pub fn net_offer_draw() {
    send(Message::DrawOffer);
}

#[frb(sync)]
pub fn net_respond_draw(accept: bool) {
    send(Message::DrawResponse { accepted: accept });
}

#[frb(sync)]
pub fn net_send_chat(text: String) {
    send(Message::Chat { text });
}

#[frb(sync)]
pub fn net_leave() {
    send(Message::Bye); // tell a connected peer (live game)
    session_cancel().notify_waiters(); // abort a still-waiting host / break drive
}

// ===== Bughouse: host-authoritative star (4 seats, up to 3 joiners) =====
//
// Seats: 0=A-White, 1=A-Black, 2=B-White, 3=B-Black. Teams: 1 = {0,3}, 2 = {1,2}.
// The host runs both boards as the authority: it validates each board-tagged
// move, routes the captured piece to the partner's reserve, and broadcasts the
// move + pass + result to every client. Clients mirror; they send only their
// own seats' input. Clock values are client-reported and relayed (not host-
// authoritative on time), matching the 1-peer relay.

fn seat_board(seat: u8) -> usize {
    if seat < 2 {
        0
    } else {
        1
    }
}

fn seat_index(board: usize, color: Color) -> u8 {
    debug_assert!(board < 2, "bughouse has exactly two boards");
    board as u8 * 2 + if color == Color::White { 0 } else { 1 }
}

fn bug_team(seat: u8) -> u8 {
    if seat == 0 || seat == 3 {
        1
    } else {
        2
    }
}

fn color_u8(c: Color) -> u32 {
    if c == Color::White {
        0
    } else {
        1
    }
}

fn piece_u8(p: Piece) -> u32 {
    match p {
        Piece::Pawn => 0,
        Piece::Knight => 1,
        Piece::Bishop => 2,
        Piece::Rook => 3,
        Piece::Queen => 4,
        Piece::King => 0,
    }
}

/// Partner feed: a capture by `mover` on `board` lands in the other board's
/// opposite-colour reserve (the partner's hand).
fn feed_target(board: usize, mover: Color) -> (usize, Color) {
    (
        1 - board,
        if mover == Color::White {
            Color::Black
        } else {
            Color::White
        },
    )
}

fn bug_game() -> Game {
    let mut pos = chess_core::parse_fen(chess_core::START_FEN).expect("start fen");
    pos.variant = Variant::Bughouse;
    Game::from_position(pos)
}

/// The piece a move makes available to pass (demoted to pawn if it was promoted).
fn bug_passable(pos: &chess_core::Position, m: chess_core::Move) -> Option<Piece> {
    if m.is_drop() {
        return None;
    }
    let cap_sq = if m.is_ep() {
        if pos.side == Color::White {
            m.to() - 8
        } else {
            m.to() + 8
        }
    } else if m.is_capture() {
        m.to()
    } else {
        return None;
    };
    let (_, cp) = pos.piece_at(cap_sq)?;
    Some(if pos.promoted & (1u64 << cap_sq) != 0 {
        Piece::Pawn
    } else {
        cp
    })
}

type BugInbound = Mutex<Option<(u64, UnboundedSender<(Option<usize>, Message)>)>>;
fn bug_inbound() -> &'static BugInbound {
    static S: OnceLock<BugInbound> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}

type BugClientOut = Mutex<Option<(u64, UnboundedSender<Message>)>>;
fn bug_client_out() -> &'static BugClientOut {
    static S: OnceLock<BugClientOut> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}

static BUG_ASSIGN: Mutex<Option<Vec<i32>>> = Mutex::new(None);
fn bug_assign_notify() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

type BugPeer = (UnboundedSender<Message>, String);

fn bug_broadcast(peers: &[BugPeer], msg: &Message) {
    for (tx, _) in peers {
        let _ = tx.send(msg.clone());
    }
}

/// Host a Bughouse match: advertise (name prefixed "[BH]"), accept up to 3
/// joiners into a lobby, then — once the host assigns seats — run the authority.
pub fn net_host_bughouse(
    name: String,
    base_minutes: u32,
    increment_seconds: u32,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    session_cancel().notify_waiters();
    runtime().block_on(async move {
        if let Err(e) = bug_host_task(name, base_minutes, increment_seconds, &sink).await {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn bug_host_task(
    name: String,
    base: u32,
    inc: u32,
    sink: &StreamSink<NetEvent>,
) -> Result<(), String> {
    let listener = TcpListener::bind("0.0.0.0:0").await.map_err(es)?;
    let port = listener.local_addr().map_err(es)?.port();
    let _adv =
        chess_net::advertise(&format!("[BH] {name}"), port, base, inc).map_err(|e| e.to_string())?;

    let (in_tx, mut in_rx) =
        tokio::sync::mpsc::unbounded_channel::<(Option<usize>, Message)>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(bug_inbound()) = Some((gen, in_tx.clone()));

    let mut peers: Vec<BugPeer> = Vec::new();
    let mut games = [bug_game(), bug_game()];
    let mut seat_owner: [Option<usize>; 4] = [None; 4]; // None = host holds the seat
    let mut started = false;
    let mut ended = false;

    loop {
        tokio::select! {
            r = listener.accept(), if !started && peers.len() < 3 => {
                let stream = match r { Ok((s, _)) => s, Err(_) => continue };
                let (rd, wr) = stream.into_split();
                let mut lines = BufReader::new(rd).lines();
                let nm = match read_message(&mut lines).await {
                    Ok(Message::Hello { name, protocol_version, .. }) => {
                        if protocol_version != PROTOCOL_VERSION { continue; }
                        name
                    }
                    _ => continue,
                };
                let idx = peers.len();
                let (ptx, prx) = tokio::sync::mpsc::unbounded_channel::<Message>();
                tokio::spawn(bug_writer(wr, prx));
                tokio::spawn(bug_reader(idx, lines, in_tx.clone()));
                peers.push((ptx, nm.clone()));
                let mut ev = NetEvent::of(NetEventKind::BugJoin);
                ev.text = nm;
                ev.seat = idx as u32; // connection index (seats assigned at start)
                let _ = sink.add(ev);
            }
            _ = bug_assign_notify().notified(), if !started => {
                let Some(owner) = lock(&BUG_ASSIGN).take() else { continue };
                if owner.len() < 4 { continue; }
                for s in 0..4 {
                    seat_owner[s] = if owner[s] < 0 { None } else { Some(owner[s] as usize) };
                }
                let names: Vec<String> = (0..4)
                    .map(|s| match seat_owner[s] {
                        None => name.clone(),
                        Some(i) => peers.get(i).map(|p| p.1.clone()).unwrap_or_default(),
                    })
                    .collect();
                for (i, (tx, _)) in peers.iter().enumerate() {
                    let my: Vec<u8> =
                        (0..4u8).filter(|&s| seat_owner[s as usize] == Some(i)).collect();
                    let _ = tx.send(Message::BugStart {
                        seats: names.clone(),
                        your_seats: my,
                        base_minutes: base,
                        increment_seconds: inc,
                    });
                }
                let host_seats: Vec<u32> =
                    (0..4u32).filter(|&s| seat_owner[s as usize].is_none()).collect();
                let mut ev = NetEvent::of(NetEventKind::BugStart);
                ev.your_seats = host_seats;
                ev.seats = names;
                ev.base_minutes = base;
                ev.increment_seconds = inc;
                let _ = sink.add(ev);
                started = true;
            }
            msg = in_rx.recv() => {
                let Some((from, m)) = msg else { break };
                if started && !ended {
                    bug_authority(from, m, &mut games, &seat_owner, &peers, sink, &mut ended);
                }
            }
            _ = session_cancel().notified() => break,
        }
    }

    let mut slot = lock(bug_inbound());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn bug_authority(
    from: Option<usize>,
    m: Message,
    games: &mut [Game; 2],
    seat_owner: &[Option<usize>; 4],
    peers: &[BugPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
) {
    match m {
        Message::BugMove {
            board,
            uci,
            white_ms,
            black_ms,
        } => {
            let b = board as usize;
            if b > 1 {
                return;
            }
            let stm = games[b].pos.side;
            let seat = seat_index(b, stm);
            let owner = seat_owner[seat as usize];
            let allowed = matches!((from, owner), (None, None))
                || matches!((from, owner), (Some(i), Some(j)) if i == j);
            if !allowed {
                return; // not this sender's seat / turn
            }
            let Ok(mv) = games[b].pos.parse_uci(&uci) else {
                return;
            };
            let passable = bug_passable(&games[b].pos, mv);
            games[b].make_move(mv);

            bug_broadcast(
                peers,
                &Message::BugMove {
                    board,
                    uci: uci.clone(),
                    white_ms,
                    black_ms,
                },
            );
            let mut ev = NetEvent::of(NetEventKind::BugMove);
            ev.board = board as u32;
            ev.uci = uci;
            ev.white_ms = white_ms;
            ev.black_ms = black_ms;
            let _ = sink.add(ev);

            if let Some(p) = passable {
                let (ob, oc) = feed_target(b, stm);
                games[ob].pos.add_to_hand(oc, p);
                bug_broadcast(
                    peers,
                    &Message::BugPass {
                        to_board: ob as u8,
                        to_color: color_u8(oc) as u8,
                        piece: piece_u8(p) as u8,
                    },
                );
                let mut ev = NetEvent::of(NetEventKind::BugPass);
                ev.to_board = ob as u32;
                ev.to_color = color_u8(oc);
                ev.piece = piece_u8(p);
                let _ = sink.add(ev);
            }

            if let Some((team, board_ended)) = bug_check_end(games) {
                bug_finish(team, board_ended, peers, sink, ended);
            }
        }
        Message::BugResign { seat } => {
            bug_finish(3 - bug_team(seat), seat_board(seat) as u8, peers, sink, ended);
        }
        Message::Bye => {
            if let Some(i) = from {
                if let Some(s) = (0..4u8).find(|&s| seat_owner[s as usize] == Some(i)) {
                    bug_finish(3 - bug_team(s), seat_board(s) as u8, peers, sink, ended);
                }
            }
        }
        _ => {}
    }
}

/// If either board has ended, the winning team + which board ended.
fn bug_check_end(games: &mut [Game; 2]) -> Option<(u8, u8)> {
    for b in 0..2usize {
        let loser = match games[b].status() {
            GameStatus::Checkmate { winner } | GameStatus::VariantWin { winner } => {
                Some(winner.opp())
            }
            GameStatus::Ongoing => None,
            _ => Some(games[b].pos.side), // stalemate / draws → side to move loses
        };
        if let Some(lc) = loser {
            let team = bug_team(seat_index(b, lc));
            return Some((3 - team, b as u8));
        }
    }
    None
}

fn bug_finish(team: u8, board: u8, peers: &[BugPeer], sink: &StreamSink<NetEvent>, ended: &mut bool) {
    if *ended {
        return;
    }
    *ended = true;
    bug_broadcast(
        peers,
        &Message::BugResult {
            winning_team: team,
            reason: "match over".into(),
            board,
        },
    );
    let mut ev = NetEvent::of(NetEventKind::BugResult);
    ev.winning_team = team as u32;
    ev.board = board as u32;
    let _ = sink.add(ev);
}

async fn bug_writer(mut wr: OwnedWriteHalf, mut rx: UnboundedReceiver<Message>) {
    while let Some(m) = rx.recv().await {
        if wr.write_all(m.encode().as_bytes()).await.is_err() {
            break;
        }
    }
}

async fn bug_reader(
    idx: usize,
    mut lines: tokio::io::Lines<BufReader<tokio::net::tcp::OwnedReadHalf>>,
    in_tx: UnboundedSender<(Option<usize>, Message)>,
) {
    while let Ok(Some(l)) = lines.next_line().await {
        if let Ok(m) = Message::decode(&l) {
            let _ = in_tx.send((Some(idx), m));
        }
    }
    let _ = in_tx.send((Some(idx), Message::Bye));
}

/// Join a Bughouse host at `addr`; mirror its broadcasts as NetEvents.
pub fn net_join_bughouse(
    addr: String,
    name: String,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    session_cancel().notify_waiters();
    runtime().block_on(async move {
        if let Err(e) = bug_join_task(addr, name, &sink).await {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn bug_join_task(
    addr: String,
    name: String,
    sink: &StreamSink<NetEvent>,
) -> Result<(), String> {
    let stream = TcpStream::connect(&addr).await.map_err(es)?;
    let (rd, wr) = stream.into_split();
    let mut lines = BufReader::new(rd).lines();

    let (otx, orx) = tokio::sync::mpsc::unbounded_channel::<Message>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(bug_client_out()) = Some((gen, otx.clone()));
    let _ = otx.send(Message::Hello {
        name,
        protocol_version: PROTOCOL_VERSION,
        base_minutes: 0,
        increment_seconds: 0,
    });
    tokio::spawn(bug_writer(wr, orx));

    loop {
        tokio::select! {
            line = lines.next_line() => match line {
                Ok(Some(l)) => {
                    if !bug_client_handle(&l, sink) { break; }
                }
                _ => {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "connection closed".into();
                    let _ = sink.add(ev);
                    break;
                }
            },
            _ = session_cancel().notified() => break,
        }
    }

    let mut slot = lock(bug_client_out());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

/// Surface one host broadcast as a NetEvent. Returns false to stop the loop.
fn bug_client_handle(line: &str, sink: &StreamSink<NetEvent>) -> bool {
    let m = match Message::decode(line) {
        Ok(m) => m,
        Err(_) => return true,
    };
    match m {
        Message::BugStart {
            seats,
            your_seats,
            base_minutes,
            increment_seconds,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugStart);
            ev.seats = seats;
            ev.your_seats = your_seats.iter().map(|&x| x as u32).collect();
            ev.base_minutes = base_minutes;
            ev.increment_seconds = increment_seconds;
            let _ = sink.add(ev);
        }
        Message::BugMove {
            board,
            uci,
            white_ms,
            black_ms,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugMove);
            ev.board = board as u32;
            ev.uci = uci;
            ev.white_ms = white_ms;
            ev.black_ms = black_ms;
            let _ = sink.add(ev);
        }
        Message::BugPass {
            to_board,
            to_color,
            piece,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugPass);
            ev.to_board = to_board as u32;
            ev.to_color = to_color as u32;
            ev.piece = piece as u32;
            let _ = sink.add(ev);
        }
        Message::BugResult {
            winning_team, board, ..
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugResult);
            ev.winning_team = winning_team as u32;
            ev.board = board as u32;
            let _ = sink.add(ev);
        }
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "host left".into();
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

fn bug_cmd(msg: Message) {
    if let Some((_, tx)) = lock(bug_inbound()).as_ref() {
        let _ = tx.send((None, msg)); // host: into the local authority
    } else if let Some((_, tx)) = lock(bug_client_out()).as_ref() {
        let _ = tx.send(msg); // client: over TCP to the host
    }
}

/// Host assigns the four seats and starts the match. `seat_owner[seat]` is the
/// connection index (join order, 0-based) or -1 for the host.
#[frb(sync)]
pub fn net_bug_start(seat_owner: Vec<i32>) {
    *lock(&BUG_ASSIGN) = Some(seat_owner);
    bug_assign_notify().notify_one();
}

#[frb(sync)]
pub fn net_send_bug_move(board: u32, uci: String, white_ms: i64, black_ms: i64) {
    bug_cmd(Message::BugMove {
        board: board as u8,
        uci,
        white_ms,
        black_ms,
    });
}

#[frb(sync)]
pub fn net_bug_resign(seat: u32) {
    bug_cmd(Message::BugResign { seat: seat as u8 });
}

// ===== 4-player chess: host-authoritative star (one cross board, 4 seats) =====
// Seats: 0=Red, 1=Blue, 2=Yellow, 3=Green. Untimed (chess4 has no clock).

type FourInbound = Mutex<Option<(u64, UnboundedSender<(Option<usize>, Message)>)>>;
fn four_inbound() -> &'static FourInbound {
    static S: OnceLock<FourInbound> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}
type FourClientOut = Mutex<Option<(u64, UnboundedSender<Message>)>>;
fn four_client_out() -> &'static FourClientOut {
    static S: OnceLock<FourClientOut> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}
static FOUR_ASSIGN: Mutex<Option<Vec<i32>>> = Mutex::new(None);
fn four_assign_notify() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

fn four_format(code: &str) -> chess4::Format {
    if code == "teams" {
        chess4::Format::Teams
    } else {
        chess4::Format::FreeForAll
    }
}

fn four_player_code(p: chess4::Player) -> &'static str {
    match p {
        chess4::Player::Red => "red",
        chess4::Player::Blue => "blue",
        chess4::Player::Yellow => "yellow",
        chess4::Player::Green => "green",
    }
}

fn four_result_str(r: chess4::FourResult) -> String {
    match r {
        chess4::FourResult::InProgress => "ongoing".into(),
        chess4::FourResult::TeamWin(chess4::Team::RedYellow) => "team:red_yellow".into(),
        chess4::FourResult::TeamWin(chess4::Team::BlueGreen) => "team:blue_green".into(),
        chess4::FourResult::FfaWin(p) => format!("ffa:{}", four_player_code(p)),
    }
}

fn four_apply_uci(game: &mut chess4::FourGame, uci: &str) -> bool {
    let Some((f, t, promo)) = chess4::serial::parse_uci(uci) else {
        return false;
    };
    let chosen = game
        .legal_moves()
        .into_iter()
        .find(|m| m.from == f && m.to == t && m.promo == promo);
    if let Some(m) = chosen {
        game.make_move(m);
        true
    } else {
        false
    }
}

/// Host a 4-player match: advertise "[4P]", accept ≤3 joiners, run the authority.
pub fn net_host_four(
    name: String,
    format: String,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    session_cancel().notify_waiters();
    runtime().block_on(async move {
        if let Err(e) = four_host_task(name, format, &sink).await {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn four_host_task(
    name: String,
    format: String,
    sink: &StreamSink<NetEvent>,
) -> Result<(), String> {
    let listener = TcpListener::bind("0.0.0.0:0").await.map_err(es)?;
    let port = listener.local_addr().map_err(es)?.port();
    let _adv =
        chess_net::advertise(&format!("[4P] {name}"), port, 0, 0).map_err(|e| e.to_string())?;

    let (in_tx, mut in_rx) = tokio::sync::mpsc::unbounded_channel::<(Option<usize>, Message)>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(four_inbound()) = Some((gen, in_tx.clone()));

    let mut peers: Vec<BugPeer> = Vec::new();
    let mut game = chess4::FourGame::new(four_format(&format));
    let mut seat_owner: [Option<usize>; 4] = [None; 4];
    let mut started = false;
    let mut ended = false;

    loop {
        tokio::select! {
            r = listener.accept(), if !started && peers.len() < 3 => {
                let stream = match r { Ok((s, _)) => s, Err(_) => continue };
                let (rd, wr) = stream.into_split();
                let mut lines = BufReader::new(rd).lines();
                let nm = match read_message(&mut lines).await {
                    Ok(Message::Hello { name, protocol_version, .. }) => {
                        if protocol_version != PROTOCOL_VERSION { continue; }
                        name
                    }
                    _ => continue,
                };
                let idx = peers.len();
                let (ptx, prx) = tokio::sync::mpsc::unbounded_channel::<Message>();
                tokio::spawn(bug_writer(wr, prx));
                tokio::spawn(bug_reader(idx, lines, in_tx.clone()));
                peers.push((ptx, nm.clone()));
                let mut ev = NetEvent::of(NetEventKind::FourJoin);
                ev.text = nm;
                ev.seat = idx as u32;
                let _ = sink.add(ev);
            }
            _ = four_assign_notify().notified(), if !started => {
                let Some(owner) = lock(&FOUR_ASSIGN).take() else { continue };
                if owner.len() < 4 { continue; }
                for s in 0..4 {
                    seat_owner[s] = if owner[s] < 0 { None } else { Some(owner[s] as usize) };
                }
                let names: Vec<String> = (0..4)
                    .map(|s| match seat_owner[s] {
                        None => name.clone(),
                        Some(i) => peers.get(i).map(|p| p.1.clone()).unwrap_or_default(),
                    })
                    .collect();
                for (i, (tx, _)) in peers.iter().enumerate() {
                    let my: Vec<u8> =
                        (0..4u8).filter(|&s| seat_owner[s as usize] == Some(i)).collect();
                    let _ = tx.send(Message::FourStart {
                        format: format.clone(),
                        seats: names.clone(),
                        your_seats: my,
                    });
                }
                let host_seats: Vec<u32> =
                    (0..4u32).filter(|&s| seat_owner[s as usize].is_none()).collect();
                let mut ev = NetEvent::of(NetEventKind::FourStart);
                ev.your_seats = host_seats;
                ev.seats = names;
                ev.variant = format.clone(); // reuse `variant` to carry the format code
                let _ = sink.add(ev);
                started = true;
            }
            msg = in_rx.recv() => {
                let Some((from, m)) = msg else { break };
                if started && !ended {
                    four_authority(from, m, &mut game, &seat_owner, &peers, sink, &mut ended);
                }
            }
            _ = session_cancel().notified() => break,
        }
    }

    let mut slot = lock(four_inbound());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn four_authority(
    from: Option<usize>,
    m: Message,
    game: &mut chess4::FourGame,
    seat_owner: &[Option<usize>; 4],
    peers: &[BugPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
) {
    match m {
        Message::FourMove { seat, uci } => {
            if seat as usize != game.turn.index() {
                return; // not the seat to move
            }
            let owner = seat_owner[seat as usize];
            let allowed = matches!((from, owner), (None, None))
                || matches!((from, owner), (Some(i), Some(j)) if i == j);
            if !allowed {
                return;
            }
            if !four_apply_uci(game, &uci) {
                return;
            }
            bug_broadcast(peers, &Message::FourMove { seat, uci: uci.clone() });
            let mut ev = NetEvent::of(NetEventKind::FourMove);
            ev.seat = seat as u32;
            ev.uci = uci;
            let _ = sink.add(ev);
            if game.ended {
                four_finish(four_result_str(game.result()), peers, sink, ended);
            }
        }
        Message::FourResign { .. } | Message::Bye => {
            // A seat resigned or disconnected → end the match.
            let _ = (from, seat_owner);
            four_finish("forfeit".into(), peers, sink, ended);
        }
        _ => {}
    }
}

fn four_finish(result: String, peers: &[BugPeer], sink: &StreamSink<NetEvent>, ended: &mut bool) {
    if *ended {
        return;
    }
    *ended = true;
    bug_broadcast(peers, &Message::FourResult { result: result.clone() });
    let mut ev = NetEvent::of(NetEventKind::FourResult);
    ev.text = result;
    let _ = sink.add(ev);
}

pub fn net_join_four(
    addr: String,
    name: String,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    session_cancel().notify_waiters();
    runtime().block_on(async move {
        if let Err(e) = four_join_task(addr, name, &sink).await {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn four_join_task(
    addr: String,
    name: String,
    sink: &StreamSink<NetEvent>,
) -> Result<(), String> {
    let stream = TcpStream::connect(&addr).await.map_err(es)?;
    let (rd, wr) = stream.into_split();
    let mut lines = BufReader::new(rd).lines();

    let (otx, orx) = tokio::sync::mpsc::unbounded_channel::<Message>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(four_client_out()) = Some((gen, otx.clone()));
    let _ = otx.send(Message::Hello {
        name,
        protocol_version: PROTOCOL_VERSION,
        base_minutes: 0,
        increment_seconds: 0,
    });
    tokio::spawn(bug_writer(wr, orx));

    loop {
        tokio::select! {
            line = lines.next_line() => match line {
                Ok(Some(l)) => { if !four_client_handle(&l, sink) { break; } }
                _ => {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "connection closed".into();
                    let _ = sink.add(ev);
                    break;
                }
            },
            _ = session_cancel().notified() => break,
        }
    }

    let mut slot = lock(four_client_out());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

fn four_client_handle(line: &str, sink: &StreamSink<NetEvent>) -> bool {
    let m = match Message::decode(line) {
        Ok(m) => m,
        Err(_) => return true,
    };
    match m {
        Message::FourStart { format, seats, your_seats } => {
            let mut ev = NetEvent::of(NetEventKind::FourStart);
            ev.variant = format;
            ev.seats = seats;
            ev.your_seats = your_seats.iter().map(|&x| x as u32).collect();
            let _ = sink.add(ev);
        }
        Message::FourMove { seat, uci } => {
            let mut ev = NetEvent::of(NetEventKind::FourMove);
            ev.seat = seat as u32;
            ev.uci = uci;
            let _ = sink.add(ev);
        }
        Message::FourResult { result } => {
            let mut ev = NetEvent::of(NetEventKind::FourResult);
            ev.text = result;
            let _ = sink.add(ev);
        }
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "host left".into();
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

fn four_cmd(msg: Message) {
    if let Some((_, tx)) = lock(four_inbound()).as_ref() {
        let _ = tx.send((None, msg));
    } else if let Some((_, tx)) = lock(four_client_out()).as_ref() {
        let _ = tx.send(msg);
    }
}

#[frb(sync)]
pub fn net_four_start(seat_owner: Vec<i32>) {
    *lock(&FOUR_ASSIGN) = Some(seat_owner);
    four_assign_notify().notify_one();
}

#[frb(sync)]
pub fn net_send_four_move(seat: u32, uci: String) {
    four_cmd(Message::FourMove { seat: seat as u8, uci });
}

#[frb(sync)]
pub fn net_four_resign(seat: u32) {
    four_cmd(Message::FourResign { seat: seat as u8 });
}
