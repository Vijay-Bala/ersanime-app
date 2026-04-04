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
import 'music_search_screen.dart' show SongListTile;

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicAlbumScreen extends StatefulWidget {
  final MusicAlbum album;
  const MusicAlbumScreen({super.key, required this.album});

  @override
  State<MusicAlbumScreen> createState() => _MusicAlbumScreenState();
}

class _MusicAlbumScreenState extends State<MusicAlbumScreen> {
  MusicAlbum? _fullAlbum;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final full = await music_api.getAlbumDetail(widget.album.id);
    if (mounted)
      setState(() {
        _fullAlbum = full ?? widget.album;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final album = _fullAlbum ?? widget.album;
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildHeader(album)],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _musicPrimary),
              )
            : album.songs.isEmpty
            ? Center(
                child: Text(
                  'No songs',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(bottom: 100.h),
                itemCount: album.songs.length,
                itemBuilder: (_, i) => SongListTile(
                  song: album.songs[i],
                  onTap: () => _play(album.songs, i),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
              ),
      ),
    );
  }

  Widget _buildHeader(MusicAlbum album) {
    return SliverAppBar(
      expandedHeight: 260.h,
      pinned: true,
      backgroundColor: AppTheme.darkBg,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (album.imageUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: album.imageUrl, fit: BoxFit.cover),
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
                    album.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${album.artist} • ${album.year} • ${album.songs.length} songs',
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _musicPrimary,
                          side: const BorderSide(
                            color: _musicPrimary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Play',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: album.songs.isEmpty
                            ? null
                            : () => _play(album.songs, 0),
                      ),
                      SizedBox(width: 12.w),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                        onPressed: album.songs.isEmpty
                            ? null
                            : () {
                                final s = [...album.songs]..shuffle();
                                _play(s, 0);
                              },
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

  void _play(List<Song> songs, int index) {
    context.read<MusicPlayerService>().playPlaylist(songs, startIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }
}
