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
  double _playbackSpeed = 1.0;
  final ScrollController _lyricsScrollCtrl = ScrollController();

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
    _lyricsScrollCtrl.dispose();
    super.dispose();
  }

  void _seekRelative(Duration delta, MusicPlayerService player) {
    final target = player.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > player.duration ? player.duration : target);
    player.seekTo(clamped);
  }

  void _cycleSpeed(MusicPlayerService player) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIdx = speeds.indexWhere((s) => (s - _playbackSpeed).abs() < 0.01);
    final nextIdx = (currentIdx + 1) % speeds.length;
    setState(() => _playbackSpeed = speeds[nextIdx]);
    player.setSpeed(_playbackSpeed);
  }

  String _speedLabel() {
    if ((_playbackSpeed - 1.0).abs() < 0.01) return '1×';
    if (_playbackSpeed == _playbackSpeed.truncateToDouble())
      return '${_playbackSpeed.toInt()}×';
    return '${_playbackSpeed}×';
  }

  // ─── Language helper methods ───────────────────────────────────────────────

  bool _isOtherLanguageSong(Song song) {
    final lang = song.language.toLowerCase();
    return lang.isNotEmpty && lang != 'tamil' && lang != 'english';
  }

  IconData _lyricsIconForSong(Song song) {
    if (song.isTamil) return Icons.translate_rounded;
    if (_isOtherLanguageSong(song)) return Icons.record_voice_over_rounded;
    return Icons.language_rounded;
  }

  Color _lyricsColorForSong(Song song) {
    if (song.isTamil) return const Color(0xFFFF6B35);
    if (_isOtherLanguageSong(song)) return const Color(0xFFBB80FF);
    return Colors.white60;
  }

  String _lyricsLabelForSong(Song song) {
    if (song.isTamil) return 'Tamil / Thanglish';
    final lang = song.language.toLowerCase();
    if (lang.isEmpty) return 'Unknown Language';
    return _fullLangName(song.language);
  }

  String _fullLangName(String lang) {
    switch (lang.toLowerCase()) {
      case 'hindi':     return 'Hindi (हिन्दी)';
      case 'telugu':    return 'Telugu (తెలుగు)';
      case 'malayalam': return 'Malayalam (മലയാളം)';
      case 'kannada':   return 'Kannada (ಕನ್ನಡ)';
      case 'punjabi':   return 'Punjabi (ਪੰਜਾਬੀ)';
      case 'bengali':   return 'Bengali (বাংলা)';
      case 'marathi':   return 'Marathi (मराठी)';
      case 'gujarati':  return 'Gujarati (ગુજરાતી)';
      case 'odia':      return 'Odia (ଓଡ଼ିଆ)';
      case 'bhojpuri':  return 'Bhojpuri';
      case 'urdu':      return 'Urdu (اردو)';
      case 'english':   return 'English';
      case 'tamil':     return 'Tamil / Thanglish';
      default:          return lang[0].toUpperCase() + lang.substring(1);
    }
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

        // Automatic lyric scrolling
        if (_showLyrics && _lyrics != null && _lyrics!.lines.isNotEmpty) {
          final idx = _lyrics!.lines.lastIndexWhere((l) => l.time <= player.position);
          if (idx != -1 && _lyricsScrollCtrl.hasClients) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (_lyricsScrollCtrl.hasClients) {
                 final offset = (idx * 45.0) - (MediaQuery.of(context).size.height * 0.25);
                 final target = offset.clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent);
                 if ((_lyricsScrollCtrl.offset - target).abs() > 5.0) {
                   _lyricsScrollCtrl.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                 }
               }
             });
          }
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
          SizedBox(height: 12.h),
          // +10/-10 seek row + speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // -10 sec
              _seekChip(Icons.replay_10_rounded, '-10s', () => _seekRelative(const Duration(seconds: -10), player)),
              // Speed button
              GestureDetector(
                onTap: () => _cycleSpeed(player),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _speedLabel(),
                    style: TextStyle(
                      color: (_playbackSpeed - 1.0).abs() > 0.01 ? _musicPrimary : Colors.white60,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // +10 sec
              _seekChip(Icons.forward_10_rounded, '+10s', () => _seekRelative(const Duration(seconds: 10), player)),
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
                          _lyricsIconForSong(song),
                          size: 12.sp,
                          color: _lyricsColorForSong(song),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _lyricsLabelForSong(song),
                          style: TextStyle(
                            color: _lyricsColorForSong(song),
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
        SizedBox(height: 8.h),
        // Language note banner for non-Tamil/English songs
        if (_isOtherLanguageSong(song))
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF9B00FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFF9B00FF).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: const Color(0xFFBB80FF), size: 14.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Lyrics shown in ${_fullLangName(song.language)} script. '  
                    'English/Thanglish versions may not be available.',
                    style: TextStyle(color: const Color(0xFFBB80FF), fontSize: 11.sp, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 8.h),
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
                            'Lyrics not available for this song',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
                          ),
                          if (_isOtherLanguageSong(song)) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'Try searching on LyricsMint or Raaga for ${_fullLangName(song.language)} lyrics',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 11.sp),
                            ),
                          ],
                        ],
                      ),
                    )
                      : _lyrics!.lines.isNotEmpty 
                      ? ListView.builder(
                          controller: _lyricsScrollCtrl,
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: MediaQuery.of(context).size.height * 0.3),
                          itemCount: _lyrics!.lines.length,
                          itemBuilder: (context, index) {
                            final line = _lyrics!.lines[index];
                            final isActive = _lyrics!.lines.lastIndexWhere((l) => l.time <= player.position) == index;
                            
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: isActive ? 6.h : 2.h),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.white38,
                                  fontSize: isActive ? 18.sp : 14.sp,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                  letterSpacing: isActive ? 0.5 : 0.0,
                                  height: 1.4,
                                ),
                                child: Text(
                                  line.text,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            );
                          },
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
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
          child: Column(
            children: [
              // Seek ±10 + speed row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _seekChip(Icons.replay_10_rounded, '-10s', () => _seekRelative(const Duration(seconds: -10), player)),
                  GestureDetector(
                    onTap: () => _cycleSpeed(player),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        _speedLabel(),
                        style: TextStyle(
                          color: (_playbackSpeed - 1.0).abs() > 0.01 ? _musicPrimary : Colors.white60,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _seekChip(Icons.forward_10_rounded, '+10s', () => _seekRelative(const Duration(seconds: 10), player)),
                ],
              ),
              SizedBox(height: 8.h),
              // Main playback row
              Row(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _seekChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18.sp),
            SizedBox(width: 4.w),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
