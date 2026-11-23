class ChatItemModel {
  final String chatRoomId;
  final String peerUid;
  final String peerName;
  final String peerEmail;
  final String peerProfileImage;
  final String lastMessage;
  final int lastMessageTime;
  final int unreadCount;

  ChatItemModel({
    required this.chatRoomId,
    required this.peerUid,
    required this.peerName,
    required this.peerEmail,
    this.peerProfileImage = '',
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'peerUid': peerUid,
      'peerName': peerName,
      'peerEmail': peerEmail,
      'peerProfileImage': peerProfileImage,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
    };
  }

  factory ChatItemModel.fromMap(Map<dynamic, dynamic> map) {
    return ChatItemModel(
      chatRoomId: map['chatRoomId']?.toString() ?? '',
      peerUid: map['peerUid']?.toString() ?? '',
      peerName: map['peerName']?.toString() ?? 'User',
      peerEmail: map['peerEmail']?.toString() ?? '',
      peerProfileImage: map['peerProfileImage']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastMessageTime: map['lastMessageTime'] is int
          ? map['lastMessageTime'] as int
          : int.tryParse(map['lastMessageTime']?.toString() ?? '0') ?? 0,
      unreadCount: map['unreadCount'] is int
          ? map['unreadCount'] as int
          : int.tryParse(map['unreadCount']?.toString() ?? '0') ?? 0,
    );
  }
}
