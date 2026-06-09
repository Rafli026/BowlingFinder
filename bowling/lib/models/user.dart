// User model untuk menyimpan data user dengan role
class AppUser {
  final String id;
  final String email;
  final String role; // 'admin' atau 'user'
  final DateTime createdAt;
  final String displayName;
  final String photoUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName = '',
    this.photoUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
    );
  }
}
