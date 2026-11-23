import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talking_app/models/chat_item_model.dart';
import 'package:talking_app/models/user_model.dart';
import 'package:talking_app/services/chat_service.dart';
import 'package:talking_app/screens/chat_screen.dart';
import 'package:talking_app/screens/search_user_screen.dart';
import 'package:talking_app/loginmathod/loginscreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureUserSynced();
  }

  void _ensureUserSynced() {
    final user = _auth.currentUser;
    if (user != null) {
      _chatService.syncCurrentUser(user);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = _auth.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.resumed) {
      _chatService.setupPresence(user.uid);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _chatService.setOffline(user.uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out from ChatNova?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _chatService.setOffline(uid);
      }
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Loginscreen()),
          (route) => false,
        );
      }
    }
  }

  String _formatChatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == dt.year &&
        yesterday.month == dt.month &&
        yesterday.day == dt.day;

    if (isToday) {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (isYesterday) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
    }
  }

  void _navigateToChat(ChatItemModel chat) {
    final peerUser = UserModel(
      uid: chat.peerUid,
      name: chat.peerName,
      email: chat.peerEmail,
      profileImage: chat.peerProfileImage,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatRoomId: chat.chatRoomId,
          peerUser: peerUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final currentEmail = currentUser?.email ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF6C5CE7), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'ChatNova',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF1E2432),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search by Email',
            icon: const Icon(Icons.search_rounded, color: Color(0xFF1E2432), size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUserScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            onPressed: () => _signOut(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // WhatsApp-inspired Search Bar at the top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchUserScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF6C5CE7), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search user by registered email...',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // User info pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Logged in as: $currentEmail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Real-time Chat List
          Expanded(
            child: StreamBuilder<List<ChatItemModel>>(
              stream: _chatService.getUserChatsStream(currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 56,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'No Conversations Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2432),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              'Search a friend\'s registered email to start your first one-to-one chat.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchUserScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.person_search_rounded, size: 20),
                            label: const Text(
                              'Search User by Email',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 0.6,
                    indent: 72,
                    color: Color(0xFFEEEEEE),
                  ),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return _buildConversationTile(chat);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // WhatsApp-inspired Floating Action Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Start New Chat',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchUserScreen()),
          );
        },
        child: const Icon(Icons.chat_rounded, size: 26),
      ),
    );
  }

  Widget _buildConversationTile(ChatItemModel chat) {
    final hasUnread = chat.unreadCount > 0;

    return StreamBuilder<UserModel?>(
      stream: _chatService.getUserStream(chat.peerUid),
      builder: (context, snapshot) {
        final liveUser = snapshot.data;
        final isOnline = liveUser?.isOnline ?? false;
        final displayName = liveUser?.name ?? chat.peerName;
        final displayImage = liveUser?.profileImage ?? chat.peerProfileImage;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => _navigateToChat(chat),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                backgroundImage: displayImage.isNotEmpty
                    ? NetworkImage(displayImage)
                    : null,
                child: displayImage.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C5CE7),
                        ),
                      )
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ED573),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
              fontSize: 16,
              color: const Color(0xFF1E2432),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                color: hasUnread ? const Color(0xFF1E2432) : Colors.grey.shade600,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatChatTime(chat.lastMessageTime),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  color: hasUnread ? const Color(0xFF25D366) : Colors.grey.shade500,
                ),
              ),
              if (hasUnread) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366), // WhatsApp badge green
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
