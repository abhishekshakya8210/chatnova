import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talking_app/models/user_model.dart';
import 'package:talking_app/models/message_model.dart';
import 'package:talking_app/models/chat_item_model.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  static const String databaseUrl =
      'https://chattingapp-62d61-default-rtdb.firebaseio.com';

  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );

  DatabaseReference get usersRef => _db.ref('users');
  DatabaseReference get chatRoomsRef => _db.ref('chat_rooms');
  DatabaseReference get userChatsRef => _db.ref('user_chats');

  /// Generate or retrieve deterministic unique chat room ID for 2 users
  String getChatRoomId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  /// Sync current user profile to Realtime Database upon login or registration
  Future<void> syncCurrentUser(User user, {String? customName}) async {
    final userRef = usersRef.child(user.uid);
    final snapshot = await userRef.get();

    final normalizedEmail = (user.email ?? '').toLowerCase().trim();
    final name = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : (user.displayName != null && user.displayName!.trim().isNotEmpty)
            ? user.displayName!
            : (normalizedEmail.contains('@')
                ? normalizedEmail.split('@').first
                : 'User');

    if (!snapshot.exists) {
      final newUser = UserModel(
        uid: user.uid,
        name: name,
        email: normalizedEmail,
        profileImage: user.photoURL ?? '',
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      await userRef.set(newUser.toMap());
    } else {
      // Update email/name if needed while preserving existing fields
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{
        'email': normalizedEmail,
        'isOnline': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      };
      if (customName != null && customName.trim().isNotEmpty) {
        updates['name'] = customName.trim();
      } else if (data['name'] == null || data['name'].toString().isEmpty) {
        updates['name'] = name;
      }
      await userRef.update(updates);
    }

    setupPresence(user.uid);
  }

  /// Listen to connection state and maintain online/offline status
  void setupPresence(String uid) {
    final connectedRef = _db.ref('.info/connected');
    final userStatusRef = usersRef.child(uid);

    connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value == true;
      if (isConnected) {
        // Set offline when disconnected
        userStatusRef.onDisconnect().update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });

        // Set online now
        userStatusRef.update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
  }

  /// Set offline on explicit logout
  Future<void> setOffline(String uid) async {
    try {
      await usersRef.child(uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Get single user profile by UID
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await usersRef.child(uid).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return UserModel.fromMap(snapshot.value as Map<dynamic, dynamic>);
  }

  /// Stream user profile for real-time presence (online/offline/lastSeen)
  Stream<UserModel?> getUserStream(String uid) {
    return usersRef.child(uid).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return UserModel.fromMap(event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  /// Search user by normalized email
  Future<UserModel?> searchUserByEmail(String rawEmail) async {
    final normalizedEmail = rawEmail.toLowerCase().trim();
    if (normalizedEmail.isEmpty) return null;

    try {
      // 1. Primary approach: Indexed query on email
      final querySnapshot =
          await usersRef.orderByChild('email').equalTo(normalizedEmail).get();

      if (querySnapshot.exists && querySnapshot.value != null) {
        final data = querySnapshot.value as Map<dynamic, dynamic>;
        final firstEntry = data.values.first as Map<dynamic, dynamic>;
        return UserModel.fromMap(firstEntry);
      }
    } catch (_) {
      // Fallback in case of index delay
    }

    // 2. Fallback scan across users
    final allUsersSnapshot = await usersRef.get();
    if (allUsersSnapshot.exists && allUsersSnapshot.value != null) {
      final map = allUsersSnapshot.value as Map<dynamic, dynamic>;
      for (final value in map.values) {
        if (value is Map<dynamic, dynamic>) {
          final email = (value['email']?.toString() ?? '').toLowerCase().trim();
          if (email == normalizedEmail) {
            return UserModel.fromMap(value);
          }
        }
      }
    }

    return null;
  }

  /// Send a text message in real-time
  Future<void> sendMessage({
    required String chatRoomId,
    required UserModel sender,
    required UserModel receiver,
    required String text,
  }) async {
    final cleanMessage = text.trim();
    if (cleanMessage.isEmpty) return;

    final messagesRef = chatRoomsRef.child('$chatRoomId/messages');
    final newMessageRef = messagesRef.push();
    final messageId = newMessageRef.key!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final messageModel = MessageModel(
      messageId: messageId,
      senderId: sender.uid,
      receiverId: receiver.uid,
      message: cleanMessage,
      timestamp: timestamp,
      messageType: 'text',
      isSeen: false,
    );

    // Save message to chat room
    await newMessageRef.set(messageModel.toMap());

    // Update sender's recent chat record
    final senderChat = ChatItemModel(
      chatRoomId: chatRoomId,
      peerUid: receiver.uid,
      peerName: receiver.name,
      peerEmail: receiver.email,
      peerProfileImage: receiver.profileImage,
      lastMessage: cleanMessage,
      lastMessageTime: timestamp,
      unreadCount: 0,
    );
    await userChatsRef
        .child('${sender.uid}/$chatRoomId')
        .set(senderChat.toMap());

    // Update receiver's recent chat record (with unread count increment)
    final receiverChatRef = userChatsRef.child('${receiver.uid}/$chatRoomId');
    final currentReceiverChatSnapshot = await receiverChatRef.get();

    int nextUnreadCount = 1;
    if (currentReceiverChatSnapshot.exists &&
        currentReceiverChatSnapshot.value != null) {
      final currentMap =
          currentReceiverChatSnapshot.value as Map<dynamic, dynamic>;
      final currentCount = int.tryParse(currentMap['unreadCount']?.toString() ?? '0') ?? 0;
      nextUnreadCount = currentCount + 1;
    }

    final receiverChat = ChatItemModel(
      chatRoomId: chatRoomId,
      peerUid: sender.uid,
      peerName: sender.name,
      peerEmail: sender.email,
      peerProfileImage: sender.profileImage,
      lastMessage: cleanMessage,
      lastMessageTime: timestamp,
      unreadCount: nextUnreadCount,
    );
    await receiverChatRef.set(receiverChat.toMap());
  }

  /// Real-time stream of messages in a chat room sorted by timestamp
  Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
    return chatRoomsRef
        .child('$chatRoomId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<MessageModel> messages = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            messages.add(MessageModel.fromMap(value));
          }
        });
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
      return messages;
    });
  }

  /// Mark unread messages as seen and reset conversation unread count
  Future<void> markMessagesAsSeen({
    required String chatRoomId,
    required String currentUserId,
  }) async {
    try {
      final messagesRef = chatRoomsRef.child('$chatRoomId/messages');
      final snapshot = await messagesRef
          .orderByChild('receiverId')
          .equalTo(currentUserId)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic> && value['isSeen'] != true) {
            updates['$key/isSeen'] = true;
          }
        });
        if (updates.isNotEmpty) {
          await messagesRef.update(updates);
        }
      }

      // Reset unread count for current user
      await userChatsRef.child('$currentUserId/$chatRoomId').update({
        'unreadCount': 0,
      });
    } catch (_) {}
  }

  /// Stream of all conversation items for current user, sorted by lastMessageTime descending
  Stream<List<ChatItemModel>> getUserChatsStream(String currentUserId) {
    return userChatsRef.child(currentUserId).onValue.map((event) {
      final List<ChatItemModel> chats = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            chats.add(ChatItemModel.fromMap(value));
          }
        });
        chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      }
      return chats;
    });
  }
}
