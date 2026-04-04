import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../services/music_playlist_service.dart';
import '../../services/music_player_service.dart';
import '../../services/playlist_import_service.dart' as importer;
import '../../theme/app_theme.dart';
import 'music_player_screen.dart';
import 'music_playlist_detail_screen.dart';
import 'music_search_screen.dart' show SongListTile;

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({super.key});
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final playlistService = context.watch<MusicPlaylistService>();
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        surfaceTintColor: Colors.transparent,
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_musicPrimary, _musicSecondary],
          ).createShader(b),
          child: Text(
            'My Library',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _musicPrimary),
            onPressed: _showCreatePlaylist,
            tooltip: 'New Playlist',
          ),
          IconButton(
            icon: const Icon(
              Icons.file_download_outlined,
              color: _musicPrimary,
            ),
            onPressed: _showImportDialog,
            tooltip: 'Import Playlist',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Liked Songs
          SliverToBoxAdapter(
            child: _buildLikedSongsCard(playlistService).animate().fadeIn(),
          ),
          // Recently Played
          if (playlistService.recentlyPlayed.isNotEmpty)
            SliverToBoxAdapter(child: _buildRecentlyPlayed(playlistService)),
          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: _musicPrimary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Your Playlists',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${playlistService.playlists.length} playlists',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Playlists
          if (playlistService.playlists.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyPlaylists())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final pl = playlistService.playlists[i];
                return _PlaylistTile(
                  playlist: pl,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MusicPlaylistDetailScreen(playlistId: pl.id),
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 40));
              }, childCount: playlistService.playlists.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildLikedSongsCard(MusicPlaylistService service) {
    final count = service.likedSongs.length;
    return GestureDetector(
      onTap: () {
        if (count == 0) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MusicPlaylistDetailScreen(
              playlistId: '__liked__',
              overridePlaylist: MusicPlaylist(
                id: '__liked__',
                name: 'Liked Songs',
                songs: service.likedSongs.toList(),
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _musicPrimary.withOpacity(0.3),
              _musicSecondary.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _musicPrimary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_musicPrimary, _musicSecondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked Songs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    '$count songs',
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: _musicPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayed(MusicPlaylistService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: _musicSecondary, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Recently Played',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: service.recentlyPlayed.length.clamp(0, 10),
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (_, i) {
              final song = service.recentlyPlayed[i];
              return GestureDetector(
                onTap: () {
                  context.read<MusicPlayerService>().playSong(song);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MusicPlayerScreen(),
                    ),
                  );
                },
                child: SizedBox(
                  width: 60.w,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.imageUrl,
                          width: 56.w,
                          height: 56.w,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56.w,
                            height: 56.w,
                            color: AppTheme.darkCard,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: _musicPrimary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 9.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaylists() {
    return Padding(
      padding: EdgeInsets.all(40.w),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 56.sp,
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: 16.h),
          Text(
            'No playlists yet',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Create one or import from\nSpotify / YouTube Music',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showCreatePlaylist,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _musicPrimary,
                  side: const BorderSide(color: _musicPrimary),
                ),
              ),
              SizedBox(width: 12.w),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _musicPrimary,
                  side: const BorderSide(color: _musicPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  void _showCreatePlaylist() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkBorder),
        ),
        title: Text(
          'New Playlist',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _musicPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _musicPrimary,
              side: const BorderSide(color: _musicPrimary),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await context.read<MusicPlaylistService>().createPlaylist(name);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          bool importing = false;
          String? progress;
          String? result;

          return AlertDialog(
            backgroundColor: AppTheme.darkCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.darkBorder),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  color: _musicPrimary,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Import Playlist',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste a public Spotify or YouTube Music playlist link:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: urlCtrl,
                  enabled: !importing,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.sp,
                  ),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText:
                        'https://open.spotify.com/playlist/...\nor https://music.youtube.com/playlist?list=...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.sp,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _musicPrimary),
                    ),
                  ),
                ),
                if (progress != null) ...[
                  SizedBox(height: 12.h),
                  LinearProgressIndicator(
                    color: _musicPrimary,
                    backgroundColor: AppTheme.darkBorder,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    progress!,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.sp,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (result != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    result!,
                    style: TextStyle(color: _musicPrimary, fontSize: 12.sp),
                  ),
                ],
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13.sp,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        'Tip: Make playlist Public, import, then set back to Private.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: importing ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: importing
                        ? AppTheme.darkBorder
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _musicPrimary,
                  side: const BorderSide(color: _musicPrimary),
                ),
                onPressed: importing
                    ? null
                    : () async {
                        final url = urlCtrl.text.trim();
                        if (url.isEmpty) return;
                        setDialogState(() {
                          importing = true;
                          progress = 'Starting import...';
                          result = null;
                        });

                        final res = await importer.importPlaylist(
                          url,
                          onProgress: (cur, total, title) {
                            setDialogState(
                              () => progress = '[$cur/$total] $title',
                            );
                          },
                        );

                        if (!mounted) return;
                        if (res.success) {
                          await context
                              .read<MusicPlaylistService>()
                              .importPlaylist(res.playlist);
                          setDialogState(() {
                            importing = false;
                            progress = null;
                            result =
                                '✅ Imported ${res.matched} of ${res.total} songs into "${res.playlist.name}"' +
                                (res.notFound > 0
                                    ? '\n(${res.notFound} songs not found on JioSaavn)'
                                    : '');
                          });
                        } else {
                          setDialogState(() {
                            importing = false;
                            progress = null;
                            result = '❌ ${res.error}';
                          });
                        }
                      },
                child: importing
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _musicPrimary,
                        ),
                      )
                    : const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Playlist Tile ─────────────────────────────────────────────────────────────
class _PlaylistTile extends StatelessWidget {
  final MusicPlaylist playlist;
  final VoidCallback onTap;

  const _PlaylistTile({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final coverUrl = playlist.displayCoverUrl;
    final sourceIcon = playlist.source == PlaylistSource.spotify
        ? '🎵'
        : playlist.source == PlaylistSource.youtube
        ? '▶️'
        : '🎧';

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: coverUrl.isNotEmpty
            ? Image.network(
                coverUrl,
                width: 56.w,
                height: 56.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultCover(),
              )
            : _defaultCover(),
      ),
      title: Text(
        playlist.name,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$sourceIcon ${playlist.songs.length} songs',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
      ),
      trailing: PopupMenuButton<String>(
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
            value: 'play',
            child: _Row(icon: Icons.play_arrow_rounded, label: 'Play All'),
          ),
          const PopupMenuItem(
            value: 'shuffle',
            child: _Row(icon: Icons.shuffle_rounded, label: 'Shuffle'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: _Row(icon: Icons.delete_rounded, label: 'Delete'),
          ),
        ],
        onSelected: (v) async {
          switch (v) {
            case 'play':
              if (playlist.songs.isNotEmpty) {
                context.read<MusicPlayerService>().playPlaylist(playlist.songs);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                );
              }
              break;
            case 'shuffle':
              if (playlist.songs.isNotEmpty) {
                final shuffled = [...playlist.songs]..shuffle();
                context.read<MusicPlayerService>().playPlaylist(shuffled);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                );
              }
              break;
            case 'delete':
              await context.read<MusicPlaylistService>().deletePlaylist(
                playlist.id,
              );
              break;
          }
        },
      ),
      onTap: onTap,
    );
  }

  Widget _defaultCover() => Container(
    width: 56,
    height: 56,
    color: AppTheme.darkCard,
    child: const Icon(Icons.queue_music_rounded, color: _musicSecondary),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _musicPrimary, size: 18),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
    ],
  );
}
