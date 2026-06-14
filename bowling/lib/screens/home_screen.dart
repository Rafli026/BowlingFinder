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
  bool _showFavoritesOnly = false;

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
        _StatPill(
          icon: Icons.favorite,
          label: '${post.likes.length}',
          color: const Color(0xFFE53935),
        ),
        const SizedBox(width: 8),
        _StatPill(
          icon: Icons.star,
          label: '${post.favorites.length}',
          color: const Color(0xFFFFB300),
        ),
        const SizedBox(width: 8),
        _StatPill(
          icon: Icons.chat_bubble_outline,
          label: '${post.comments.length}',
          color: const Color(0xFF1E88E5),
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
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildPostImage(Post post) {
    if (post.imageUrl.trim().isEmpty) {
      return const _BowlingImagePlaceholder();
    }

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
      errorBuilder: (context, error, stackTrace) =>
          const _BowlingImagePlaceholder(),
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
    return const _BowlingImagePlaceholder();
  }

  Widget _buildPostCard(Post post) {
    final isAdmin = _currentUserId == post.adminId;
    final isLiked = post.likes.contains(_currentUserId);
    final isFavorited = post.favorites.contains(_currentUserId);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: () => _openDetail(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildPostImage(post),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_score, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Arena Bowling',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isAdmin)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDelete(post);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Palembang',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildStats(post),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildActionButton(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        label: 'Suka',
                        color: isLiked ? Colors.red : null,
                        onTap: () =>
                            _postServices.toggleLike(post.id, _currentUserId),
                      ),
                      _buildActionButton(
                        icon: isFavorited ? Icons.star : Icons.star_border,
                        label: 'Favorit',
                        color: isFavorited ? Colors.amber : null,
                        onTap: () => _postServices.toggleFavorite(
                          post.id,
                          _currentUserId,
                        ),
                      ),
                      _buildActionButton(
                        icon: Icons.comment_outlined,
                        label: 'Komentar',
                        onTap: () => _openComments(post),
                      ),
                      _buildActionButton(
                        icon: Icons.map_outlined,
                        label: 'Map',
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

  Widget _buildHomeHeader(List<Post> posts) {
    final theme = Theme.of(context);
    final totalLikes = posts.fold<int>(
      0,
      (sum, post) => sum + post.likes.length,
    );
    final favoriteCount = posts
        .where((post) => post.favorites.contains(_currentUserId))
        .length;
    final totalComments = posts.fold<int>(
      0,
      (sum, post) => sum + post.comments.length,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFFFF9800)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -28,
            child: Icon(
              Icons.sports_score,
              size: 150,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bowling Finder Palembang',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Temukan arena bowling, lihat lokasi, dan simpan tempat favorit.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeaderMetric(
                    icon: Icons.place_outlined,
                    label: 'Venue',
                    value: '${posts.length}',
                  ),
                  _HeaderMetric(
                    icon: Icons.favorite_border,
                    label: 'Suka',
                    value: '$totalLikes',
                  ),
                  _HeaderMetric(
                    icon: Icons.star_border,
                    label: 'Favorit Saya',
                    value: '$favoriteCount',
                  ),
                  _HeaderMetric(
                    icon: Icons.chat_bubble_outline,
                    label: 'Komentar',
                    value: '$totalComments',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher(int favoriteCount) {
    final theme = Theme.of(context);

    return SegmentedButton<bool>(
      segments: [
        ButtonSegment<bool>(
          value: false,
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Semua'),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: const Icon(Icons.star_rounded),
          label: Text('Favorit ($favoriteCount)'),
        ),
      ],
      selected: {_showFavoritesOnly},
      onSelectionChanged: (selection) {
        setState(() => _showFavoritesOnly = selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(
          BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildPostsContent(List<Post> posts) {
    final favoritePosts = posts
        .where((post) => post.favorites.contains(_currentUserId))
        .toList();
    final visiblePosts = _showFavoritesOnly ? favoritePosts : posts;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 3
            : width >= 720
            ? 2
            : 1;

        final contentSliver = crossAxisCount == 1
            ? SliverList.separated(
                itemCount: visiblePosts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    _buildPostCard(visiblePosts[index]),
              )
            : SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPostCard(visiblePosts[index]),
                  childCount: visiblePosts.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
              );

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(child: _buildHomeHeader(posts)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildViewSwitcher(favoritePosts.length),
                ),
              ),
            ),
            if (visiblePosts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildStateMessage(
                  icon: Icons.star_border_rounded,
                  title: 'Belum ada favorit',
                  message:
                      'Tekan tombol Favorit di venue yang ingin Anda simpan.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: contentSliver,
              ),
          ],
        );
      },
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
            icon: Icon(
              _showFavoritesOnly ? Icons.star : Icons.star_border,
              color: _showFavoritesOnly ? Colors.amber : null,
            ),
            tooltip: _showFavoritesOnly ? 'Tampilkan semua' : 'Favorit saya',
            onPressed: () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
            },
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
            return _buildStateMessage(
              icon: Icons.error_outline,
              title: 'Data belum bisa dimuat',
              message: 'Terjadi kesalahan: ${snapshot.error}',
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildStateMessage(
              icon: Icons.sports_score,
              title: 'Belum ada arena bowling',
              message:
                  'Data venue akan tampil di sini setelah admin menambahkannya.',
            );
          }

          final posts = snapshot.data!;
          return _buildPostsContent(posts);
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

class _BowlingImagePlaceholder extends StatelessWidget {
  const _BowlingImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: CustomPaint(
        painter: _BowlingImagePainter(),
        child: const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_score, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Bowling Venue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BowlingImagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF17324D), Color(0xFF246B8F), Color(0xFFFF9800)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final lanePaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final lanePath = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..lineTo(size.width * 0.44, size.height * 0.2)
      ..lineTo(size.width * 0.57, size.height * 0.2)
      ..lineTo(size.width * 0.86, size.height)
      ..close();
    canvas.drawPath(lanePath, lanePaint);

    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2;
    for (final x in [0.36, 0.5, 0.64]) {
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.22),
        Offset(size.width * x, size.height),
        stripePaint,
      );
    }

    final pinPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final pinShadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
    final accentPaint = Paint()..color = const Color(0xFFE53935);
    final pinCenters = [
      Offset(size.width * 0.72, size.height * 0.35),
      Offset(size.width * 0.67, size.height * 0.48),
      Offset(size.width * 0.77, size.height * 0.48),
      Offset(size.width * 0.62, size.height * 0.61),
      Offset(size.width * 0.72, size.height * 0.61),
      Offset(size.width * 0.82, size.height * 0.61),
    ];

    for (final center in pinCenters) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * 0.055,
        height: size.height * 0.22,
      );
      final body = RRect.fromRectAndRadius(rect, const Radius.circular(18));
      canvas.drawRRect(body.shift(const Offset(0, 5)), pinShadow);
      canvas.drawRRect(body, pinPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - rect.height * 0.16),
            width: rect.width * 0.82,
            height: rect.height * 0.14,
          ),
          const Radius.circular(8),
        ),
        accentPaint,
      );
    }

    final ballCenter = Offset(size.width * 0.28, size.height * 0.58);
    final ballRadius = size.shortestSide * 0.24;
    final ballPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.5),
        radius: 0.9,
        colors: [Color(0xFF7C4DFF), Color(0xFF241335)],
      ).createShader(Rect.fromCircle(center: ballCenter, radius: ballRadius));
    canvas.drawCircle(ballCenter, ballRadius, ballPaint);

    final holePaint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    canvas.drawCircle(
      ballCenter + Offset(ballRadius * 0.2, -ballRadius * 0.25),
      ballRadius * 0.12,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter + Offset(ballRadius * 0.42, ballRadius * 0.02),
      ballRadius * 0.1,
      holePaint,
    );
    canvas.drawCircle(
      ballCenter + Offset(ballRadius * 0.02, ballRadius * 0.1),
      ballRadius * 0.1,
      holePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
