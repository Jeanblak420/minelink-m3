import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A self-contained colour scheme for the chat overlay. The messenger re-skins
/// itself from the selected palette (its inner surfaces read these colours, not
/// the global app theme), so the user can theme chat independently of the app.
///
/// Ported from the MineLink design's `chat-theme.js` (itself adapted from the
/// CPS Smart Central chat theme provider) — MineLink cyan/navy palette at [0];
/// the app default is Nord (see [ChatThemes.defaultId]).
///
/// ## Why this lives in `core/design/tokens/` and not in the chat feature
///
/// Moved here 2026-08-15 while closing S5-19, and the reasoning is the point.
/// This file is **eighteen complete palettes**, each carrying its own `isDark`
/// and a matched foreground for every surface it defines. It is a token table
/// in exactly the sense [MlTokens] is one — the raw scale — and the `no-raw-
/// color-hex` guard was counting all 144 of its literals as design-system
/// violations.
///
/// They are not violations. The guard's stated fault is "raw `Color(0x…)`
/// bypasses MlTokens/MlSemantic and **breaks light mode**". A `ChatPalette`
/// cannot break light mode: it declares which mode it *is* and supplies both
/// sides. There is also no token that could express `Nord`'s `#88C0D0` — Nord
/// is a named external palette, and re-deriving it from MineLink cyan would
/// produce something that is no longer Nord.
///
/// So the honest resolution was to move the table into the layer that is
/// allowed to hold literals, **and to make that permission explicit**: the
/// guard's roots now include `lib/core`, exempting only
/// `lib/core/design/tokens/`. Before this change `lib/core` was not scanned at
/// all, so the move traded 144 counted-but-legitimate literals for 40 real
/// ones in `core/widgets/` and `core/design/shell/` that nothing had ever
/// looked at. The rule it leaves behind is stateable in one line: *raw colour
/// literals live in the token layer and nowhere else.*
@immutable
class ChatPalette {
  final String id;
  final String name;
  final bool isDark;
  final Color header;
  final Color headerText;
  final Color body;
  final Color bodyText;
  final Color bodySubtle;
  final Color divider;
  final Color tabSelectedBg;
  final Color accent;
  final Color accentText;
  final Color incomingBubble;
  final Color incomingText;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color senderName;
  final Color bubbleSeparator;

  const ChatPalette({
    required this.id,
    required this.name,
    required this.isDark,
    required this.header,
    required this.headerText,
    required this.body,
    required this.bodyText,
    required this.bodySubtle,
    required this.divider,
    required this.tabSelectedBg,
    required this.accent,
    required this.accentText,
    required this.incomingBubble,
    required this.incomingText,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.senderName,
    required this.bubbleSeparator,
  });
}

/// The messenger palettes, in display order. Index 0 is the MineLink palette;
/// the app-wide default is [defaultId] (Nord) — applied to any user who hasn't
/// explicitly chosen a chat theme.
abstract final class ChatThemes {
  static const String defaultId = 'nord';

  /// Resolves a palette by id, falling back to the [defaultId] palette (then to
  /// the first) for a null/unknown id — so the default lives in one place.
  static ChatPalette byId(String? id) => palettes.firstWhere(
        (p) => p.id == id,
        orElse: () => palettes.firstWhere(
          (p) => p.id == defaultId,
          orElse: () => palettes.first,
        ),
      );

