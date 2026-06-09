import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart';

class UserServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> createUser(
    String uid,
    String email, {
    String role = 'user',
  }) async {
    try {
      final user = AppUser(
        id: uid,
        email: email,
        role: role,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(uid).set(user.toMap());
    } catch (e) {
      throw Exception('Gagal membuat user: $e');
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Gagal mengambil data user: $e');
    }
  }

  Stream<AppUser?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  Future<bool> isAdmin(String uid) async {
    try {
      final user = await getUser(uid);
      return user?.role == 'admin';
    } catch (e) {
      return false;
    }
  }

  Future<void> setUserAsAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({'role': 'admin'});
    } catch (e) {
      throw Exception('Gagal mengubah role user: $e');
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    Uint8List? photoBytes,
  }) async {
    try {
      String photoUrl = '';

      if (photoBytes != null) {
        String fileName = 'profile_$uid';
        Reference ref = _storage.ref().child('profile_photos').child(fileName);
        await ref.putData(
          photoBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        photoUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('users').doc(uid).update({
        'displayName': displayName,
        if (photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      });

      if (_auth.currentUser?.uid == uid) {
        await _auth.currentUser?.updateDisplayName(displayName);
        if (photoUrl.isNotEmpty) {
          await _auth.currentUser?.updatePhotoURL(photoUrl);
        }
      }
    } catch (e) {
      throw Exception('Gagal update profil: $e');
    }
  }
}
