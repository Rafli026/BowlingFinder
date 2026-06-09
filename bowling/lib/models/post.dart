class Post {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String adminId;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> favorites;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.adminId,
    required this.createdAt,
    this.likes = const [],
    this.favorites = const [],
    this.comments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'adminId': adminId,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'favorites': favorites,
      'comments': comments.map((c) => c.toMap()).toList(),
    };
  }

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    List<Comment> comments = [];
    if (map['comments'] != null) {
      comments = (map['comments'] as List)
          .map((c) => Comment.fromMap(c as Map<String, dynamic>))
          .toList();
    }

    return Post(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      adminId: map['adminId'] ?? '',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      likes: List<String>.from(map['likes'] ?? []),
      favorites: List<String>.from(map['favorites'] ?? []),
      comments: comments,
    );
  }
}

class Comment {
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Pengguna',
      text: map['text'] ?? '',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
