import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/post.dart';

class PostServices {
  final CollectionReference _postsCollection = FirebaseFirestore.instance
      .collection('bowling_venues');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addPost(
    String name,
    String description,
    Uint8List imageBytes,
    double lat,
    double lng,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User tidak terautentikasi');
    }

    final imageUrl = _buildFirestoreImageDataUrl(imageBytes);

    Post newPost = Post(
      id: '',
      name: name,
      description: description,
      imageUrl: imageUrl,
      latitude: lat,
      longitude: lng,
      adminId: currentUser.uid,
      createdAt: DateTime.now(),
    );

    await _postsCollection.add(newPost.toMap());
  }

  String _buildFirestoreImageDataUrl(Uint8List imageBytes) {
    final compressedBytes = _compressImageForFirestore(imageBytes);
    return 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
  }

  Uint8List _compressImageForFirestore(Uint8List imageBytes) {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return imageBytes;

    var maxDimension = 800;
    var quality = 68;
    var resized = decodedImage;
    Uint8List encoded = Uint8List.fromList(
      img.encodeJpg(resized, quality: quality),
    );

    while (encoded.length > 520 * 1024 && maxDimension >= 420) {
      resized = img.copyResize(
        decodedImage,
        width: decodedImage.width >= decodedImage.height ? maxDimension : null,
        height: decodedImage.height > decodedImage.width ? maxDimension : null,
      );
      encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      maxDimension -= 140;
      quality -= 8;
      if (quality < 42) quality = 42;
    }

    return encoded;
  }

  Stream<List<Post>> getPosts() {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Post.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  Stream<Post?> getPostStream(String postId) {
    return _postsCollection.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Post.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> deletePost(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User tidak terautentikasi');
    }

    // Ambil data post untuk cek adminId
    final doc = await _postsCollection.doc(postId).get();
    if (doc.exists) {
      final postData = doc.data() as Map<String, dynamic>;
      if (postData['adminId'] != currentUser.uid) {
        throw Exception('Hanya admin pemilik post yang bisa menghapus');
      }

      // Hapus gambar dari storage
      try {
        final imageUrl = postData['imageUrl'] ?? '';
        if (imageUrl.isNotEmpty) {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        }
      } catch (e) {
        // Lanjutkan jika gagal hapus gambar
      }

      // Hapus post dari firestore
      await _postsCollection.doc(postId).delete();
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final doc = await _postsCollection.doc(postId).get();
    if (doc.exists) {
      final postData = doc.data() as Map<String, dynamic>;
      List<String> likes = List<String>.from(postData['likes'] ?? []);

      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }

      await _postsCollection.doc(postId).update({'likes': likes});
    }
  }

  Future<void> toggleFavorite(String postId, String userId) async {
    final doc = await _postsCollection.doc(postId).get();
    if (doc.exists) {
      final postData = doc.data() as Map<String, dynamic>;
      List<String> favorites = List<String>.from(postData['favorites'] ?? []);

      if (favorites.contains(userId)) {
        favorites.remove(userId);
      } else {
        favorites.add(userId);
      }

      await _postsCollection.doc(postId).update({'favorites': favorites});
    }
  }

  Future<void> addComment(
    String postId,
    String userId,
    String userName,
    String commentText,
  ) async {
    final doc = await _postsCollection.doc(postId).get();
    if (doc.exists) {
      final postData = doc.data() as Map<String, dynamic>;
      List<dynamic> commentsList = postData['comments'] ?? [];

      final newComment = {
        'userId': userId,
        'userName': userName,
        'text': commentText,
        'createdAt': DateTime.now().toIso8601String(),
      };

      commentsList.add(newComment);
      await _postsCollection.doc(postId).update({'comments': commentsList});
    }
  }

  Future<void> deleteComment(String postId, int commentIndex) async {
    final doc = await _postsCollection.doc(postId).get();
    if (doc.exists) {
      final postData = doc.data() as Map<String, dynamic>;
      List<dynamic> commentsList = postData['comments'] ?? [];

      if (commentIndex >= 0 && commentIndex < commentsList.length) {
        commentsList.removeAt(commentIndex);
        await _postsCollection.doc(postId).update({'comments': commentsList});
      }
    }
  }
}
