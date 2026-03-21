import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/anime.dart';
import '../theme/app_theme.dart';
import '../screens/anime_detail_screen.dart';

class AnimeCard extends StatefulWidget {
  final Anime anime;
  final int index;
  const AnimeCard({super.key, required this.anime, this.index = 0});

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, _) => AnimeDetailScreen(
                animeId: widget.anime.id,
                anime: widget.anime,
              ),
              transitionsBuilder: (_, a, _, child) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
            ),
          ),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.darkBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.anime.image,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppTheme.darkCardElev),
                          errorWidget: (_, _, _) => Container(
                            color: AppTheme.darkCardElev,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.textSecondary,
                              size: 24.sp,
                            ),
                          ),
                        ),
                        // Bottom gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 60.h,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [AppTheme.darkCard, Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        // Rating
                        if (widget.anime.rating != null)
                          Positioned(
                            top: 5.h,
                            right: 5.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: AppTheme.accentYellow.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                '★ ${widget.anime.rating!.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: AppTheme.accentYellow,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        // Ongoing badge
                        if (widget.anime.status == 'Ongoing')
                          Positioned(
                            top: 5.h,
                            left: 5.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: AppTheme.accentGreen.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                        width: 4.w,
                                        height: 4.h,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGreen,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.accentGreen,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .fadeOut(duration: 800.ms)
                                      .then()
                                      .fadeIn(duration: 800.ms),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: AppTheme.accentGreen,
                                      fontSize: 7.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(7.w, 5.h, 7.w, 2.h),
                    child: Text(
                      widget.anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(7.w, 0, 7.w, 7.h),
                    child: Text(
                      [
                        if (widget.anime.format != null) widget.anime.format!,
                        if (widget.anime.episodes != null)
                          '${widget.anime.episodes} EP',
                      ].join(' · '),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: (widget.index * 40).ms)
        .fadeIn(curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
  }
}
