import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../services/post_services.dart';
import '../services/user_services.dart';
import 'add_post_screen.dart';
import 'detail_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostServices _postServices = PostServices();
  final UserServices _userServices = UserServices();
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _sharePost(Post post) async {
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}';
    final text =
        'Arena bowling: ${post.name}\n\n${post.description}\n\nLihat lokasi: $mapsUrl';

    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Arena Bowling: ${post.name}'),
    );
  }

  void _openMap(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(post: post)),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _openDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(post: post)),
    );
  }

  Future<String> _getCurrentUserName() async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return 'Pengguna';

    final appUser = await _userServices.getUser(authUser.uid);
    if (appUser?.displayName.trim().isNotEmpty == true) {
      return appUser!.displayName.trim();
    }
    if (authUser.displayName?.trim().isNotEmpty == true) {
      return authUser.displayName!.trim();
    }
    if (authUser.email?.trim().isNotEmpty == true) {
      return authUser.email!.trim();
    }
    return 'Pengguna';
  }

  Future<void> _openComments(Post post) async {
    final commentController = TextEditingController();
    var isSending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitComment() async {
              final text = commentController.text.trim();
              if (text.isEmpty || isSending) return;

              setModalState(() => isSending = true);
              try {
                final userName = await _getCurrentUserName();
                await _postServices.addComment(
                  post.id,
                  _currentUserId,
                  userName,
                  text,
                );
                commentController.clear();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menambah komentar: $e')),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() => isSending = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Komentar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<Post?>(
                        stream: _postServices.getPostStream(post.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final comments =
                              snapshot.data?.comments ?? post.comments;
                          if (comments.isEmpty) {
                            return const Center(
                              child: Text('Belum ada komentar.'),
                            );
                          }

                          return ListView.separated(
                            itemCount: comments.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final canDelete =
                                  comment.userId == _currentUserId ||
                                  post.adminId == _currentUserId;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(comment.text),
                                trailing: canDelete
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Hapus komentar',
                                        onPressed: () => _postServices
                                            .deleteComment(post.id, index),
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              hintText: 'Tulis komentar...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          tooltip: 'Kirim komentar',
                          onPressed: isSending ? null : submitComment,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  Widget _buildStats(Post post) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${post.likes.length} Suka',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            '${post.favorites.length} Favorit',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            '${post.comments.length} Komentar',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildPostImage(Post post) {
    if (post.imageUrl.startsWith('data:image')) {
      final base64Data = post.imageUrl.split(',').last;
      return Image.memory(
        base64Decode(base64Data),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildBrokenImage(),
      );
    }

    return Image.network(
      post.imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildBrokenImage(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildBrokenImage() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    final isAdmin = _currentUserId == post.adminId;
    final isLiked = post.likes.contains(_currentUserId);
    final isFavorited = post.favorites.contains(_currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: InkWell(
        onTap: () => _openDetail(post),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: _buildPostImage(post),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDelete(post);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStats(post),
                const Divider(),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildActionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: 'Suka',
                      color: isLiked ? Colors.red : Colors.grey,
                      onTap: () =>
                          _postServices.toggleLike(post.id, _currentUserId),
                    ),
                    _buildActionButton(
                      icon: isFavorited ? Icons.star : Icons.star_border,
                      label: 'Favorit',
                      color: isFavorited ? Colors.amber : Colors.grey,
                      onTap: () =>
                          _postServices.toggleFavorite(post.id, _currentUserId),
                    ),
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      label: 'Komentar',
                      color: Colors.grey,
                      onTap: () => _openComments(post),
                    ),
                    _buildActionButton(
                      icon: Icons.map_outlined,
                      label: 'Lihat Map',
                      color: Colors.green,
                      onTap: () => _openMap(post),
                    ),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: Colors.blue,
                      onTap: () => _sharePost(post),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _confirmDelete(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Post?'),
        content: const Text('Apakah Anda yakin ingin menghapus post ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _postServices.deletePost(post.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post berhasil dihapus')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bowling di Palembang'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Mode terang' : 'Mode gelap',
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
            onPressed: _openProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await firebase_auth.FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _postServices.getPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data arena bowling.'));
          }

          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) => _buildPostCard(posts[index]),
          );
        },
      ),
      floatingActionButton: StreamBuilder<firebase_auth.User?>(
        stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          return FutureBuilder<bool>(
            future: _userServices.isAdmin(snapshot.data!.uid),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.data != true) return const SizedBox.shrink();

              return FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddPostScreen(),
                    ),
                  );
                },
                tooltip: 'Tambah Arena Bowling',
                child: const Icon(Icons.add),
              );
            },
          );
        },
      ),
    );
  }
}
