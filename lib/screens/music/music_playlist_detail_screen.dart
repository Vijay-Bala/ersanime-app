import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../services/music_playlist_service.dart';
import '../../services/music_player_service.dart';
import '../../theme/app_theme.dart';
import 'music_player_screen.dart';
import 'music_search_screen.dart' show SongListTile;

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicPlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final MusicPlaylist? overridePlaylist; // for liked songs etc.

  const MusicPlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.overridePlaylist,
  });

  @override
  State<MusicPlaylistDetailScreen> createState() => _MusicPlaylistDetailScreenState();
}

class _MusicPlaylistDetailScreenState extends State<MusicPlaylistDetailScreen> {
  bool _reorderMode = false;

  MusicPlaylist? _getPlaylist(MusicPlaylistService service) {
    if (widget.overridePlaylist != null) return widget.overridePlaylist;
    return service.getPlaylist(widget.playlistId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlaylistService>(
      builder: (_, service, __) {
        final playlist = _getPlaylist(service);
        if (playlist == null) {
          return Scaffold(
            backgroundColor: AppTheme.darkBg,
            appBar: AppBar(backgroundColor: AppTheme.darkBg),
            body: const Center(child: Text('Playlist not found', style: TextStyle(color: AppTheme.textSecondary))),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.darkBg,
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              _buildHeader(context, playlist, service),
            ],
            body: playlist.songs.isEmpty
                ? _buildEmpty()
                : _reorderMode
                    ? _buildReorderList(playlist, service)
                    : _buildSongList(playlist, service),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MusicPlaylist playlist, MusicPlaylistService service) {
    final coverUrl = playlist.displayCoverUrl;
    return SliverAppBar(
      expandedHeight: 280.h,
      pinned: true,
      backgroundColor: AppTheme.darkBg,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (widget.overridePlaylist == null) ...[
          IconButton(
            icon: Icon(_reorderMode ? Icons.check_rounded : Icons.edit_rounded, color: _musicPrimary),
            onPressed: () => setState(() => _reorderMode = !_reorderMode),
            tooltip: _reorderMode ? 'Done' : 'Reorder',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppTheme.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.darkBorder)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: _MenuRow(icon: Icons.edit_rounded, label: 'Rename')),
              const PopupMenuItem(value: 'delete', child: _MenuRow(icon: Icons.delete_rounded, label: 'Delete Playlist')),
            ],
            onSelected: (v) async {
              if (v == 'rename') _showRename(context, service, playlist);
              if (v == 'delete') {
                await service.deletePlaylist(playlist.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background image blurred
            if (coverUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF1A0030)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A0030)),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, AppTheme.darkBg],
                ),
              ),
            ),
            // Centered info
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${playlist.songs.length} songs • ${_totalDuration(playlist.songs)}',
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _musicPrimary,
                            side: const BorderSide(color: _musicPrimary, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: playlist.songs.isEmpty ? null : () => _play(context, playlist.songs, 0),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: playlist.songs.isEmpty ? null : () {
                            final shuffled = [...playlist.songs]..shuffle();
                            _play(context, shuffled, 0);
                          },
                        ),
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

  Widget _buildSongList(MusicPlaylist playlist, MusicPlaylistService service) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: playlist.songs.length,
      itemBuilder: (_, i) {
        final song = playlist.songs[i];
        return Dismissible(
          key: Key(song.id),
          direction: widget.overridePlaylist != null ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24.w),
            color: Colors.red.withOpacity(0.2),
            child: const Icon(Icons.delete_rounded, color: Colors.red),
          ),
          onDismissed: (_) => service.removeSongFromPlaylist(playlist.id, song.id),
          child: SongListTile(
            song: song,
            onTap: () => _play(context, playlist.songs, i),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
        );
      },
    );
  }

  Widget _buildReorderList(MusicPlaylist playlist, MusicPlaylistService service) {
    return ReorderableListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: playlist.songs.length,
      onReorder: (oldIndex, newIndex) =>
          service.reorderSongs(playlist.id, oldIndex, newIndex),
      itemBuilder: (_, i) {
        final song = playlist.songs[i];
        return ListTile(
          key: Key(song.id),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(song.imageUrl, width: 48.w, height: 48.w, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48.w, height: 48.w, color: AppTheme.darkCard,
                child: const Icon(Icons.music_note_rounded, color: _musicPrimary))),
          ),
          title: Text(song.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp), maxLines: 1),
          trailing: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary, size: 20.sp),
        );
      },
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.queue_music_rounded, size: 56.sp, color: AppTheme.textSecondary),
        SizedBox(height: 16.h),
        Text('This playlist is empty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp)),
        SizedBox(height: 8.h),
        Text('Search songs and add them here', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12.sp)),
      ],
    ),
  );

  void _play(BuildContext context, List<Song> songs, int index) {
    context.read<MusicPlayerService>().playPlaylist(songs, startIndex: index);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPlayerScreen()));
  }

  void _showRename(BuildContext context, MusicPlaylistService service, MusicPlaylist playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.darkBorder)),
        title: Text('Rename Playlist', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _musicPrimary),
            onPressed: () async {
              await service.renamePlaylist(playlist.id, ctrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _totalDuration(List<Song> songs) {
    final total = songs.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _musicPrimary, size: 18),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
    ],
  );
}
