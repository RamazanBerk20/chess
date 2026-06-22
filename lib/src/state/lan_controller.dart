import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/rust/api/net.dart';
import 'package:chess/src/state/clock_provider.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/game_mode.dart';
import 'package:chess/src/state/game_providers.dart';
import 'package:chess/src/state/time_control.dart';

/// A single chat line. [mine] is true for messages this device sent.
class ChatMessage {
  final String text;
  final bool mine;
  const ChatMessage(this.text, this.mine);
}

class LanGameState {
  final bool waiting; // hosting/connecting, not yet connected
  final bool connected;
  final bool ended;
  final String myName;
  final String opponentName;
  final bool youAreWhite;
  final bool drawOfferIncoming;
  final List<ChatMessage> chat;
  final String? error;

  const LanGameState({
    this.waiting = false,
    this.connected = false,
    this.ended = false,
    this.myName = '',
    this.opponentName = '',
    this.youAreWhite = true,
    this.drawOfferIncoming = false,
    this.chat = const [],
    this.error,
  });

  LanGameState copyWith({
    bool? waiting,
    bool? connected,
    bool? ended,
    String? myName,
    String? opponentName,
    bool? youAreWhite,
    bool? drawOfferIncoming,
    List<ChatMessage>? chat,
    String? error,
  }) =>
      LanGameState(
        waiting: waiting ?? this.waiting,
        connected: connected ?? this.connected,
        ended: ended ?? this.ended,
        myName: myName ?? this.myName,
        opponentName: opponentName ?? this.opponentName,
        youAreWhite: youAreWhite ?? this.youAreWhite,
        drawOfferIncoming: drawOfferIncoming ?? this.drawOfferIncoming,
        chat: chat ?? this.chat,
        error: error,
      );
}

final lanProvider =
    NotifierProvider<LanController, LanGameState>(LanController.new);

class LanController extends Notifier<LanGameState> {
  StreamSubscription<NetEvent>? _sub;

  @override
  LanGameState build() {
    ref.onDispose(() {
      _sub?.cancel();
      netLeave();
    });
    return const LanGameState();
  }

  void host(
    String name,
    int baseMinutes,
    int incrementSeconds,
    bool hostWhite,
    GameVariant variant,
    int chess960Index,
  ) {
    _listen(
      netHost(
        name: name,
        baseMinutes: baseMinutes,
        incrementSeconds: incrementSeconds,
        hostWhite: hostWhite,
        variant: variantCode(variant),
        chess960Index: chess960Index,
      ),
      name,
    );
  }

  void join(String addr, String name) {
    _listen(netJoin(addr: addr, name: name), name);
  }

  void _listen(Stream<NetEvent> stream, String name) {
    _sub?.cancel();
    state = LanGameState(waiting: true, myName: name);
    _sub = stream.listen(
      _onEvent,
      onError: (e) => state = state.copyWith(error: '$e', waiting: false),
    );
  }

  void _onEvent(NetEvent e) {
    final game = ref.read(gameControllerProvider.notifier);
    switch (e.kind) {
      case NetEventKind.connected:
        final myColor = e.youAreWhite ? PieceColor.white : PieceColor.black;
        ref.read(gameModeProvider.notifier).setLan(myColor);
        final tc = e.baseMinutes == 0
            ? TimeControlOption.infinite
            : TimeControlOption(
                '${e.baseMinutes}+${e.incrementSeconds}',
                e.baseMinutes,
                e.incrementSeconds,
              );
        ref.read(selectedTimeControlProvider.notifier).set(tc);
        final variant = variantFromCode(e.variant);
        // Chess960's layout rides in the FEN (X-FEN); other variants start
        // standard and only set the rules flag.
        ref.read(customStartFenProvider.notifier).set(
            variant == GameVariant.chess960 ? e.fen : null);
        ref.read(selectedVariantProvider.notifier).set(variant);
        ref.invalidate(gameControllerProvider);
        ref.invalidate(clockProvider);
        state = state.copyWith(
          waiting: false,
          connected: true,
          youAreWhite: e.youAreWhite,
          opponentName: e.youAreWhite ? e.blackName : e.whiteName,
        );
      case NetEventKind.move:
        game.lanApplyRemote(e.uci, e.whiteMs, e.blackMs);
      case NetEventKind.resign:
        game.lanSetResult(LanResultCode.opponentResigned);
      case NetEventKind.drawOffer:
        state = state.copyWith(drawOfferIncoming: true);
      case NetEventKind.drawResponse:
        if (e.drawAccepted) {
          game.lanSetResult(LanResultCode.drawAgreed);
        }
      case NetEventKind.chat:
        state = state.copyWith(
            chat: [...state.chat, ChatMessage(e.text, false)]);
      case NetEventKind.disconnected:
        if (state.connected) {
          game.lanSetResult(e.text.isEmpty ? LanResultCode.opponentDisconnected : e.text);
        }
        state = state.copyWith(ended: true, waiting: false);
      case NetEventKind.error:
        state = state.copyWith(error: e.text);
      default:
        break; // Bughouse events are handled by the Bughouse LAN controller.
    }
  }

  void resign() {
    netResign();
    ref
        .read(gameControllerProvider.notifier)
        .lanSetResult(LanResultCode.youResigned);
  }

  void offerDraw() => netOfferDraw();

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    netSendChat(text: t);
    state = state.copyWith(chat: [...state.chat, ChatMessage(t, true)]);
  }

  void respondDraw(bool accept) {
    netRespondDraw(accept: accept);
    state = state.copyWith(drawOfferIncoming: false);
    if (accept) {
      ref.read(gameControllerProvider.notifier).lanSetResult(LanResultCode.drawAgreed);
    }
  }

  void leave() {
    netLeave();
    _sub?.cancel();
    _sub = null;
    state = const LanGameState();
  }
}
