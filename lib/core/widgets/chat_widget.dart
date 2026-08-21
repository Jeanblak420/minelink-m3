import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/features/chat/services/attachment_url.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/design/tokens/ml_chat_palettes.dart';

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
  });
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

                // Group messages by sender
                final isFirstInGroup =
                    index == 0 ||
                    widget.messages[index - 1].senderId != message.senderId;
                final isLastInGroup =
                    index == widget.messages.length - 1 ||
                    widget.messages[index + 1].senderId != message.senderId;

                return _buildMessageItem(
                  context,
                  message,
                  isCurrentUser,
                  isFirstInGroup,
                  isLastInGroup,
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
  ) {
    final semantic = MlSemantic.of(context);

    return GestureDetector(
      onLongPress: widget.onMessageLongPress != null
          ? () => widget.onMessageLongPress!(message)
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: isFirstInGroup ? 8.0 : 2.0,
          bottom: isLastInGroup ? 8.0 : 2.0,
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
                        // Message text
                        if (message.content.isNotEmpty)
                          Text(
                            message.content,
                            style: context.mlText.bodyLarge.copyWith(
                              color: isCurrentUser ? MlTokens.inkOnFill : semantic.textStrong,
                            ),
                          ),

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
                                    color: isCurrentUser ? MlTokens.overlayLight.withValues(alpha: 0.68) : semantic.textFaint,
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
                                      : MlTokens.inkOnFill70,
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
    final fg = mine ? MlTokens.inkOnFill : semantic.textFaint;
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
      final chipFg = mine ? MlTokens.inkOnFill : MlTokens.accentHover;
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
                hintText: 'Type a message…',
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
