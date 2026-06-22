import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/four_player_controller.dart';

class FourLanState {
  final bool active;
  final bool isHost;
  final bool started;
  final List<String> joiners;
  final List<int> mySeats;
  final List<String> seatNames;
  final String format; // "ffa" | "teams"
  final String? error;

  const FourLanState({
    this.active = false,
    this.isHost = false,
    this.started = false,
    this.joiners = const [],
    this.mySeats = const [],
    this.seatNames = const [],
    this.format = 'ffa',
    this.error,
  });

  FourLanState copyWith({
    bool? active,
    bool? isHost,
    bool? started,
    List<String>? joiners,
    List<int>? mySeats,
    List<String>? seatNames,
    String? format,
    String? error,
  }) =>
      FourLanState(
        active: active ?? this.active,
        isHost: isHost ?? this.isHost,
        started: started ?? this.started,
        joiners: joiners ?? this.joiners,
        mySeats: mySeats ?? this.mySeats,
        seatNames: seatNames ?? this.seatNames,
        format: format ?? this.format,
        error: error,
      );
}

final fourLanProvider =
    NotifierProvider<FourLanController, FourLanState>(FourLanController.new);

class FourLanController extends Notifier<FourLanState> {
  StreamSubscription<NetEvent>? _sub;
  FourPlayerController? _match;

  @override
  FourLanState build() {
    ref.onDispose(() {
      _sub?.cancel();
      netLeave();
    });
    return const FourLanState();
  }

  void host(String name, String format) {
    _listen(netHostFour(name: name, format: format),
        isHost: true, format: format);
  }

  void join(String addr, String name) {
    _listen(netJoinFour(addr: addr, name: name), isHost: false, format: 'ffa');
  }

  void _listen(Stream<NetEvent> stream,
      {required bool isHost, required String format}) {
    _sub?.cancel();
    state = FourLanState(active: true, isHost: isHost, format: format);
    _sub = stream.listen(
      _onEvent,
      onError: (e) => state = state.copyWith(error: '$e'),
    );
  }

  void startAssign(List<int> seatOwner) => netFourStart(seatOwner: seatOwner);

  void register(FourPlayerController match) => _match = match;

  void _onEvent(NetEvent e) {
    switch (e.kind) {
      case NetEventKind.fourJoin:
        state = state.copyWith(joiners: [...state.joiners, e.text]);
      case NetEventKind.fourStart:
        state = state.copyWith(
          started: true,
          mySeats: e.yourSeats.map((x) => x.toInt()).toList(),
          seatNames: e.seats,
          format: e.variant.isEmpty ? state.format : e.variant,
        );
      case NetEventKind.fourMove:
        _match?.applyRemoteMove(e.seat.toInt(), e.uci);
      case NetEventKind.fourResult:
        _match?.applyResult(e.text);
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
    state = const FourLanState();
  }
}
