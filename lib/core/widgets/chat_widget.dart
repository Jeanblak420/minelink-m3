import 'dart:async';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/features/chat/services/attachment_url.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/design/tokens/ml_chat_palettes.dart';

/// A mention as the dock writes it into `chat_messages.content`.
///
/// Both chat surfaces read the same table, so a message composed in the dock
/// — where mentions are a real feature — can appear in this thread. Rendered
/// raw, its quote preview would read `@[Thandi Mokoena](user:8f2c…)`.
final RegExp _kMentionToken = RegExp(r'@\[([^\]]+)\]\(user:([^)]+)\)');

/// Replaces mention tokens with a plain `@Display`, as the dock does for its
/// own list and reply previews.
String _stripMentionTokens(String text) =>
    text.replaceAllMapped(_kMentionToken, (m) => '@${m.group(1)}');

/// [bubble], tinted 14% AWAY from [ink].
///
/// The counterpart of [ChatPalette.quoteGround] for the legacy thread, and the
/// same guarantee: moving the ground away from the ink cannot reduce their
/// contrast, so a quote drawn on this is at least as legible as the bubble it
/// sits in. Tinting the other way — with the ink itself — is what produced a
/// 3.17:1 quote heading in the dock and a 3.44:1 one here.
Color _quoteGround(Color bubble, Color ink) => Color.alphaBlend(
      // `overlay*`, not `Colors.*`: this is white and black as a translucent
      // LAYER, where the alpha is the decision — which is the distinction
      // those tokens exist to make, and which `no-material-colors` enforces.
      (ink.computeLuminance() > 0.5
              ? MlTokens.overlayDark
              : MlTokens.overlayLight)
          .withValues(alpha: 0.14),
      bubble,
    );

class ChatWidgetController {
  void Function(ChatMessage message)? _replyToMessage;

  void replyTo(ChatMessage message) {
    _replyToMessage?.call(message);
  }
}

/// A model representing a chat message
class ChatMessage {
  /// The message ID
  final String id;

  /// The message content
  final String content;

  /// The sender's ID
  final String senderId;

  /// The sender's name
  final String senderName;

  /// The sender's avatar URL
  final String? senderAvatarUrl;

  /// The timestamp when the message was sent
  final DateTime timestamp;

  /// Whether the message has been read
  final bool isRead;

  /// The URL of any attached file
  final String? fileUrl;

  /// The type of the attached file
  final String? fileType;

  /// The name of the attached file
  final String? fileName;

  /// The id of the message this one replies to, or null.
  ///
  /// This field is the reason a reply was invisible for the life of this
  /// screen. The composer already captured a reply target, and
  /// `ChatMessagesNotifier.sendMessage` already wrote `reply_to_id` to
  /// `chat_messages` — but this model had nowhere to put the column on the way
  /// back, so `_loadMessages` dropped it and the bubble had nothing to draw.
  /// The write worked; nothing read it. A reply looked sent and then arrived
  /// as an ordinary message, which is worse than not offering reply at all —
  /// the sender believes the quote went with it.
  ///
  /// The dock's own [ChatMessage] (`messaging_models.dart`) has carried this
  /// field all along; the two models disagreeing is what hid it.
  final String? replyToId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.timestamp,
    this.isRead = false,
    this.fileUrl,
    this.fileType,
    this.fileName,
    this.replyToId,
  });

  /// Whether this message carries a file, matching the dock model's getter of
  /// the same name so the two quote blocks can preview alike.
  bool get hasAttachment => fileUrl != null && fileUrl!.isNotEmpty;

  /// Builds a message from a `chat_messages` row.
  ///
  /// **A named factory rather than a map literal at the call site, because a
  /// map literal at the call site is the bug this had.** `ChatScreen` wrote
  /// `reply_to_id` on the way out and hand-built a `ChatMessage` on the way
  /// in; the hand-built one simply had no line for that column, so replies
  /// were written and never read for the life of the screen. Nothing threw —
  /// `.select()` returned the column, and the mapping quietly dropped it.
  ///
  /// With one factory there is one place to add a column, and
  /// `test/features/chat/chat_message_row_test.dart` reads `chat_messages`'
  /// real column list and fails if any of them arrives here unmapped. That is
  /// the guard the original code could not have: a missing field in a literal
  /// looks exactly like a field that was never meant to be read.
  ///
  /// The dock's own model has had [ChatMessage.fromJson] all along. The two
  /// surfaces disagreeing about how a row becomes a message is the root of it.
  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        content: row['content'] as String? ?? '',
        senderId: row['sender_id'] as String,
        senderName: row['sender_name'] as String? ?? '',
        senderAvatarUrl: row['sender_avatar_url'] as String?,
        timestamp: DateTime.parse(row['timestamp'] as String),
        isRead: (row['is_read'] as bool?) ?? false,
        fileUrl: row['file_url'] as String?,
        fileType: row['file_type'] as String?,
        fileName: row['file_name'] as String?,
        replyToId: row['reply_to_id'] as String?,
      );
}

