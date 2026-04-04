import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../services/music_service.dart' as music_api;
import '../../services/music_player_service.dart';
import '../../theme/app_theme.dart';
import 'music_player_screen.dart';
import 'music_album_screen.dart';
import 'music_artist_screen.dart';

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key});
  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final TabController _tabController;

  List<Song> _songs = [];
  List<MusicAlbum> _albums = [];
  List<MusicArtist> _artists = [];
  bool _loading = false;
  String _lastQuery = '';

  // Browse genres
  static const _genres = [
    {'icon': '🎤', 'name': 'Tamil', 'color': Color(0xFFFF6B35)},
    {'icon': '🎵', 'name': 'Hindi', 'color': Color(0xFF00D4FF)},
    {'icon': '🌍', 'name': 'English', 'color': Color(0xFF00FF88)},
    {'icon': '🎶', 'name': 'Pop', 'color': Color(0xFFFF1493)},
    {'icon': '🎸', 'name': 'Rock', 'color': Color(0xFFFF6200)},
    {'icon': '🎹', 'name': 'Classical', 'color': Color(0xFFBF00FF)},
    {'icon': '🥁', 'name': 'Hip Hop', 'color': Color(0xFFFFE600)},
    {'icon': '🎺', 'name': 'Jazz', 'color': Color(0xFF00F5FF)},
    {'icon': '💃', 'name': 'Dance', 'color': Color(0xFFFF007A)},
    {'icon': '❤️', 'name': 'Romantic', 'color': Color(0xFFFF4B6E)},
    {'icon': '🕉️', 'name': 'Devotional', 'color': Color(0xFFFFD700)},
    {'icon': '🎭', 'name': 'Folk', 'color': Color(0xFF76FF03)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search(String q, {bool isGenre = false}) async {
    final queryText = q.trim();
    if (queryText.isEmpty || queryText == _lastQuery) return;
    _lastQuery = queryText;
    setState(() => _loading = true);

    if (isGenre) {
      final songs = await music_api.searchGenrePlaylistSongs(queryText);
      if (mounted) {
        setState(() {
          _songs = songs;
          _albums = [];
          _artists = [];
          _loading = false;
        });
      }
      return;
    }

    final results = await Future.wait([
      music_api.searchSongs(queryText),
      music_api.searchAlbums(queryText),
      music_api.searchArtists(queryText),
    ]);

    if (mounted) {
      setState(() {
        _songs = results[0] as List<Song>;
        _albums = results[1] as List<MusicAlbum>;
        _artists = results[2] as List<MusicArtist>;
        _loading = false;
      });
    }
  }

  void _playSong(Song song) {
    context.read<MusicPlayerService>().playPlaylist(
      _songs.isNotEmpty ? _songs : [song],
      startIndex: _songs
          .indexWhere((s) => s.id == song.id)
          .clamp(0, _songs.length - 1),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _lastQuery.isNotEmpty;
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        surfaceTintColor: Colors.transparent,
        title: _buildSearchBar(),
        bottom: hasQuery
            ? TabBar(
                controller: _tabController,
                indicatorColor: _musicPrimary,
                labelColor: _musicPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(text: 'Songs (${_songs.length})'),
                  Tab(text: 'Albums (${_albums.length})'),
                  Tab(text: 'Artists (${_artists.length})'),
                ],
              )
            : null,
      ),
      body: hasQuery ? _buildResults() : _buildBrowse(),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: false,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15.sp),
      decoration: InputDecoration(
        hintText: 'Search songs, artists, albums...',
        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
        prefixIcon: const Icon(Icons.search_rounded, color: _musicPrimary),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _songs = [];
                    _albums = [];
                    _artists = [];
                    _lastQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.darkCard,
        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _musicPrimary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.darkBorder),
        ),
      ),
      onChanged: (v) {
        setState(() {});
        if (v.trim().length >= 2) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_controller.text.trim() == v.trim()) _search(v.trim());
          });
        }
      },
      onSubmitted: (q) => _search(q),
    );
  }

  Widget _buildBrowse() {
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 2,
      ),
      itemCount: _genres.length,
      itemBuilder: (_, i) {
        final g = _genres[i];
        final color = g['color'] as Color;
        return GestureDetector(
          onTap: () {
            _controller.text = g['name'] as String;
            _search(g['name'] as String, isGenre: true);
          },
          child:
              Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.8),
                          color.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Text(
                            g['icon'] as String,
                            style: TextStyle(fontSize: 50.sp),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Text(
                            g['name'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: i * 40))
                  .scale(begin: const Offset(0.9, 0.9)),
        );
      },
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _musicPrimary),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildSongsList(), _buildAlbumsList(), _buildArtistsList()],
    );
  }

  Widget _buildSongsList() {
    if (_songs.isEmpty) {
      return _emptyState('No songs found', Icons.music_off_rounded);
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: _songs.length,
      itemBuilder: (_, i) => SongListTile(
        song: _songs[i],
        onTap: () => _playSong(_songs[i]),
      ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
    );
  }

  Widget _buildAlbumsList() {
    if (_albums.isEmpty) {
      return _emptyState('No albums found', Icons.album_rounded);
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final album = _albums[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: album.imageUrl,
              width: 50.w,
              height: 50.w,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppTheme.darkCard,
                child: const Icon(Icons.album_rounded, color: _musicSecondary),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.darkCard,
                child: const Icon(Icons.album_rounded, color: _musicSecondary),
              ),
            ),
          ),
          title: Text(
            album.name,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            album.artist,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            album.year,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.sp),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MusicAlbumScreen(album: album)),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
      },
    );
  }

  Widget _buildArtistsList() {
    if (_artists.isEmpty) {
      return _emptyState('No artists found', Icons.person_rounded);
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: _artists.length,
      itemBuilder: (_, i) {
        final artist = _artists[i];
        return ListTile(
          leading: ClipOval(
            child: CachedNetworkImage(
              imageUrl: artist.imageUrl,
              width: 50.w,
              height: 50.w,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppTheme.darkCard,
                child: Icon(
                  Icons.person_rounded,
                  color: _musicPrimary,
                  size: 28.sp,
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.darkCard,
                child: Icon(
                  Icons.person_rounded,
                  color: _musicPrimary,
                  size: 28.sp,
                ),
              ),
            ),
          ),
          title: Text(
            artist.name,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Artist',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTheme.textSecondary,
            size: 14,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MusicArtistScreen(
                artistId: artist.id,
                artistName: artist.name,
              ),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
      },
    );
  }

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48.sp, color: AppTheme.textSecondary),
        SizedBox(height: 12.h),
        Text(
          msg,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
        ),
      ],
    ),
  );
}

