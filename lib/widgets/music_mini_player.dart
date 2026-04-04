import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/music_player_service.dart';
import '../theme/app_theme.dart';
import '../screens/music/music_player_screen.dart';

const _musicPrimary = Color(0xFFFF1493);
const _musicSecondary = Color(0xFF9B00FF);

/// Persistent mini player bar — shown at the bottom of ALL sections when music is playing.
/// Slides up when a song starts, disappears when stopped.
class MusicMiniPlayer extends StatelessWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (_, player, __) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return Dismissible(
          key: ValueKey(song.id),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => player.stopAndClear(),
          child:
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const MusicPlayerScreen(),
                    transitionsBuilder: (_, animation, __, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      );
                    },
                  ),
                ),
                child: Container(
                  height: 64.h,
                  margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A0030).withOpacity(0.95),
                        AppTheme.darkCard.withOpacity(0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _musicPrimary.withOpacity(0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _musicPrimary.withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 8.w),
                      // Album art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: song.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.imageUrl,
                                width: 46.w,
                                height: 46.w,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppTheme.darkCard,
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: _musicPrimary,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppTheme.darkCard,
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: _musicPrimary,
                                  ),
                                ),
                              )
                            : Container(
                                width: 46.w,
                                height: 46.w,
                                color: AppTheme.darkCard,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: _musicPrimary,
                                ),
                              ),
                      ),
                      SizedBox(width: 12.w),
                      // Song info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white70,
                          size: 22.sp,
                        ),
                        onPressed: player.skipPrevious,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 32.w,
                          minHeight: 32.h,
                        ),
                      ),
                      // Play/Pause
                      GestureDetector(
                        onTap: player.togglePlayPause,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_musicPrimary, _musicSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: player.isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white70,
                          size: 22.sp,
                        ),
                        onPressed: player.skipNext,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 32.w,
                          minHeight: 32.h,
                        ),
                      ),
                      // Close button
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 20.sp,
                        ),
                        onPressed: () => player.stopAndClear(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 28.w,
                          minHeight: 28.h,
                        ),
                      ),
                      SizedBox(width: 4.w),
                    ],
                  ),
                ),
              ).animate().slideY(
                begin: 1,
                end: 0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }
}
