import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/post.dart';

class DetailScreen extends StatelessWidget {
  final Post post;

  const DetailScreen({super.key, required this.post});

  Widget _buildImage() {
    if (post.imageUrl.startsWith('data:image')) {
      final base64Data = post.imageUrl.split(',').last;
      return Image.memory(
        base64Decode(base64Data),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (post.imageUrl.isNotEmpty) {
      return Image.network(
        post.imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, size: 50));
        },
      );
    }

    return const Center(child: Icon(Icons.image, size: 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: _buildImage(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              post.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deskripsi:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(post.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text(
              'Koordinat:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${post.latitude}, ${post.longitude}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                Text('${post.likes.length} suka'),
                const SizedBox(width: 16),
                const Icon(Icons.bookmark, color: Colors.amber),
                const SizedBox(width: 8),
                Text('${post.favorites.length} favorit'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