  static const List<ChatPalette> palettes = [
    ChatPalette(
      id: 'minelink', name: 'MineLink', isDark: false,
      header: Color(0xFF0B192E), headerText: Color(0xFFE6F6FB),
      body: Color(0xFFF4F8FB), bodyText: Color(0xFF0F1B2D),
      bodySubtle: Color(0xFF5A6B80), divider: Color(0xFFE2ECF3),
      tabSelectedBg: Color(0xFF0F2338), accent: MlTokens.accent,
      accentText: Color(0xFF04222B), incomingBubble: Color(0xFFFFFFFF),
      incomingText: Color(0xFF0F1B2D), outgoingBubble: MlTokens.accent,
      outgoingText: Color(0xFF04222B), senderName: Color(0xFF0E7C93),
      bubbleSeparator: Color(0xFFE2ECF3),
    ),
    ChatPalette(
      id: 'deep-navy', name: 'Deep Navy', isDark: true,
      header: Color(0xFF08121F), headerText: Color(0xFFDCEBFF),
      body: Color(0xFF0B1725), bodyText: Color(0xFFE8EFF8),
      bodySubtle: Color(0xFF8DA2BC), divider: Color(0xFF1E3149),
      tabSelectedBg: Color(0xFF0E1D30), accent: Color(0xFF2CC7E4),
      accentText: Color(0xFF04222B), incomingBubble: Color(0xFF152740),
      incomingText: Color(0xFFEAF2FB), outgoingBubble: Color(0xFF0E86A8),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF6FD8EC),
      bubbleSeparator: Color(0xFF2A4A66),
    ),
    ChatPalette(
      id: 'midnight', name: 'Midnight Blue', isDark: true,
      header: Color(0xFF0B1220), headerText: Color(0xFFE2ECFF),
      body: Color(0xFF070C18), bodyText: Color(0xFFE8EEFB),
      bodySubtle: Color(0xFFA3B3CC), divider: Color(0xFF22314F),
      tabSelectedBg: Color(0xFF111A2E), accent: Color(0xFF4F8CFF),
      accentText: Color(0xFF06122B), incomingBubble: Color(0xFF182748),
      incomingText: Color(0xFFEAF1FF), outgoingBubble: Color(0xFF2B6BFF),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF8FB6FF),
      bubbleSeparator: Color(0xFF33456B),
    ),
    ChatPalette(
      id: 'forest', name: 'Forest Green', isDark: true,
      header: Color(0xFF0E1A12), headerText: Color(0xFFE5F5E9),
      body: Color(0xFF0A130D), bodyText: Color(0xFFEAF5EE),
      bodySubtle: Color(0xFFA9C2B0), divider: Color(0xFF22412C),
      tabSelectedBg: Color(0xFF142519), accent: Color(0xFF66BB6A),
      accentText: Color(0xFF0A1A0E), incomingBubble: Color(0xFF1A2E22),
      incomingText: Color(0xFFEFFAF1), outgoingBubble: Color(0xFF2E7D32),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF9CDFA1),
      bubbleSeparator: Color(0xFF2F5A3A),
    ),
    ChatPalette(
      id: 'royal', name: 'Royal Purple', isDark: true,
      header: Color(0xFF160A22), headerText: Color(0xFFF0E6FF),
      body: Color(0xFF0E0716), bodyText: Color(0xFFEEE6FA),
      bodySubtle: Color(0xFFB7A6CF), divider: Color(0xFF3A2359),
      tabSelectedBg: Color(0xFF1E0F30), accent: Color(0xFFB388FF),
      accentText: Color(0xFF160A22), incomingBubble: Color(0xFF291846),
      incomingText: Color(0xFFF3EBFF), outgoingBubble: Color(0xFF6A1B9A),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFD5BBFF),
      bubbleSeparator: Color(0xFF4A2F6B),
    ),
    ChatPalette(
      id: 'crimson', name: 'Crimson', isDark: true,
      header: Color(0xFF1C0A0E), headerText: Color(0xFFFFE5E9),
      body: Color(0xFF110608), bodyText: Color(0xFFFAE8EC),
      bodySubtle: Color(0xFFD0A3AC), divider: Color(0xFF5A2130),
      tabSelectedBg: Color(0xFF260F14), accent: Color(0xFFFF5C7A),
      accentText: Color(0xFF1C0A0E), incomingBubble: Color(0xFF3A1620),
      incomingText: Color(0xFFFFEBEF), outgoingBubble: Color(0xFFC2185B),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFFF9DB2),
      bubbleSeparator: Color(0xFF6B2F3F),
    ),
    ChatPalette(
      id: 'steel', name: 'Steel Gray', isDark: true,
      header: Color(0xFF1A1D21), headerText: Color(0xFFE6E9EE),
      body: Color(0xFF12151A), bodyText: Color(0xFFE8ECEF),
      bodySubtle: Color(0xFFB0B8BF), divider: Color(0xFF39424A),
      tabSelectedBg: Color(0xFF22262B), accent: Color(0xFFB0BEC5),
      accentText: Color(0xFF12151A), incomingBubble: Color(0xFF252A31),
      incomingText: Color(0xFFEEF1F4), outgoingBubble: Color(0xFF455A64),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFCFD8DC),
      bubbleSeparator: Color(0xFF3F4A52),
    ),
    ChatPalette(
      id: 'ocean', name: 'Ocean Teal', isDark: true,
      header: Color(0xFF062126), headerText: Color(0xFFE0F7FA),
      body: Color(0xFF03171B), bodyText: Color(0xFFE6F6F8),
      bodySubtle: Color(0xFF9FC1C6), divider: Color(0xFF124049),
      tabSelectedBg: Color(0xFF0A2C32), accent: Color(0xFF26C6DA),
      accentText: Color(0xFF03171B), incomingBubble: Color(0xFF103E45),
      incomingText: Color(0xFFE6F7FA), outgoingBubble: Color(0xFF00838F),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF7CEAF5),
      bubbleSeparator: Color(0xFF1C5560),
    ),
    ChatPalette(
      id: 'sunset', name: 'Sunset', isDark: true,
      header: Color(0xFF221016), headerText: Color(0xFFFFE6EB),
      body: Color(0xFF170A10), bodyText: Color(0xFFFAEAEE),
      bodySubtle: Color(0xFFC9A6AE), divider: Color(0xFF552F38),
      tabSelectedBg: Color(0xFF2B141C), accent: Color(0xFFFF7043),
      accentText: Color(0xFF170A10), incomingBubble: Color(0xFF35192A),
      incomingText: Color(0xFFFFEDED), outgoingBubble: Color(0xFFD84315),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFFFB199),
      bubbleSeparator: Color(0xFF6B3F48),
    ),
    ChatPalette(
      id: 'charcoal', name: 'Charcoal', isDark: true,
      header: Color(0xFF161616), headerText: Color(0xFFE6E6E6),
      body: Color(0xFF0D0D0D), bodyText: Color(0xFFEDEDED),
      bodySubtle: Color(0xFFB3B3B3), divider: Color(0xFF333333),
      tabSelectedBg: Color(0xFF1E1E1E), accent: Color(0xFFE0E0E0),
      accentText: Color(0xFF0D0D0D), incomingBubble: Color(0xFF242424),
      incomingText: Color(0xFFF2F2F2), outgoingBubble: Color(0xFF424242),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFEFEFEF),
      bubbleSeparator: Color(0xFF3F3F3F),
    ),
    ChatPalette(
      id: 'snow', name: 'Snow', isDark: false,
      header: Color(0xFFF1F4F8), headerText: Color(0xFF1A1F2A),
      body: Color(0xFFFAFBFD), bodyText: Color(0xFF1A1F2A),
      bodySubtle: Color(0xFF5A6473), divider: Color(0xFFDBE4EE),
      tabSelectedBg: Color(0xFFFFFFFF), accent: Color(0xFF1976D2),
      accentText: Color(0xFFFFFFFF), incomingBubble: Color(0xFFE8EEF6),
      incomingText: Color(0xFF101521), outgoingBubble: Color(0xFF1976D2),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF0D47A1),
      bubbleSeparator: Color(0xFFCDD9E8),
    ),
    ChatPalette(
      id: 'cream', name: 'Cream', isDark: false,
      header: Color(0xFFFDF5E6), headerText: Color(0xFF2A1E0A),
      body: Color(0xFFFFF9EE), bodyText: Color(0xFF2A1E0A),
      bodySubtle: Color(0xFF7A6240), divider: Color(0xFFECDCB6),
      tabSelectedBg: Color(0xFFFFFAEB), accent: Color(0xFFB8860B),
      accentText: Color(0xFFFFFFFF), incomingBubble: Color(0xFFF6E9CB),
      incomingText: Color(0xFF1E1605), outgoingBubble: Color(0xFFB8860B),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF8B5A00),
      bubbleSeparator: Color(0xFFE2CF9E),
    ),
    ChatPalette(
      id: 'sage', name: 'Sage', isDark: false,
      header: Color(0xFFEEF4EC), headerText: Color(0xFF12241A),
      body: Color(0xFFF6FAF5), bodyText: Color(0xFF12241A),
      bodySubtle: Color(0xFF4F6A55), divider: Color(0xFFD6E5D3),
      tabSelectedBg: Color(0xFFF7FBF6), accent: Color(0xFF2E7D32),
      accentText: Color(0xFFFFFFFF), incomingBubble: Color(0xFFE2EEDF),
      incomingText: Color(0xFF0E1F14), outgoingBubble: Color(0xFF2E7D32),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF1B5E20),
      bubbleSeparator: Color(0xFFC9DDC5),
    ),
    ChatPalette(
      id: 'rose', name: 'Rose', isDark: false,
      header: Color(0xFFFCE9EE), headerText: Color(0xFF2A0A14),
      body: Color(0xFFFFF6F8), bodyText: Color(0xFF2A0A14),
      bodySubtle: Color(0xFF7A4858), divider: Color(0xFFF0D5DF),
      tabSelectedBg: Color(0xFFFFF4F7), accent: Color(0xFFC2185B),
      accentText: Color(0xFFFFFFFF), incomingBubble: Color(0xFFF7DCE4),
      incomingText: Color(0xFF1F0810), outgoingBubble: Color(0xFFC2185B),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFF880E4F),
      bubbleSeparator: Color(0xFFE8C3D0),
    ),
    ChatPalette(
      id: 'dracula', name: 'Dracula', isDark: true,
      header: Color(0xFF282A36), headerText: Color(0xFFF8F8F2),
      body: Color(0xFF1E1F29), bodyText: Color(0xFFF8F8F2),
      bodySubtle: Color(0xFFBFBFD9), divider: Color(0xFF44475A),
      tabSelectedBg: Color(0xFF343746), accent: Color(0xFFFF79C6),
      accentText: Color(0xFF1E1F29), incomingBubble: Color(0xFF3C3F52),
      incomingText: Color(0xFFF8F8F2), outgoingBubble: Color(0xFFBD93F9),
      outgoingText: Color(0xFF1E1F29), senderName: Color(0xFF8BE9FD),
      bubbleSeparator: Color(0xFF565A70),
    ),
    ChatPalette(
      id: 'nord', name: 'Nord', isDark: true,
      header: Color(0xFF2E3440), headerText: Color(0xFFECEFF4),
      body: Color(0xFF242933), bodyText: Color(0xFFECEFF4),
      bodySubtle: Color(0xFFB7C0CC), divider: Color(0xFF3F4757),
      tabSelectedBg: Color(0xFF3B4252), accent: Color(0xFF88C0D0),
      accentText: Color(0xFF242933), incomingBubble: Color(0xFF3B4252),
      incomingText: Color(0xFFECEFF4), outgoingBubble: Color(0xFF5E81AC),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFA3D5E1),
      bubbleSeparator: Color(0xFF4A5468),
    ),
    ChatPalette(
      id: 'cobalt', name: 'Cobalt', isDark: true,
      header: Color(0xFF002240), headerText: Color(0xFFFFFFFF),
      body: Color(0xFF001833), bodyText: Color(0xFFFFFFFF),
      bodySubtle: Color(0xFFB3D4FF), divider: Color(0xFF0A3D69),
      tabSelectedBg: Color(0xFF003355), accent: Color(0xFFFFC600),
      accentText: Color(0xFF001833), incomingBubble: Color(0xFF003B6F),
      incomingText: Color(0xFFFFFFFF), outgoingBubble: Color(0xFF1F7AC2),
      outgoingText: Color(0xFFFFFFFF), senderName: Color(0xFFFFC600),
      bubbleSeparator: Color(0xFF0F4D85),
    ),
    ChatPalette(
      id: 'high-contrast', name: 'High Contrast', isDark: true,
      header: Color(0xFF000000), headerText: Color(0xFFFFFFFF),
      body: Color(0xFF000000), bodyText: Color(0xFFFFFFFF),
      bodySubtle: Color(0xFFE0E0E0), divider: Color(0xFF444400),
      tabSelectedBg: Color(0xFF111111), accent: Color(0xFFFFEB3B),
      accentText: Color(0xFF000000), incomingBubble: Color(0xFF1A1A1A),
      incomingText: Color(0xFFFFFFFF), outgoingBubble: Color(0xFFFFEB3B),
      outgoingText: Color(0xFF000000), senderName: Color(0xFFFFEB3B),
      bubbleSeparator: Color(0xFF5A5A20),
    ),
  ];
}

