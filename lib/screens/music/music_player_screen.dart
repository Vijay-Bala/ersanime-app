import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/song.dart';
import '../../services/music_player_service.dart';
import '../../services/music_playlist_service.dart';
import '../../services/music_service.dart' as music_api;
import '../../theme/app_theme.dart';

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});
  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationCtrl;
  Color _bgColor1 = const Color(0xFF1A0030);
  Color _bgColor2 = AppTheme.darkBg;
  Song? _lastSongForPalette;
  SongLyrics? _lyrics;
  bool _loadingLyrics = false;
  bool _showLyrics = false;
  bool _showQueue = false;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<MusicPlayerService>();
      if (player.currentSong != null) {
        _updatePalette(player.currentSong!);
        _loadLyrics(player.currentSong!);
      }
    });
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(Song song) async {
    if (_lastSongForPalette?.id == song.id) return;
    _lastSongForPalette = song;
    if (song.imageUrl.isEmpty) return;
    try {
      final gen = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(song.imageUrl),
        maximumColorCount: 8,
      );
      if (!mounted) return;
      setState(() {
        _bgColor1 = (gen.dominantColor?.color ?? gen.vibrantColor?.color ?? const Color(0xFF1A0030)).withOpacity(0.9);
        _bgColor2 = (gen.darkMutedColor?.color ?? AppTheme.darkBg);
      });
    } catch (_) {}
  }

  Future<void> _loadLyrics(Song song) async {
    if (_lyrics != null && _lastSongForPalette?.id == song.id && _lyrics!.hasLyrics) return;
    if (song.lyricsId == null || song.lyricsId!.isEmpty) {
      setState(() => _lyrics = SongLyrics.empty());
      return;
    }
    setState(() { _loadingLyrics = true; _lyrics = null; });
    final l = await music_api.getLyrics(song);
    if (mounted) setState(() { _lyrics = l; _loadingLyrics = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (_, player, __) {
        final song = player.currentSong;

        // Update palette + lyrics when song changes
        if (song != null && song.id != _lastSongForPalette?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updatePalette(song);
            _loadLyrics(song);
          });
        }

        if (!player.isPlaying && _rotationCtrl.isAnimating) {
          _rotationCtrl.stop();
        } else if (player.isPlaying && !_rotationCtrl.isAnimating) {
          _rotationCtrl.repeat();
        }

        return Scaffold(
          body: Stack(
            children: [
              // Dynamic background
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_bgColor1, _bgColor2, AppTheme.darkBg],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              // Blur circles for depth
              Positioned(top: -80, left: -60,
                child: Container(width: 250.w, height: 250.w,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _musicPrimary.withOpacity(0.08)))),
              Positioned(bottom: 100, right: -80,
                child: Container(width: 200.w, height: 200.w,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _musicSecondary.withOpacity(0.08)))),

              // Main content
              SafeArea(
                child: song == null
                    ? _buildEmpty()
                    : _showLyrics
                        ? _buildLyricsView(song, player)
                        : _buildPlayerView(song, player),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.music_off_rounded, color: AppTheme.textSecondary, size: 64.sp),
        SizedBox(height: 16.h),
        Text('Nothing playing', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16.sp)),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go Back', style: TextStyle(color: _musicPrimary)),
        ),
      ],
    ),
  );

  Widget _buildPlayerView(Song song, MusicPlayerService player) {
    return Column(
      children: [
        // Top bar
        _buildTopBar(song),
        // Rotating album art
        Expanded(
          child: Center(
            child: _buildAlbumArt(song, player).animate().scale(
              begin: const Offset(0.85, 0.85),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
            ),
          ),
        ),
        // Song info + controls
        _buildControls(song, player),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildTopBar(Song song) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Now Playing', style: TextStyle(color: Colors.white60, fontSize: 11.sp, letterSpacing: 1.5)),
                Text(song.album, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
            onPressed: () => setState(() => _showQueue = !_showQueue),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song, MusicPlayerService player) {
    return GestureDetector(
      onTap: () => setState(() => _showLyrics = true),
      child: AnimatedBuilder(
        animation: _rotationCtrl,
        builder: (_, child) {
          return Transform.rotate(
            angle: player.isPlaying ? _rotationCtrl.value * 2 * 3.14159 : 0,
            child: child,
          );
        },
        child: Container(
          width: 260.w,
          height: 260.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _bgColor1.withOpacity(0.6), blurRadius: 40, spreadRadius: 10),
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
            ],
          ),
          child: ClipOval(
            child: song.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: song.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.darkCard,
                      child: Icon(Icons.music_note_rounded, color: _musicPrimary, size: 80.sp)),
                    errorWidget: (_, __, ___) => Container(color: AppTheme.darkCard,
                      child: Icon(Icons.music_note_rounded, color: _musicPrimary, size: 80.sp)),
                  )
                : Container(color: AppTheme.darkCard,
                    child: Icon(Icons.music_note_rounded, color: _musicPrimary, size: 80.sp)),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(Song song, MusicPlayerService player) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          // Song title + artist + like
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                          ),
                        ),
                        if (song.isTamil)
                          Container(
                            margin: EdgeInsets.only(left: 8.w),
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5)),
                            ),
                            child: Text('तமிழ்', style: TextStyle(color: const Color(0xFFFF6B35), fontSize: 10.sp, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Consumer<MusicPlaylistService>(
                builder: (_, service, __) {
                  final liked = service.isLiked(song.id);
                  return IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(liked),
                        color: liked ? _musicPrimary : Colors.white70,
                        size: 24.sp,
                      ),
                    ),
                    onPressed: () => service.toggleLike(song),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 20.h),
          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              thumbColor: Colors.white,
              activeTrackColor: _musicPrimary,
              inactiveTrackColor: Colors.white24,
              overlayColor: _musicPrimary.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
            ),
            child: Slider(
              value: player.progress,
              onChanged: (v) => player.seekToFraction(v),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(player.position), style: TextStyle(color: Colors.white60, fontSize: 11.sp)),
                Text(_formatDuration(player.duration), style: TextStyle(color: Colors.white60, fontSize: 11.sp)),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              IconButton(
                icon: Icon(Icons.shuffle_rounded,
                  color: player.isShuffled ? _musicPrimary : Colors.white70, size: 22.sp),
                onPressed: player.toggleShuffle,
              ),
              // Previous
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32.sp),
                onPressed: player.skipPrevious,
              ),
              // Play/Pause
              GestureDetector(
                onTap: player.togglePlayPause,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_musicPrimary, _musicSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _musicPrimary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: player.isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36.sp,
                        ),
                ),
              ),
              // Next
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 32.sp),
                onPressed: player.skipNext,
              ),
              // Repeat
              IconButton(
                icon: Icon(
                  player.repeatMode == PlayerRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: player.repeatMode != PlayerRepeatMode.none ? _musicPrimary : Colors.white70,
                  size: 22.sp,
                ),
                onPressed: player.toggleRepeat,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Bottom row: Lyrics button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showLyrics = true),
                icon: Icon(Icons.lyrics_rounded, size: 16.sp, color: Colors.white60),
                label: Text('Lyrics', style: TextStyle(color: Colors.white60, fontSize: 13.sp)),
              ),
            ],
          ),
          // Error banner
          if (player.error != null)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(player.error!, style: TextStyle(color: Colors.redAccent, fontSize: 11.sp))),
                  TextButton(onPressed: player.retry, child: const Text('Retry', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Lyrics View ────────────────────────────────────────────────────────────
  Widget _buildLyricsView(Song song, MusicPlayerService player) {
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                onPressed: () => setState(() => _showLyrics = false),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Lyrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.sp)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          song.isTamil ? Icons.translate_rounded : Icons.language_rounded,
                          size: 12.sp,
                          color: song.isTamil ? const Color(0xFFFF6B35) : Colors.white60,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          song.isTamil ? 'Tamil / Thanglish' : 'English',
                          style: TextStyle(
                            color: song.isTamil ? const Color(0xFFFF6B35) : Colors.white60,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.album_rounded, color: Colors.white60),
                onPressed: () => setState(() => _showLyrics = false),
              ),
            ],
          ),
        ),
        // Small album art
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: song.imageUrl,
            width: 80.w,
            height: 80.w,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppTheme.darkCard, child: const Icon(Icons.music_note_rounded, color: _musicPrimary)),
            errorWidget: (_, __, ___) => Container(color: AppTheme.darkCard, child: const Icon(Icons.music_note_rounded, color: _musicPrimary)),
          ),
        ),
        SizedBox(height: 8.h),
        Text(song.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(song.artist, style: TextStyle(color: Colors.white60, fontSize: 12.sp)),
        SizedBox(height: 16.h),
        // Lyrics body
        Expanded(
          child: _loadingLyrics
              ? const Center(child: CircularProgressIndicator(color: _musicPrimary))
              : (_lyrics == null || !_lyrics!.hasLyrics)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lyrics_rounded, color: AppTheme.textSecondary, size: 40.sp),
                          SizedBox(height: 12.h),
                          Text(
                            song.isTamil
                                ? 'Lyrics not available for this Tamil song'
                                : 'Lyrics not available for this song',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                      child: Text(
                        _lyrics!.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16.sp,
                          height: 2.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
        ),
        // Mini playback controls at bottom of lyrics view
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28.sp),
                onPressed: player.skipPrevious,
              ),
              GestureDetector(
                onTap: player.togglePlayPause,
                child: Container(
                  width: 52.w, height: 52.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_musicPrimary, _musicSecondary]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 28.sp,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 28.sp),
                onPressed: player.skipNext,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
