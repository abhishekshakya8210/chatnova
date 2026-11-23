import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talking_app/models/user_model.dart';
import 'package:talking_app/models/message_model.dart';
import 'package:talking_app/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final UserModel peerUser;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.peerUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _currentUserModel;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _markSeen();
  }

  Future<void> _loadCurrentUser() async {
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser == null) return;

    final user = await _chatService.getUser(currentFirebaseUser.uid);
    if (mounted) {
      setState(() {
        _currentUserModel = user ??
            UserModel(
              uid: currentFirebaseUser.uid,
              name: currentFirebaseUser.displayName ??
                  (currentFirebaseUser.email?.split('@').first ?? 'User'),
              email: currentFirebaseUser.email ?? '',
              profileImage: currentFirebaseUser.photoURL ?? '',
            );
      });
    }
  }

  void _markSeen() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null) {
      _chatService.markMessagesAsSeen(
        chatRoomId: widget.chatRoomId,
        currentUserId: currentUid,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_currentUserModel == null) {
      await _loadCurrentUser();
      if (_currentUserModel == null) return;
    }

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        sender: _currentUserModel!,
        receiver: widget.peerUser,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatMessageTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatLastSeen(int timestamp) {
    if (timestamp == 0) return 'offline';
    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'last seen just now';
    } else if (diff.inHours < 1) {
      return 'last seen ${diff.inMinutes}m ago';
    } else if (diff.inDays < 1 && now.day == dt.day) {
      return 'last seen today at ${_formatMessageTime(timestamp)}';
    } else {
      return 'last seen on ${dt.day}/${dt.month} at ${_formatMessageTime(timestamp)}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2), // WhatsApp-like classic wallpaper tint
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E2432)),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<UserModel?>(
          stream: _chatService.getUserStream(widget.peerUser.uid),
          builder: (context, snapshot) {
            final user = snapshot.data ?? widget.peerUser;
            final isOnline = user.isOnline;

            return Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      backgroundImage: user.profileImage.isNotEmpty
                          ? NetworkImage(user.profileImage)
                          : null,
                      child: user.profileImage.isEmpty
                          ? Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7),
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ED573),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2432),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? 'online' : _formatLastSeen(user.lastSeen),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? const Color(0xFF2ED573) : Colors.grey.shade600,
                          fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Real-time Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessagesStream(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  );
                }

                final messages = snapshot.data ?? [];

                // Mark unseen messages as seen
                if (messages.isNotEmpty) {
                  final hasUnread = messages.any((m) =>
                      m.receiverId == currentUid && !m.isSeen);
                  if (hasUnread) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markSeen();
                    });
                  }
                  _scrollToBottom();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 24, color: Color(0xFF6C5CE7)),
                          const SizedBox(height: 8),
                          const Text(
                            'Say Hello 👋',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E2432),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Messages are stored securely in Firebase Realtime Database.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUid;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Message Input Field & Send Button
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE7FFDB) : Colors.white, // WhatsApp green tint for sender
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 3),
              bottomRight: Radius.circular(isMe ? 3 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                message.message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E2432),
                  height: 1.3,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isSeen
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 15,
                      color: message.isSeen
                          ? const Color(0xFF34B7F1) // WhatsApp blue tick
                          : Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.transparent,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleSendMessage,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)], // WhatsApp Green gradient
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4025D366),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
