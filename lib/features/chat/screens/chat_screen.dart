import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/core/widgets/chat_widget.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/widgets/file_upload_widget.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Provider for the current chat messages
final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, List<ChatMessage>, String>(
      (ref, chatRoomId) => ChatMessagesNotifier(chatRoomId),
    );

/// Notifier for chat messages
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final String chatRoomId;
  final _supabase = SupabaseConfig.client;
  final _storageAssetService = StorageAssetService();
  RealtimeChannel? _channel;

  ChatMessagesNotifier(this.chatRoomId) : super([]) {
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('timestamp', ascending: true);

      final resolvedMessages = await _storageAssetService
          .resolveChatMessageRecords(
            response.map((json) => Map<String, dynamic>.from(json as Map)),
          );

      final messages = resolvedMessages
          .map(
            (json) => ChatMessage(
              id: json['id'],
              content: json['content'],
              senderId: json['sender_id'],
              senderName: json['sender_name'],
              senderAvatarUrl: json['sender_avatar_url'],
              timestamp: DateTime.parse(json['timestamp']),
              isRead: json['is_read'] ?? false,
              fileUrl: json['file_url'],
              fileType: json['file_type'],
              fileName: json['file_name'],
            ),
          )
          .toList();

      state = messages;
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _subscribeToMessages() {
    _channel = _supabase.channel('chat_room_$chatRoomId');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: chatRoomId,
          ),
          callback: (_) => _loadMessages(),
        )
        .subscribe();
  }

  Future<void> sendMessage(
    String content,
    String senderId,
    String senderName,
    String? senderAvatarUrl, {
    String? replyToId,
  }) async {
    try {
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();
      final senderAvatarReference = _storageAssetService.toStorableReference(
        senderAvatarUrl,
        bucketQualified: true,
      );

      await _supabase.from('chat_messages').insert({
        'id': messageId,
        'chat_room_id': chatRoomId,
        'content': content,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar_url': senderAvatarReference,
        'timestamp': timestamp.toIso8601String(),
        'is_read': false,
        'reply_to_id': replyToId,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> sendFileMessage(
    String content,
    String senderId,
    String senderName,
    String? senderAvatarUrl,
    String fileUrl,
    String fileType,
    String fileName,
  ) async {
    try {
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();
      final senderAvatarReference = _storageAssetService.toStorableReference(
        senderAvatarUrl,
        bucketQualified: true,
      );
      final fileReference =
          _storageAssetService.toStorableReference(
            fileUrl,
            defaultBucketName: StorageAssetService.chatFilesBucket,
          ) ??
          fileUrl;

      await _supabase.from('chat_messages').insert({
        'id': messageId,
        'chat_room_id': chatRoomId,
        'content': content,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar_url': senderAvatarReference,
        'timestamp': timestamp.toIso8601String(),
        'is_read': false,
        'file_url': fileReference,
        'file_type': fileType,
        'file_name': fileName,
      });
    } catch (e) {
      debugPrint('Error sending file message: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _supabase.rpc(
        'mark_chat_messages_read',
        params: {
          'target_chat_room_id': chatRoomId,
          'target_message_id': messageId,
        },
      );

      state = state.map((message) {
        if (message.id == messageId) {
          return ChatMessage(
            id: message.id,
            content: message.content,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatarUrl: message.senderAvatarUrl,
            timestamp: message.timestamp,
            isRead: true,
            fileUrl: message.fileUrl,
            fileType: message.fileType,
            fileName: message.fileName,
          );
        }
        return message;
      }).toList();
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<void> markRoomAsRead(String currentUserId) async {
    try {
      await _supabase.rpc(
        'mark_chat_messages_read',
        params: {'target_chat_room_id': chatRoomId},
      );

      state = state.map((message) {
        if (message.senderId == currentUserId || message.isRead) {
          return message;
        }

        return ChatMessage(
          id: message.id,
          content: message.content,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatarUrl: message.senderAvatarUrl,
          timestamp: message.timestamp,
          isRead: true,
          fileUrl: message.fileUrl,
          fileType: message.fileType,
          fileName: message.fileName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error marking room as read: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

/// Provider for the typing users in a chat room
final typingUsersProvider = StateNotifierProvider.autoDispose
    .family<TypingUsersNotifier, List<String>, String>(
      (ref, chatRoomId) => TypingUsersNotifier(chatRoomId),
    );

/// Notifier for typing users
class TypingUsersNotifier extends StateNotifier<List<String>> {
  final String chatRoomId;
  final _supabase = SupabaseConfig.client;
  RealtimeChannel? _presenceChannel;

  TypingUsersNotifier(this.chatRoomId) : super([]) {
    _subscribeToPresence();
  }

  void _subscribeToPresence() {
    _presenceChannel = _supabase.channel(
      'presence_$chatRoomId',
      opts: const RealtimeChannelConfig(self: true),
    );

    _presenceChannel!
        .onPresenceSync((payload) {
          final typingUsers = <String>[];

          // Get the presence state from the channel
          final presenceStates = _presenceChannel!.presenceState();

          // Iterate through all presence states
          for (final presenceState in presenceStates) {
            for (final presence in presenceState.presences) {
              // Check if the user is typing
              if (presence.payload['isTyping'] == true) {
                // Add the username to the list of typing users
                final username = presence.payload['username'] as String?;
                if (username != null && username.isNotEmpty) {
                  typingUsers.add(username);
                }
              }
            }
          }

          // Update the state with the list of typing users
          state = typingUsers;
        })
        .subscribe((status, [error]) {
          debugPrint('Presence status: $status');
          if (error != null) {
            debugPrint('Presence error: $error');
          }
        });
  }

  void setTyping(String userId, String username, bool isTyping) {
    _presenceChannel?.track({
      'user_id': userId,
      'username': username,
      'isTyping': isTyping,
    });
  }

  @override
  void dispose() {
    _presenceChannel?.untrack();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}

/// A screen that displays a chat interface
class ChatScreen extends ConsumerStatefulWidget {
  final ChatRoom chatRoom;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;
  final List<AvatarUser> participants;

  const ChatScreen({
    super.key,
    required this.chatRoom,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatarUrl,
    required this.participants,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  bool _isAttaching = false;
  final ChatWidgetController _chatController = ChatWidgetController();
  bool _isMarkingRoomRead = false;
  late final TypingUsersNotifier _typingUsersNotifier;

  @override
  void initState() {
    super.initState();
    _typingUsersNotifier = ref.read(
      typingUsersProvider(widget.chatRoom.id).notifier,
    );
  }

  @override
  void dispose() {
    _typingUsersNotifier.setTyping(
      widget.currentUserId,
      widget.currentUserName,
      false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.chatRoom.id));
    final messagesNotifier = ref.read(
      chatMessagesProvider(widget.chatRoom.id).notifier,
    );
    final typingUsers = ref
        .watch(typingUsersProvider(widget.chatRoom.id))
        .where((username) => username != widget.currentUserName)
        .toList();
    final hasUnreadIncomingMessages = messages.any(
      (message) => message.senderId != widget.currentUserId && !message.isRead,
    );

    if (hasUnreadIncomingMessages && !_isMarkingRoomRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _isMarkingRoomRead) {
          return;
        }

        _isMarkingRoomRead = true;
        await messagesNotifier.markRoomAsRead(widget.currentUserId);
        _isMarkingRoomRead = false;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatRoom.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // File upload widget (conditionally shown)
          if (_isAttaching)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FileUploadWidget(
                bucketName: 'chat_files',
                folderPath: widget.chatRoom.id,
                returnStoragePath: true,
                onUploadComplete: (fileUrls) {
                  if (fileUrls.isNotEmpty) {
                    final fileName = _fileNameFromUrl(fileUrls[0]);
                    final fileType = _getFileType(fileName);

                    // Send file message
                    ref
                        .read(chatMessagesProvider(widget.chatRoom.id).notifier)
                        .sendFileMessage(
                          'Sent a file',
                          widget.currentUserId,
                          widget.currentUserName,
                          widget.currentUserAvatarUrl,
                          fileUrls[0],
                          fileType,
                          fileName,
                        );
                  }

                  setState(() {
                    _isAttaching = false;
                  });
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error uploading file. ${friendlyError(error)}')),
                  );

                  setState(() {
                    _isAttaching = false;
                  });
                },
                buttonText: 'Select File',
                imagesOnly: false,
                allowMultiple: false,
              ),
            ),

          // Chat widget
          Expanded(
            child: ChatWidget(
              controller: _chatController,
              messages: messages,
              currentUserId: widget.currentUserId,
              onSendMessage: (message, {String? replyToId}) {
                ref
                    .read(chatMessagesProvider(widget.chatRoom.id).notifier)
                    .sendMessage(
                      message,
                      widget.currentUserId,
                      widget.currentUserName,
                      widget.currentUserAvatarUrl,
                      replyToId: replyToId,
                    );

                // Set typing to false when sending a message
                _typingUsersNotifier.setTyping(
                  widget.currentUserId,
                  widget.currentUserName,
                  false,
                );
              },
              onTypingChanged: (isTyping) {
                _typingUsersNotifier.setTyping(
                  widget.currentUserId,
                  widget.currentUserName,
                  isTyping,
                );
              },
              onAttachFile: () {
                setState(() {
                  _isAttaching = true;
                });
              },
              onMessageLongPress: (message) {
                // Show message options
                showModalBottomSheet(
                  context: context,
                  builder: (context) => _buildMessageOptions(context, message),
                );
              },
              title: widget.chatRoom.name,
              participants: widget.participants,
              showAvatarsInHeader: true,
              typingUsers: typingUsers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageOptions(BuildContext context, ChatMessage message) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Reply'),
            onTap: () {
              Navigator.pop(context);
              _chatController.replyTo(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: const Text('Copy Text'),
            onTap: () {
              Navigator.pop(context);
              _copyMessageText(message.content);
            },
          ),
          if (message.fileUrl != null)
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: Text(message.fileName ?? 'Attachment'),
              subtitle: Text(message.fileType ?? 'File attachment'),
            ),
        ],
      ),
    );
  }

  Future<void> _copyMessageText(String value) async {
    if (value.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final createdLabel = DateFormat(
          'MMM d, yyyy • h:mm a',
        ).format(MlTime.sast(widget.chatRoom.createdAt));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatRoom.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created $createdLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Participants',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.participants.isEmpty)
                  Text(
                    'Participant details will appear as soon as the room metadata loads.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...widget.participants.map((participant) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: participant.avatarUrl != null
                            ? NetworkImage(participant.avatarUrl!)
                            : null,
                        child: participant.avatarUrl == null
                            ? Text(
                                participant.name.isNotEmpty
                                    ? participant.name[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      title: Text(participant.name),
                      subtitle: Text(
                        participant.status ??
                            (participant.id == widget.currentUserId
                                ? 'You'
                                : 'Participant'),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image/$extension';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  String _fileNameFromUrl(String value) {
    final uri = Uri.tryParse(value);
    final rawName = uri == null || uri.pathSegments.isEmpty
        ? value.split('/').last
        : uri.pathSegments.last;
    return rawName.replaceFirst(
      RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}_'),
      '',
    );
  }
}
