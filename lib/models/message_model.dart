class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final int timestamp;
  final String messageType;
  final bool isSeen;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.messageType = 'text',
    this.isSeen = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'messageType': messageType,
      'isSeen': isSeen,
    };
  }

  factory MessageModel.fromMap(Map<dynamic, dynamic> map) {
    return MessageModel(
      messageId: map['messageId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp'] is int
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      messageType: map['messageType']?.toString() ?? 'text',
      isSeen: map['isSeen'] == true,
    );
  }

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? message,
    int? timestamp,
    String? messageType,
    bool? isSeen,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      isSeen: isSeen ?? this.isSeen,
    );
  }
}
