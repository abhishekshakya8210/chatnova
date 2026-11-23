class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profileImage;
  final bool isOnline;
  final int lastSeen;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage = '',
    this.isOnline = false,
    this.lastSeen = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email.toLowerCase().trim(),
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? (map['email']?.toString().split('@').first ?? 'User'),
      email: map['email']?.toString() ?? '',
      profileImage: map['profileImage']?.toString() ?? '',
      isOnline: map['isOnline'] == true,
      lastSeen: map['lastSeen'] is int
          ? map['lastSeen'] as int
          : int.tryParse(map['lastSeen']?.toString() ?? '0') ?? 0,
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? profileImage,
    bool? isOnline,
    int? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