// ─── Reusable Song List Tile ──────────────────────────────────────────────────
class SongListTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool showMenu;

  const SongListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: song.imageUrl,
          width: 52.w,
          height: 52.w,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppTheme.darkCard,
            child: const Icon(Icons.music_note_rounded, color: _musicPrimary),
          ),
          errorWidget: (_, __, ___) => Container(
            color: AppTheme.darkCard,
            child: const Icon(Icons.music_note_rounded, color: _musicPrimary),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
            ),
          ),
          if (song.isTamil)
            Container(
              margin: EdgeInsets.only(left: 4.w),
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.4),
                ),
              ),
              child: Text(
                'TN',
                style: TextStyle(
                  color: const Color(0xFFFF6B35),
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      trailing: showMenu
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.displayDuration,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(width: 4.w),
                _SongMenu(song: song),
              ],
            )
          : Text(
              song.displayDuration,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.sp),
            ),
      onTap: onTap,
    );
  }
}

// ─── Song Context Menu ────────────────────────────────────────────────────────
class _SongMenu extends StatelessWidget {
  final Song song;
  const _SongMenu({required this.song});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: AppTheme.textSecondary,
        size: 18.sp,
      ),
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'queue',
          child: _MenuItemRow(
            icon: Icons.queue_music_rounded,
            label: 'Add to Queue',
          ),
        ),
        const PopupMenuItem(
          value: 'like',
          child: _MenuItemRow(icon: Icons.favorite_rounded, label: 'Like Song'),
        ),
        const PopupMenuItem(
          value: 'playlist',
          child: _MenuItemRow(
            icon: Icons.playlist_add_rounded,
            label: 'Add to Playlist',
          ),
        ),
      ],
      onSelected: (v) {
        switch (v) {
          case 'queue':
            context.read<MusicPlayerService>().addToQueue(song);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to queue: ${song.title}'),
                backgroundColor: AppTheme.darkCard,
                duration: const Duration(seconds: 2),
              ),
            );
            break;
          case 'like':
            // handled by MusicPlaylistService
            break;
        }
      },
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItemRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _musicPrimary, size: 18),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
    ],
  );
}
