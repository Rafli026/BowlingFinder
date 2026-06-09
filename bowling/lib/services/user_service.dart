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