/// Chat's **semantic** hues — the ones that mean something rather than skin
/// something.
///
/// Deliberately separate from [ChatPalette]. A palette is a look the user
/// chose; these carry state, and state must not change meaning because
/// somebody picked Dracula. "Delivered" is red in all eighteen themes.
///
/// Named at S5-19, where they were 22 literals scattered through
/// `chat_dock.dart` — including the same `#EF4444` written out five times for
/// three different concepts (offline, unread separator, delivered tick), which
/// is how a later change to one of them silently changes the other two.
abstract final class MlChatTone {
  const MlChatTone._();

  /// Presence. Reuses the app's live/inactive pair so a chat roster and a
  /// console presence dot cannot disagree about what green means.
  static const online = MlTokens.green500;
  static const offline = MlTokens.red500;

  /// The unread-messages separator rule and its label.
  static const unread = MlTokens.red500;

  // ── Delivery ticks ─────────────────────────────────────────────────────
  // Two pairs, because a tick is drawn in two places against two different
  // grounds: on a conversation ROW (the palette's body surface) and inside my
  // own BUBBLE (the palette's outgoing fill, which may be dark even in a light
  // theme). Picking the row pair for a bubble is the bug this split prevents.
  //
  // Scheme, from the drop: sent = the surface's own muted ink, delivered =
  // red, read = vivid blue. Red for delivered-but-unread is unusual and
  // deliberate — it is the one state the sender can act on.
  static const readOnRowDark = Color(0xFF40C4FF);
  static const readOnRowLight = Color(0xFF0B4FCC);
  static const readOnBubbleDark = Color(0xFF66E0FF);
  static const readOnBubbleLight = Color(0xFF0A3FB0);
  static const deliveredOnBubbleDark = Color(0xFFFF6B6B);
  static const deliveredOnBubbleLight = Color(0xFFC62828);

  /// A support-ticket pill mid-flight. Amber rather than [MlTokens.orange500]:
  /// orange is the app's *departure/logout* hue, and a ticket in progress is
  /// neither.
  static const inProgress = Color(0xFFEA8C1E);

  /// A link, mention or @-handle inside a message, on a dark palette. Lighter
  /// than [MlTokens.accent] because it has to read against eighteen different
  /// bubble fills, several of which are already cyan.
  static const linkOnDark = Color(0xFF7FD4FF);

  /// Scrim behind the dock when it opens over the page, and the drop shadow
  /// under a floating chat control.
  static const scrim = Color(0x59000000);
  static const shadow = Color(0x4D000000);
}
