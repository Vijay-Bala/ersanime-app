import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../screens/media/media_detail_screen.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final int index;
  const MediaCard({super.key, required this.item, this.index = 0});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
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
              pageBuilder: (_, a, _) => MediaDetailScreen(
                itemId: widget.item.id,
                isSeries: widget.item.isSeries,
                item: widget.item,
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
                    color: AppTheme.accentCyan.withOpacity(0.06),
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
                        widget.item.image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.item.image,
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
                              )
                            : Container(
                                color: AppTheme.darkCardElev,
                                child: Icon(
                                  widget.item.isSeries
                                      ? Icons.tv_rounded
                                      : Icons.movie_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 32.sp,
                                ),
                              ),
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
                        if (widget.item.rating != null)
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
                                '★ ${widget.item.rating!.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: AppTheme.accentYellow,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 5.h,
                          left: 5.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (widget.item.isSeries
                                          ? AppTheme.accentCyan
                                          : AppTheme.accentOrange)
                                      .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color:
                                    (widget.item.isSeries
                                            ? AppTheme.accentCyan
                                            : AppTheme.accentOrange)
                                        .withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              widget.item.isSeries ? 'TV' : 'MOVIE',
                              style: TextStyle(
                                color: widget.item.isSeries
                                    ? AppTheme.accentCyan
                                    : AppTheme.accentOrange,
                                fontSize: 7.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(7.w, 5.h, 7.w, 2.h),
                    child: Text(
                      widget.item.title,
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
                        if (widget.item.year != null) '${widget.item.year}',
                        if (widget.item.isSeries &&
                            widget.item.totalSeasons != null)
                          '${widget.item.totalSeasons} S',
                        _langLabel(widget.item.originalLanguage),
                      ].where((s) => s.isNotEmpty).join(' · '),
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

  String _langLabel(String? code) {
    const map = {
      'hi': '🇮🇳 Hindi',
      'ta': '🇮🇳 Tamil',
      'te': '🇮🇳 Telugu',
      'ml': '🇮🇳 Malayalam',
      'ko': '🇰🇷 Korean',
      'ja': '🇯🇵 Japanese',
      'zh': '🇨🇳 Chinese',
      'en': '🇺🇸 English',
      'fr': '🇫🇷 French',
      'es': '🇪🇸 Spanish',
    };
    return map[code] ?? '';
  }
}
