import 'package:bowling/models/post.dart';
import 'package:flutter/material.dart';
import '../models/bowling_venue.dart';

class DetailScreen extends StatelessWidget {
  final BowlingVenue venue;

  const DetailScreen({super.key, required this.venue, required Post post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(venue.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, size: 50)),
            ),
            const SizedBox(height: 16),
            Text(
              venue.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                Text(
                  ' ${venue.rating} / 5.0',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Alamat:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(venue.address, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
