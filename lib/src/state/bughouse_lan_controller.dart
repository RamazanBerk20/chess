import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/bughouse_controller.dart';

/// Lobby + live-session state for a networked Bughouse match.
class BughouseLanState {
  final bool active; // a host/join session is running
  final bool isHost;
  final bool started; // BugStart received → match underway
  final List<String> joiners; // host lobby: joined player names (connection order)
  final List<int> mySeats; // seats this device controls (after start)
  final List<String> seatNames; // the four player names
  final String? error;

  const BughouseLanState({
    this.active = false,
    this.isHost = false,
    this.started = false,
    this.joiners = const [],
    this.mySeats = const [],
    this.seatNames = const [],
    this.error,
  });

  BughouseLanState copyWith({
    bool? active,
    bool? isHost,
    bool? started,
    List<String>? joiners,
    List<int>? mySeats,
    List<String>? seatNames,
    String? error,
  }) =>
      BughouseLanState(
        active: active ?? this.active,
        isHost: isHost ?? this.isHost,
        started: started ?? this.started,
        joiners: joiners ?? this.joiners,
        mySeats: mySeats ?? this.mySeats,
        seatNames: seatNames ?? this.seatNames,
        error: error,
      );
}

final bughouseLanProvider =
    NotifierProvider<BughouseLanController, BughouseLanState>(
        BughouseLanController.new);

class BughouseLanController extends Notifier<BughouseLanState> {
  StreamSubscription<NetEvent>? _sub;
  BughouseController? _match; // the live match controller (registered by the screen)

  @override
  BughouseLanState build() {
    ref.onDispose(() {
      _sub?.cancel();
      netLeave();
    });
    return const BughouseLanState();
  }

  void host(String name) {
    _listen(
      netHostBughouse(name: name, baseMinutes: 0, incrementSeconds: 0),
      isHost: true,
    );
  }

  void join(String addr, String name) {
    _listen(netJoinBughouse(addr: addr, name: name), isHost: false);
  }

  void _listen(Stream<NetEvent> stream, {required bool isHost}) {
    _sub?.cancel();
    state = BughouseLanState(active: true, isHost: isHost);
    _sub = stream.listen(
      _onEvent,
      onError: (e) => state = state.copyWith(error: '$e'),
    );
  }

  /// Host commits the seat assignment (`seatOwner[seat]` = connection index, or
  /// -1 for the host) and starts the match.
  void startAssign(List<int> seatOwner) {
    netBugStart(seatOwner: seatOwner);
  }

  /// The match screen registers its controller so broadcasts can be applied.
  void register(BughouseController match) {
    _match = match;
  }

  void _onEvent(NetEvent e) {
    switch (e.kind) {
      case NetEventKind.bugJoin:
        state = state.copyWith(joiners: [...state.joiners, e.text]);
      case NetEventKind.bugStart:
        state = state.copyWith(
          started: true,
          mySeats: e.yourSeats.map((x) => x.toInt()).toList(),
          seatNames: e.seats,
        );
      case NetEventKind.bugMove:
        _match?.applyRemoteMove(e.board.toInt(), e.uci);
      case NetEventKind.bugPass:
        _match?.applyPass(
            e.toBoard.toInt(), e.toColor.toInt(), e.piece.toInt());
      case NetEventKind.bugResult:
        _match?.applyResult(e.winningTeam.toInt(), e.board.toInt());
      case NetEventKind.disconnected:
        state = state.copyWith(error: e.text.isEmpty ? 'Disconnected' : e.text);
      case NetEventKind.error:
        state = state.copyWith(error: e.text);
      default:
        break;
    }
  }

  void leave() {
    netLeave();
    _sub?.cancel();
    _sub = null;
    _match = null;
    state = const BughouseLanState();
  }
}