/// A widget that displays a chat interface
class ChatWidget extends StatefulWidget {
  /// The list of messages to display
  final List<ChatMessage> messages;

  /// The current user's ID
  final String currentUserId;

  /// Callback when a message is sent
  final Function(String message, {String? replyToId}) onSendMessage;

  /// Callback when a file is attached
  final Function()? onAttachFile;

  /// Callback when a message is long-pressed
  final Function(ChatMessage message)? onMessageLongPress;

  /// The title of the chat
  final String? title;

  /// The list of users in the chat
  final List<AvatarUser>? participants;

  /// Whether to show the user avatars in the header
  final bool showAvatarsInHeader;

  /// Whether to show the timestamp for each message
  final bool showMessageTimestamp;

  /// Whether to show read receipts
  final bool showReadReceipts;

  /// Whether to enable file attachments
  final bool enableAttachments;

  /// Whether to show the typing indicator
  final bool showTypingIndicator;

  /// The list of users who are currently typing
  final List<String> typingUsers;

  /// Callback when the local typing state changes
  final ValueChanged<bool>? onTypingChanged;

  /// Optional controller for driving reply state from a parent widget
  final ChatWidgetController? controller;

  /// Trailing controls for the header row — the thread's own actions.
  ///
  /// This exists so a host does not have to draw a SECOND bar to hold them.
  /// `ChatScreen` did: it wrapped this widget in `Scaffold(appBar: AppBar(...))`
  /// carrying the room name and an info button, while this widget drew the
  /// room name again immediately underneath — and the whole thing sits inside
  /// the portal `ShellRoute`, whose own top bar carries the room name too.
  /// Three bars and the same name twice in the first 200px of a phone.
  final List<Widget> headerActions;

