import 'package:flutter/widgets.dart';

/// App-wide latest pointer (mouse) position in **global** logical coordinates.
///
/// Fed by a single [Listener] high in the shell (see `ChatDock`), so any widget
/// can react to the cursor's position anywhere on screen — not just when the
/// pointer is directly over it. Used by [LiveChatIcon] to make the chat disc
/// "look at" the cursor across the whole window.
///
/// Desktop/web only in practice (touch devices emit no hover); on those the
/// value simply stays null and consumers fall back to their idle behaviour.
class PointerPositionTracker {
  PointerPositionTracker._();

  static final PointerPositionTracker instance = PointerPositionTracker._();

  /// Latest global pointer position, or null if unknown (e.g. touch-only).
  final ValueNotifier<Offset?> position = ValueNotifier<Offset?>(null);

  void update(Offset global) {
    position.value = global;
  }
}
