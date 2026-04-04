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
import 'music_search_screen.dart' show SongListTile;

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicArtistScreen extends StatefulWidget {
  final String artistId;
  final String artistName;
  const MusicArtistScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  State<MusicArtistScreen> createState() => _MusicArtistScreenState();
}

class _MusicArtistScreenState extends State<MusicArtistScreen> {
  MusicArtist? _artist;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final artist = await music_api.getArtistDetail(widget.artistId);
      if (mounted)
        setState(() {
          _artist = artist;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _musicPrimary))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load artist',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _musicPrimary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final artist = _artist!;
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [_buildHeader(artist)],
      body: CustomScrollView(
        slivers: [
          if (artist.topSongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 8.h),
                child: Text(
                  'Top Songs',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SongListTile(
                  song: artist.topSongs[i],
                  onTap: () {
                    context.read<MusicPlayerService>().playPlaylist(
                      artist.topSongs,
                      startIndex: i,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MusicPlayerScreen(),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
                childCount: artist.topSongs.length,
              ),
            ),
          ],
          if (artist.albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
                child: Text(
                  'Albums',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 175.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: artist.albums.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12.w),
                  itemBuilder: (_, i) {
                    final album = artist.albums[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MusicAlbumScreen(album: album),
                        ),
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
                                  child: const Icon(
                                    Icons.album_rounded,
                                    color: _musicSecondary,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppTheme.darkCard,
                                  child: const Icon(
                                    Icons.album_rounded,
                                    color: _musicSecondary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              album.year,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 50));
                  },
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(MusicArtist artist) {
    return SliverAppBar(
      expandedHeight: 240.h,
      pinned: true,
      backgroundColor: AppTheme.darkBg,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (artist.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: artist.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF1A0030)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A0030),
                  child: Icon(
                    Icons.person_rounded,
                    color: _musicPrimary,
                    size: 80.sp,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.darkBg],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (artist.topSongs.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _musicPrimary,
                        side: const BorderSide(color: _musicPrimary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text(
                        'Shuffle Play',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        final shuffled = [...artist.topSongs]..shuffle();
                        context.read<MusicPlayerService>().playPlaylist(
                          shuffled,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MusicPlayerScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
