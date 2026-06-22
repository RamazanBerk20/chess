//! Transform the Lichess CC0 puzzle CSV into `assets/puzzles/puzzles.json`.
//!
//! Lichess convention: the CSV `FEN` is the position *before* the first listed
//! move; `Moves[0]` is the opponent's setup move (auto-played), and `Moves[1..]`
//! is the solution the player must find. We apply `Moves[0]` with `chess_core`
//! to get the player-to-move position, validate the whole solution is legal,
//! sample 100 puzzles evenly across the rating range (easy → hard) and write
//! the bundled JSON.
//!
//! Usage: `puzzle_prep <input.csv> <output.json>`

use chess_core::{parse_fen, to_fen};

struct Puzzle {
    fen: String,
    solution: Vec<String>,
    themes: Vec<String>,
    rating: i32,
    side: &'static str,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: puzzle_prep <input.csv> <output.json>");
        std::process::exit(2);
    }
    let data = std::fs::read_to_string(&args[1]).expect("read input csv");

    let mut puzzles: Vec<Puzzle> = Vec::new();
    for (i, line) in data.lines().enumerate() {
        if i == 0 {
            continue; // header
        }
        let cols: Vec<&str> = line.split(',').collect();
        if cols.len() < 8 {
            continue;
        }
        let fen = cols[1];
        let moves: Vec<&str> = cols[2].split_whitespace().collect();
        let rating: i32 = cols[3].parse().unwrap_or(0);
        let popularity: i32 = cols[5].parse().unwrap_or(0);
        let themes = cols[7];

        // Quality + shape filters.
        if popularity < 85 || rating < 500 || moves.len() < 2 {
            continue;
        }

        // Apply the opponent's setup move to reach the player-to-move position.
        let mut pos = match parse_fen(fen) {
            Ok(p) => p,
            Err(_) => continue,
        };
        let m0 = match pos.parse_uci(moves[0]) {
            Ok(m) => m,
            Err(_) => continue,
        };
        pos.make_move(m0);
        let start_fen = to_fen(&pos);
        let side = if start_fen.contains(" w ") { "white" } else { "black" };

        let solution: Vec<String> = moves[1..].iter().map(|s| s.to_string()).collect();
        if !solution_is_legal(&start_fen, &solution) {
            continue;
        }

        puzzles.push(Puzzle {
            fen: start_fen,
            solution,
            themes: themes.split_whitespace().map(String::from).collect(),
            rating,
            side,
        });
    }

    puzzles.sort_by_key(|p| p.rating);
    let n = puzzles.len();
    assert!(n >= 100, "need >=100 valid puzzles, got {n}");

    // Pick 100 evenly spaced across the sorted (easy → hard) range.
    let mut picked: Vec<&Puzzle> = Vec::with_capacity(100);
    for i in 0..100 {
        let idx = (i as u64 * (n - 1) as u64 / 99) as usize;
        picked.push(&puzzles[idx]);
    }

    let mut out = String::from("[\n");
    for (i, p) in picked.iter().enumerate() {
        let id = format!("{:05}", i + 1);
        let sol = join_quoted(&p.solution);
        let themes = join_quoted(&p.themes);
        let comma = if i + 1 < picked.len() { "," } else { "" };
        out.push_str(&format!(
            "  {{\"id\":\"{id}\",\"fen\":\"{}\",\"solution\":[{sol}],\"themes\":[{themes}],\"rating\":{},\"side_to_move\":\"{}\"}}{comma}\n",
            p.fen, p.rating, p.side
        ));
    }
    out.push_str("]\n");

    std::fs::write(&args[2], out).expect("write output json");
    eprintln!(
        "wrote 100 puzzles to {} (ratings {}..{})",
        args[2],
        picked.first().unwrap().rating,
        picked.last().unwrap().rating
    );
}

fn solution_is_legal(start_fen: &str, solution: &[String]) -> bool {
    let mut pos = match parse_fen(start_fen) {
        Ok(p) => p,
        Err(_) => return false,
    };
    for uci in solution {
        match pos.parse_uci(uci) {
            Ok(m) => {
                pos.make_move(m);
            }
            Err(_) => return false,
        }
    }
    true
}

fn join_quoted(items: &[String]) -> String {
    items
        .iter()
        .map(|s| format!("\"{s}\""))
        .collect::<Vec<_>>()
        .join(",")
}