  const ChatWidget({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.onSendMessage,
    this.onAttachFile,
    this.onMessageLongPress,
    this.title,
    this.participants,
    this.showAvatarsInHeader = true,
    this.showMessageTimestamp = true,
    this.showReadReceipts = true,
    this.enableAttachments = true,
    this.showTypingIndicator = true,
    this.typingUsers = const [],
    this.onTypingChanged,
    this.controller,
    this.headerActions = const [],
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyToId;
  ChatMessage? _replyToMessage;
  bool _isTyping = false;

  /// One key per rendered message, so a quote can scroll to its original.
  ///
  /// The same mechanism the dock uses (`chat_dock.dart` `_msgKeys` +
  /// [Scrollable.ensureVisible]) rather than a second invention — two chat
  /// surfaces in one product should not disagree about what tapping a quote
  /// does.
  final Map<String, GlobalKey> _msgKeys = {};

  /// The id of the message currently flashed by a quote tap, if any.
  ///
  /// Landing on the original silently is not an answer — on a dense thread the
  /// reader cannot tell which bubble was meant. It clears itself.
  String? _highlightedId;
  Timer? _highlightTimer;

  GlobalKey _keyFor(String id) => _msgKeys.putIfAbsent(id, () => GlobalKey());

  void _scrollToMessage(String id) {
    final ctx = _msgKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: MlMotion.of(context, MlMotion.enter),
      alignment: 0.3,
      curve: Curves.easeOut,
    );
    _highlightTimer?.cancel();
    setState(() => _highlightedId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._replyToMessage = _setReplyTarget;
    // Scroll to bottom when widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._replyToMessage = null;
      widget.controller?._replyToMessage = _setReplyTarget;
    }
    // Scroll to bottom when new messages are added
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _isTyping = false;
    widget.controller?._replyToMessage = null;
    // Before the controllers: the callback calls setState, and a timer that
    // outlives the element fires into a disposed State.
    _highlightTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message, replyToId: _replyToId);
      _messageController.clear();
      _notifyTyping(false);
      setState(() {
        _replyToId = null;
        _replyToMessage = null;
      });
    }
  }

  void _handleMessageChanged(String value) {
    _notifyTyping(value.trim().isNotEmpty);
    if (mounted) {
      setState(() {});
    }
  }

  void _notifyTyping(bool isTyping) {
    if (_isTyping == isTyping) {
      return;
    }

    _isTyping = isTyping;
    widget.onTypingChanged?.call(isTyping);
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToMessage = null;
    });
  }

  void _setReplyTarget(ChatMessage message) {
    setState(() {
      _replyToId = message.id;
      _replyToMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Built once per frame rather than once per bubble: resolving a quote by
    // scanning `widget.messages` inside `itemBuilder` is O(n) per row, which
    // on a long thread is O(n²) during a scroll.
    final byId = {for (final m in widget.messages) m.id: m};

    return Column(
      children: [
        // Chat header
        if (widget.title != null ||
            widget.headerActions.isNotEmpty ||
            (widget.participants != null && widget.showAvatarsInHeader))
          _buildChatHeader(),

        // Messages list
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isCurrentUser = message.senderId == widget.currentUserId;

                // The original this message answers, if it is still in the
                // thread. `ChatScreen` loads the whole room rather than a
                // window, so an in-room reply always resolves; a reply whose
                // original was deleted resolves to null and the bubble simply
                // renders without a quote. `reply_to_id` is `ON DELETE SET
                // NULL` in Postgres, so that case is normally the column
                // going null rather than a dangling id — this handles both.
                final repliedTo = message.replyToId == null
                    ? null
                    : byId[message.replyToId];

                // Group messages by sender
                final isFirstInGroup =
                    index == 0 ||
                    widget.messages[index - 1].senderId != message.senderId;
                final isLastInGroup =
                    index == widget.messages.length - 1 ||
                    widget.messages[index + 1].senderId != message.senderId;

                return KeyedSubtree(
                  key: _keyFor(message.id),
                  child: _buildMessageItem(
                    context,
                    message,
                    isCurrentUser,
                    isFirstInGroup,
                    isLastInGroup,
                    repliedTo,
                  ),
                );
              },
            ),
          ),
        ),

        // Typing indicator
        if (widget.showTypingIndicator && widget.typingUsers.isNotEmpty)
          _buildTypingIndicator(),

        // Reply indicator
        if (_replyToMessage != null) _buildReplyIndicator(),

        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader() {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        border: Border(bottom: BorderSide(color: semantic.divider)),
        boxShadow: MlTokens.shadowSm,
      ),
      child: Row(
        children: [
          if (widget.participants != null && widget.showAvatarsInHeader)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: AvatarStack(
                users: widget.participants!,
                avatarSize: 34,
                maxDisplayed: 3,
              ),
            ),
          if (widget.title != null)
            Expanded(
              child: Text(
                widget.title!,
                style: context.mlText.titleMedium.copyWith(
                  color: semantic.textStrong,
                  fontWeight: FontWeight.w800,
                ),
                // TWO lines: a room between two companies is named for both,
                // and "Roadhaul Logistics ↔ Iron Hills Mining" (247px) had
                // 238px on a phone — so the header of the thread you are IN
                // could not say who it was with.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          ...widget.headerActions,
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    ChatMessage message,
    bool isCurrentUser,
    bool isFirstInGroup,
    bool isLastInGroup,
    ChatMessage? repliedTo,
  ) {
    final semantic = MlSemantic.of(context);
    final isHighlighted = _highlightedId == message.id;

    return GestureDetector(
      onLongPress: widget.onMessageLongPress != null
          ? () => widget.onMessageLongPress!(message)
          : null,
      // Flashed for a moment when a quote scrolls here, then cleared. Landing
      // on the original without saying which one it is answers nothing on a
      // dense thread — every bubble looks like the one you were sent to.
      child: AnimatedContainer(
        duration: MlMotion.of(context, MlMotion.enter),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          top: isFirstInGroup ? 8.0 : 2.0,
          bottom: isLastInGroup ? 8.0 : 2.0,
        ),
        decoration: BoxDecoration(
          color: isHighlighted
              ? MlTone.accent.well(Theme.of(context).brightness)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(MlTokens.rMd),
        ),
        child: Row(
          mainAxisAlignment: isCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for other users
            if (!isCurrentUser && isLastInGroup)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                // A WELL, not a bare letter. `backgroundColor:
                // Colors.transparent` drew no circle at all, so every sender
                // without a photo — which is nearly everyone — appeared as a
                // single grey character floating in the gutter beside their
                // bubble. Same fault, same day, as `AvatarStack` and the
                // Messages screen's platform-account avatar.
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: message.senderAvatarUrl == null
                        ? MlTokens.accent.withValues(alpha: 0.14)
                        : null,
                    image: message.senderAvatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                                message.senderAvatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: message.senderAvatarUrl == null
                      ? Text(
                          message.senderName.trim().isNotEmpty
                              ? message.senderName.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: MlTokens.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              )
            else if (!isCurrentUser && !isLastInGroup)
              const SizedBox(width: 40),

            // Message content
            //
            // CAPPED AT 460, the same measure as the Messages screen's bubble.
            // Un-capped, a `Flexible` in a full-width row let one sentence run
            // the whole workspace: "Understood. Two trucks moved to 05:00."
            // was 1,300px wide on a desktop, which is not a chat bubble, it is
            // a banner. Two chat surfaces in one product cannot disagree about
            // how wide a message is.
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name for other users
                  if (!isCurrentUser && isFirstInGroup)
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 13,
                          color: MlTokens.accentHover,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                  // Message bubble
                  Container(
                    padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? MlTokens.accent
                          : semantic.surfaceCard,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(MlShape.large),
                        topRight: const Radius.circular(MlShape.large),
                        bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                      ),
                      border: isCurrentUser
                          ? null
                          : Border.all(color: semantic.borderCard),
                      boxShadow: MlTokens.shadowXs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The quoted original, above the reply's own text.
                        // Tapping it scrolls to the message it names.
                        if (repliedTo != null) ...[
                          _buildQuotedOriginal(repliedTo, isCurrentUser),
                          const SizedBox(height: 6),
                        ],

                        // Message text
                        if (message.content.isNotEmpty)
                          _buildMessageText(message.content, isCurrentUser),

                        // File attachment
                        if (message.fileUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: _buildFileAttachment(message, isCurrentUser),
                          ),

                        // Timestamp + read receipt
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.showMessageTimestamp)
                                Text(
                                  MlTime.clock(message.timestamp),
                                  style: context.mlText.code(
                                    // `inkOnAccent`, not white at 68%.
                                    //
                                    // An outgoing bubble is the brand cyan,
                                    // and white on it is 1.81:1 before any
                                    // alpha; at 68% the timestamp measured
                                    // **1.46:1**. `overlayLight` is white as
                                    // a translucent LAYER - a sheen, a scrim
                                    // - and it was being used as ink, which
                                    // is the distinction the token file draws
                                    // in its own doc comment.
                                    color: isCurrentUser
                                        ? MlTokens.inkOnAccent
                                        : semantic.textFaint,
                                    size: 11,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              if (isCurrentUser && widget.showReadReceipts) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message.isRead ? Icons.done_all : Icons.done,
                                  size: 15,
                                  color: message.isRead
                                      ? MlChatTone.linkOnDark
                                      : MlTokens.inkOnAccent
                                          .withValues(alpha: 0.72),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// P3-52 / P3-53 (S2-3, S2-4): `fileUrl` is **not a URL**. Both attachment
  /// buckets went private on 2026-08-12, so the stored value is a
  /// bucket-qualified object path that must be signed before anything can open
  /// it — the same contract `chat_dock.dart` already honours.
  ///
  /// Handing the raw stored value to `CachedNetworkImage` (as this widget did)
  /// renders a permanent broken image, and handing it to `launchUrl` passes a
  /// *relative* URI that `Uri.tryParse` accepts and the launcher then rejects.
  /// Neither leaks anything — the bucket is private — but a private bucket with
  /// a public-URL reader is a broken feature, not a secured one.
  ///
  /// Both buckets held 0 objects at the cutover, so nothing in production is
  /// currently broken by this; the first attachment sent from this screen would
  /// have been.
  Widget _buildFileAttachment(ChatMessage message, [bool mine = false]) {
    return FutureBuilder<String?>(
      future: resolveAttachmentUrlCached(message.fileUrl),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _attachmentPending(message, mine, spinner: true);
        }
        final signed = snap.data;
        if (signed == null) {
          return _attachmentPending(message, mine, spinner: false);
        }
        return _attachmentBody(message, mine, signed);
      },
    );
  }

  /// Loading, and the honest "unavailable" state. A null resolve means the
  /// viewer is not a participant of that room, or the object is gone — stated
  /// plainly rather than shown as a broken image (the rule P10-D2 settled for
  /// POD photos).
  Widget _attachmentPending(
    ChatMessage message,
    bool mine, {
    required bool spinner,
  }) {
    final semantic = MlSemantic.of(context);
    final fg = mine ? MlTokens.inkOnAccent : semantic.textFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine
            ? MlTokens.overlayLight.withValues(alpha: 0.16)
            : semantic.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg.withValues(alpha: 0.5),
              ),
            )
          else
            Icon(Icons.lock_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              spinner
                  ? (message.fileName ?? 'Attachment')
                  : 'Attachment unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.titleSmall.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentBody(ChatMessage message, bool mine, String signedUrl) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = MlSemantic.of(context);

    // Determine file type
    final fileType = message.fileType ?? '';
    final attachmentName = (message.fileName ?? message.fileUrl ?? '')
        .toLowerCase();
    final isImage =
        fileType.contains('image') ||
        attachmentName.endsWith('.jpg') ||
        attachmentName.endsWith('.jpeg') ||
        attachmentName.endsWith('.png') ||
        attachmentName.endsWith('.gif');

    if (isImage) {
      return InkWell(
        onTap: () => _openAttachment(signedUrl),
        borderRadius: MlShape.radiusSmall,
        child: ClipRRect(
          borderRadius: MlShape.radiusSmall,
          child: CachedNetworkImage(
            imageUrl: signedUrl,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 200,
              height: 150,
              color: scheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: 200,
              height: 150,
              color: scheme.surfaceContainerHighest,
              child: const Icon(Icons.error),
            ),
          ),
        ),
      );
    } else {
      // Generic file attachment
      final chipFg = mine ? MlTokens.inkOnAccent : MlTokens.accentHover;
      return InkWell(
        onTap: () => _openAttachment(signedUrl),
        borderRadius: BorderRadius.circular(MlTokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine
                ? MlTokens.overlayLight.withValues(alpha: 0.16)
                : semantic.surfaceSunken,
            borderRadius: BorderRadius.circular(MlTokens.rSm),
            border: Border.all(
              color: mine
                  ? MlTokens.overlayLight.withValues(alpha: 0.24)
                  : semantic.borderCard,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForFile(message.fileName ?? ''),
                size: 18,
                color: chipFg,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.fileName ?? 'File',
                  style: context.mlText.titleSmall.copyWith(color: chipFg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _openAttachment(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(fileUrl);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _getIconForFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildTypingIndicator() {
    final typingText = widget.typingUsers.length == 1
        ? '${widget.typingUsers[0]} is typing…'
        : '${widget.typingUsers.length} people are typing…';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        typingText,
        style: const TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 13,
          color: MlTokens.accentHover,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// A message body, with any `@[Display](user:id)` mention tokens drawn as
  /// chips instead of as their raw source.
  ///
  /// **Both chat surfaces read the same `chat_messages` table**, and the dock
  /// — where @-mentioning is a real feature — writes mentions into `content`
  /// in that form. This screen rendered `content` through a plain [Text], so a
  /// message composed in the dock and opened here read
  /// `Morning @[Thandi Mokoena](user:8f2c…) — 06:00?`. Machinery, shown to a
  /// user, in the body of their message.
  ///
  /// The colours are deliberately NOT a new pair. The chip keeps the bubble's
  /// own ink and marks itself with weight and a ground tinted AWAY from that
  /// ink — the same rule as [_quoteGround] — so a mention is as legible as the
  /// sentence it sits in, on either bubble, without inventing a hue that would
  /// then need measuring on both.
  Widget _buildMessageText(String content, bool isCurrentUser) {
    final semantic = MlSemantic.of(context);
    final ink =
        isCurrentUser ? MlTokens.inkOnAccent : semantic.textStrong;
    final base = context.mlText.bodyLarge.copyWith(color: ink);

    final matches = _kMentionToken.allMatches(content).toList();
    if (matches.isEmpty) return Text(content, style: base);

    final chipBg = _quoteGround(
      isCurrentUser ? MlTokens.accent : semantic.surfaceCard,
      ink,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: content.substring(last, m.start)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: MlShape.radiusSmall,
            ),
            child: Text(
              '@${m.group(1)}',
              style: base.copyWith(fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ),
      ));
      last = m.end;
    }
    if (last < content.length) {
      spans.add(TextSpan(text: content.substring(last)));
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }

  /// The quoted original, drawn inside the replying bubble.
  ///
  /// Deliberately the same vocabulary as [_buildReplyIndicator] — the bar, the
  /// sender's name, one clamped line of preview — because they are the two
  /// halves of one gesture: what you saw above the composer when you wrote the
  /// reply is what the reader sees above the reply itself. They also share the
  /// dock's shape (`chat_dock.dart` `_ReplyQuote`), so the product has one
  /// idea of what a quote looks like rather than three.
  ///
  /// Colour: solid rungs on both sides, never an alpha on the ink. On the
  /// outgoing bubble the ground is [MlTokens.accent] and the ink is
  /// [MlTokens.inkOnAccent] — a very dark teal — so the quote's own ground
  /// tints with `inkOnAccent`, which DARKENS the cyan and moves the dark ink
  /// further from its ground rather than closer to it. Tinting with the ink's
  /// opposite here would have quietly cut the contrast of every quoted line.
  Widget _buildQuotedOriginal(ChatMessage original, bool isCurrentUser) {
    final semantic = MlSemantic.of(context);

    // The quote's ground is always the BUBBLE, tinted AWAY from that bubble's
    // ink — never toward it, and never the accent well.
    //
    // The first version of this used `MlTone.accent.well()` with
    // `accentHover` written on it, and the render reported it at 3.44:1: a
    // cyan ink on a cyan-tinted ground, which is the same fault the dock's
    // `_ReplyQuote` had (`ChatPalette.quoteGround`) and the same one §3.3
    // records for `_TxnRow` and `_DispatchStatusChip`. Tinting away instead
    // means separation can only increase, so a quote is legible wherever the
    // bubble under it is legible — which both of these already are.
    final Color barColor;
    final Color bgColor;
    final Color nameColor;
    final Color previewColor;
    if (isCurrentUser) {
      barColor = MlTokens.inkOnAccent;
      bgColor = _quoteGround(MlTokens.accent, MlTokens.inkOnAccent);
      nameColor = MlTokens.inkOnAccent;
      previewColor = MlTokens.inkOnAccent;
    } else {
      barColor = MlTokens.accent;
      bgColor = _quoteGround(semantic.surfaceCard, semantic.textStrong);
      nameColor = semantic.textStrong;
      previewColor = semantic.textMuted;
    }

    // An attachment with no words is still an answerable message; quoting it
    // as an empty box tells the reader nothing about what was replied to.
    final String preview;
    if (original.hasAttachment &&
        (original.fileName?.trim().isNotEmpty ?? false)) {
      preview = '📎 ${original.fileName!.trim()}';
    } else {
      final stripped = _stripMentionTokens(original.content.trim());
      preview = stripped.length > 80
          ? '${stripped.substring(0, 80)}…'
          : stripped;
    }

    return Semantics(
      button: true,
      label: 'Replying to ${original.senderName}. Show the original message.',
      child: GestureDetector(
        onTap: () => _scrollToMessage(original.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: MlShape.radiusSmall,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: MlShape.radiusExtraSmall,
                  ),
                ),
                const SizedBox(width: 8),
                // `Expanded`, not `Flexible`: this is the only child that may
                // grow, and an unflexed child in a `Row` is handed unbounded
                // width, so `ellipsis` would never engage on a long quote.
                // CLAUDE.md §10.4.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        original.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.labelMedium.copyWith(
                          color: nameColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (preview.isNotEmpty)
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.bodySmall
                              .copyWith(color: previewColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: MlTone.accent.well(brightness),
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: semantic.borderAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: MlTokens.accentHover),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderName}',
                  style: const TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 12,
                    color: MlTokens.accentHover,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodyMedium.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 17, color: semantic.textFaint),
            onPressed: _cancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final semantic = MlSemantic.of(context);
    final hasDraft = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        border: Border(top: BorderSide(color: semantic.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          if (widget.enableAttachments && widget.onAttachFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 1),
              child: IconButton(
                tooltip: 'Attach file',
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: MlTokens.accent,
                onPressed: widget.onAttachFile,
              ),
            ),

          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _handleMessageChanged,
              onSubmitted: (_) => _sendMessage(),
              style: context.mlText.bodyLarge.copyWith(
                color: semantic.textStrong,
              ),
              cursorColor: MlTokens.accent,
              decoration: InputDecoration(
                // "Write a message…", the wording the other two composers
                // use. This product has three message boxes — this one, the
                // Messages screen's and the chat dock's — and this was the
                // only one that said "Type". Photographed side by side on
                // `screen-messages-phone-dark` and
                // `screen-chat-thread-phone-dark`.
                hintText: 'Write a message…',
                hintStyle: context.mlText.bodyLarge.copyWith(
                  color: semantic.textFaint,
                ),
                border: OutlineInputBorder(
                  borderRadius: MlShape.radiusLargeIncreased,
                  borderSide: BorderSide(color: semantic.borderStrong),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: MlShape.radiusLargeIncreased,
                  borderSide: BorderSide(color: semantic.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: MlShape.radiusLargeIncreased,
                  borderSide: const BorderSide(
                    color: MlTokens.accent,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: semantic.surfaceSunken,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
            ),
          ),

          // Send button
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Material(
              color: hasDraft ? MlTokens.accent : semantic.surfaceSunken,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: hasDraft ? _sendMessage : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: hasDraft ? MlTokens.inkOnFill : semantic.textFaint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
