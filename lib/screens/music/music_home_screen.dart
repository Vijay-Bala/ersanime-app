import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/song.dart';
import '../../services/music_service.dart' as music_api;
import '../../services/music_playlist_service.dart';
import '../../services/music_player_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import 'music_player_screen.dart';
import 'music_album_screen.dart';

// Music accent color
const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key});
  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  MusicHomeData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final playlist = context.read<MusicPlaylistService>();
      final data = await music_api.getMusicHomeData(
        recentlyPlayed: playlist.recentlyPlayed,
      );
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _playSong(Song song, List<Song> queue) {
    context.read<MusicPlayerService>().playPlaylist(
      queue.isNotEmpty ? queue : [song],
      startIndex: queue.isNotEmpty ? queue.indexWhere((s) => s.id == song.id).clamp(0, queue.length - 1) : 0,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading) _buildShimmer()
          else if (_error != null) _buildError()
          else ..._buildContent(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.h,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.darkBg,
      surfaceTintColor: Colors.transparent,
      title: const ModeSwitcherTitle(),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0030), AppTheme.darkBg],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SliverToBoxAdapter(
      child: Shimmer.fromColors(
        baseColor: AppTheme.darkCard,
        highlightColor: AppTheme.darkCardElev,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            _shimmerRow(),
            SizedBox(height: 24.h),
            _shimmerRow(),
          ],
        ),
      ),
    );
  }

  Widget _shimmerRow() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 18.h, width: 140.w, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
        SizedBox(height: 12.h),
        SizedBox(
          height: 160.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (_, __) => Container(
              width: 130.w, height: 160.h,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => SliverFillRemaining(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: AppTheme.textSecondary, size: 48.sp),
          SizedBox(height: 12.h),
          Text('Could not load music', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: _musicPrimary),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  List<Widget> _buildContent() {
    final d = _data!;
    return [
      SliverToBoxAdapter(child: SizedBox(height: 8.h)),
      if (d.recentlyPlayed.isNotEmpty)
        SliverToBoxAdapter(
          child: _SongSection(
            title: 'Recently Played',
            icon: Icons.history_rounded,
            songs: d.recentlyPlayed,
            onTap: (s) => _playSong(s, d.recentlyPlayed),
          ).animate().fadeIn(delay: 50.ms),
        ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'Trending Now',
          icon: Icons.local_fire_department_rounded,
          songs: d.trending,
          onTap: (s) => _playSong(s, d.trending),
          accentColor: _musicPrimary,
        ).animate().fadeIn(delay: 100.ms),
      ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'Tamil Hits',
          icon: Icons.music_note_rounded,
          songs: d.tamilHits,
          onTap: (s) => _playSong(s, d.tamilHits),
          accentColor: const Color(0xFFFF6B35),
        ).animate().fadeIn(delay: 150.ms),
      ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'Hindi Featured',
          icon: Icons.mic_rounded,
          songs: d.hindiFeatured,
          onTap: (s) => _playSong(s, d.hindiFeatured),
          accentColor: const Color(0xFF00D4FF),
        ).animate().fadeIn(delay: 200.ms),
      ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'English Top',
          icon: Icons.language_rounded,
          songs: d.englishTop,
          onTap: (s) => _playSong(s, d.englishTop),
          accentColor: const Color(0xFF00FF88),
        ).animate().fadeIn(delay: 250.ms),
      ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'Telugu Hits',
          icon: Icons.audiotrack_rounded,
          songs: d.teluguHits,
          onTap: (s) => _playSong(s, d.teluguHits),
          accentColor: const Color(0xFFFF9100),
        ).animate().fadeIn(delay: 300.ms),
      ),
      SliverToBoxAdapter(
        child: _SongSection(
          title: 'Malayalam Hits',
          icon: Icons.library_music_rounded,
          songs: d.malayalamHits,
          onTap: (s) => _playSong(s, d.malayalamHits),
          accentColor: const Color(0xFF00E676),
        ).animate().fadeIn(delay: 350.ms),
      ),
      if (d.newReleases.isNotEmpty)
        SliverToBoxAdapter(
          child: _AlbumSection(
            title: 'New Releases',
            albums: d.newReleases,
          ).animate().fadeIn(delay: 400.ms),
        ),
    ];
  }
}

// ─── Song Section ─────────────────────────────────────────────────────────────
class _SongSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Song> songs;
  final void Function(Song) onTap;
  final Color accentColor;

  const _SongSection({
    required this.title,
    required this.icon,
    required this.songs,
    required this.onTap,
    this.accentColor = _musicPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 190.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: songs.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (_, i) => _SongCard(
                song: songs[i],
                onTap: () => onTap(songs[i]),
                accentColor: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Song Card ────────────────────────────────────────────────────────────────
class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Color accentColor;

  const _SongCard({required this.song, required this.onTap, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Art
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: song.imageUrl,
                    width: 130.w,
                    height: 130.w,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.darkCard,
                      child: Icon(Icons.music_note_rounded, color: accentColor, size: 40.sp),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.darkCard,
                      child: Icon(Icons.music_note_rounded, color: accentColor, size: 40.sp),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 8)],
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16.sp),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Album Section ────────────────────────────────────────────────────────────
class _AlbumSection extends StatelessWidget {
  final String title;
  final List<MusicAlbum> albums;

  const _AlbumSection({required this.title, required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              title,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 175.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: albums.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (_, i) {
                final album = albums[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MusicAlbumScreen(album: album)),
                  ),
                  child: SizedBox(
                    width: 130.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: album.imageUrl,
                            width: 130.w,
                            height: 130.w,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.darkCard,
                              child: Icon(Icons.album_rounded, color: _musicSecondary, size: 40.sp),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.darkCard,
                              child: Icon(Icons.album_rounded, color: _musicSecondary, size: 40.sp),
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                        Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.sp)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
