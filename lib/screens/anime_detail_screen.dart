import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/anime.dart';
import '../services/anilist_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/skeleton.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;
  final Anime? anime;
  const AnimeDetailScreen({super.key, required this.animeId, this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  Anime? _anime;
  List<Episode> _episodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;
    _load();
  }

  Future<void> _load() async {
    try {
      final anime = await getAnimeDetail(widget.animeId);
      final episodes = await getEpisodes(anime);
      if (mounted) {
        setState(() {
          _anime = anime;
          _episodes = episodes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play(Episode ep) {
    if (_anime == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) =>
            PlayerScreen(anime: _anime!, episode: ep, allEpisodes: _episodes),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final anime = _anime;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _loading && anime == null
          ? const CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: AppTheme.darkBg,
                  flexibleSpace: FlexibleSpaceBar(),
                ),
                SliverToBoxAdapter(child: AnimeDetailSkeleton()),
              ],
            )
          : CustomScrollView(
              slivers: [
                // ── Banner ────────────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 240.h,
                  pinned: true,
                  backgroundColor: AppTheme.darkBg,
                  flexibleSpace: FlexibleSpaceBar(
                    background: anime?.cover != null || anime?.image != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.black54,
                                  BlendMode.darken,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: anime!.cover ?? anime.image,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      AppTheme.darkBg,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  actions: [
                    // Status picker button
                    if (anime != null) _StatusPickerButton(animeId: anime.id),
                    SizedBox(width: 4.w),
                  ],
                ),

                if (anime != null)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Poster + Info ───────────────────────────────────
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Poster
                              Container(
                                width: 110.w,
                                height: 160.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.25),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: CachedNetworkImage(
                                  imageUrl: anime.image,
                                  fit: BoxFit.cover,
                                ),
                              ).animate().fadeIn().slideY(begin: 0.1),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                          anime.title,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 17.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          overflow: TextOverflow.visible,
                                        )
                                        .animate()
                                        .fadeIn(delay: 80.ms)
                                        .slideX(begin: 0.05),
                                    SizedBox(height: 8.h),
                                    Wrap(
                                      spacing: 5.w,
                                      runSpacing: 5.h,
                                      children: [
                                        if (anime.rating != null)
                                          _Badge(
                                            '★ ${anime.rating!.toStringAsFixed(1)}',
                                            AppTheme.accentYellow,
                                          ),
                                        if (anime.format != null)
                                          _Badge(
                                            anime.format!,
                                            AppTheme.primary,
                                          ),
                                        if (anime.episodes != null)
                                          _Badge(
                                            '${anime.episodes} EP',
                                            AppTheme.accentCyan,
                                          ),
                                        if (anime.status != null)
                                          _Badge(
                                            anime.status!,
                                            anime.status == 'Ongoing'
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentCyan,
                                          ),
                                        if (anime.year != null)
                                          _Badge(
                                            '${anime.year}',
                                            AppTheme.textSecondary,
                                          ),
                                      ],
                                    ).animate().fadeIn(delay: 120.ms),
                                    // Current list status
                                    if (watchlist.getStatus(anime.id) !=
                                        null) ...[
                                      SizedBox(height: 8.h),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 3.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: watchlist
                                              .getStatus(anime.id)!
                                              .color
                                              .withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            6.r,
                                          ),
                                          border: Border.all(
                                            color: watchlist
                                                .getStatus(anime.id)!
                                                .color
                                                .withOpacity(0.4),
                                          ),
                                        ),
                                        child: Text(
                                          '${watchlist.getStatus(anime.id)!.emoji} ${watchlist.getStatus(anime.id)!.label}',
                                          style: TextStyle(
                                            color: watchlist
                                                .getStatus(anime.id)!
                                                .color,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ).animate().fadeIn(delay: 140.ms),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // ── Play button ─────────────────────────────────────
                        if (_episodes.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final last = watchlist.lastWatchedEpisode(
                                    anime.id,
                                  );
                                  final ep = last > 0 && last < _episodes.length
                                      ? _episodes[last]
                                      : _episodes.first;
                                  _play(ep);
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                                label: Text(
                                  watchlist.lastWatchedEpisode(anime.id) > 0
                                      ? 'Continue EP ${watchlist.lastWatchedEpisode(anime.id) + 1}'
                                      : 'Watch Now',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 13.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.1),

                        SizedBox(height: 14.h),

                        // ── Next episode countdown ──────────────────────────
                        if (anime.nextAiringEpisode != null)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: _NextEpisodeCard(
                              next: anime.nextAiringEpisode!,
                            ),
                          ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.05),

                        // ── Genres ──────────────────────────────────────────
                        if (anime.genres.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 6.h,
                              children: anime.genres
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SearchScreen(
                                            initialGenre: e.value,
                                          ),
                                        ),
                                      ),
                                      child:
                                          Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        20.r,
                                                      ),
                                                  border: Border.all(
                                                    color: AppTheme.primary
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  e.value,
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.primaryLight,
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              )
                                              .animate(delay: (e.key * 30).ms)
                                              .fadeIn()
                                              .scale(
                                                begin: const Offset(0.8, 0.8),
                                              ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),

                        // ── Studios ─────────────────────────────────────────
                        if ((anime.studios ?? []).isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
                            child: Text(
                              '🏢 ${anime.studios!.join(', ')}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),

                        // ── Synopsis ─────────────────────────────────────────
                        if (anime.description != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SYNOPSIS',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                _ExpandableText(anime.description!),
                              ],
                            ),
                          ),

                        // ── Episodes ─────────────────────────────────────────
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else if (_episodes.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              24.h,
                              16.w,
                              10.h,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4.w,
                                  height: 18.h,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(2.r),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: AppTheme.primary,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'Episodes (${_episodes.length})',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _EpisodeGrid(
                            episodes: _episodes,
                            animeId: anime.id,
                            onPlay: _play,
                          ),
                        ],

                        // ── Recommendations ──────────────────────────────────
                        if ((anime.recommendations ?? []).isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              28.h,
                              16.w,
                              10.h,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4.w,
                                  height: 18.h,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCyan,
                                    borderRadius: BorderRadius.circular(2.r),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: AppTheme.accentCyan,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'You Might Also Like',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 210.h,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              itemCount: anime.recommendations!.length,
                              itemBuilder: (ctx, i) => SizedBox(
                                width: 130.w,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                  ),
                                  child: AnimeCard(
                                    anime: anime.recommendations![i],
                                    index: i,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Next episode countdown card ───────────────────────────────────────────────
class _NextEpisodeCard extends StatefulWidget {
  final NextAiringEpisode next;
  const _NextEpisodeCard({required this.next});
  @override
  State<_NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<_NextEpisodeCard> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calcRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = _calcRemaining());
    });
  }

  Duration _calcRemaining() {
    final target = DateTime.fromMillisecondsSinceEpoch(
      widget.next.airingAt * 1000,
    );
    final diff = target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d == Duration.zero) return 'Airing now! 🔥';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (days > 0) return '${days}d ${hours}h ${mins}m';
    if (hours > 0) return '${hours}h ${mins}m ${secs}s';
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final isClose = _remaining.inHours < 1;
    final color = isClose ? AppTheme.accentGreen : AppTheme.accentCyan;
    final airingDate = DateTime.fromMillisecondsSinceEpoch(
      widget.next.airingAt * 1000,
    );
    final dateStr =
        '${_weekday(airingDate.weekday)}, ${_month(airingDate.month)} ${airingDate.day} · ${_time(airingDate)}';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16)],
      ),
      child: Row(
        children: [
          Text(isClose ? '🔥' : '📅', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Episode ${widget.next.episode} ${isClose ? "airing very soon!" : "coming up"}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text(
              _fmt(_remaining),
              style: TextStyle(
                color: color,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ── Episode grid ──────────────────────────────────────────────────────────────
class _EpisodeGrid extends StatelessWidget {
  final List<Episode> episodes;
  final int animeId;
  final ValueChanged<Episode> onPlay;
  const _EpisodeGrid({
    required this.episodes,
    required this.animeId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 1.1,
          crossAxisSpacing: 6.w,
          mainAxisSpacing: 6.h,
        ),
        itemCount: episodes.length,
        itemBuilder: (ctx, i) {
          final ep = episodes[i];
          final isWatched = watchlist.isWatched(animeId, ep.number);
          return GestureDetector(
            onTap: () => onPlay(ep),
            child: Container(
              decoration: BoxDecoration(
                color: isWatched
                    ? AppTheme.primary.withOpacity(0.15)
                    : AppTheme.darkCard,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isWatched
                      ? AppTheme.primary.withOpacity(0.4)
                      : AppTheme.darkBorder,
                ),
              ),
              child: Center(
                child: Text(
                  '${ep.number}',
                  style: TextStyle(
                    color: isWatched
                        ? AppTheme.primaryLight
                        : AppTheme.textPrimary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ).animate(delay: (i * 10).ms).fadeIn(duration: 200.ms);
        },
      ),
    );
  }
}

// ── Status picker button ──────────────────────────────────────────────────────
class _StatusPickerButton extends StatelessWidget {
  final int animeId;
  const _StatusPickerButton({required this.animeId});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final status = watchlist.getStatus(animeId);

    return GestureDetector(
      onTap: () => _showPicker(context, watchlist, status),
      child: AnimatedContainer(
        duration: 200.ms,
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: status != null
              ? status.color.withOpacity(0.2)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: status != null
                ? status.color.withOpacity(0.5)
                : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status?.emoji ?? '＋', style: TextStyle(fontSize: 13.sp)),
            SizedBox(width: 4.w),
            Text(
              status?.label ?? 'Add to List',
              style: TextStyle(
                color: status?.color ?? AppTheme.textPrimary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    WatchlistService watchlist,
    WatchStatus? current,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorder,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Add to List',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              ...WatchStatus.values.map(
                (s) => ListTile(
                  leading: Text(s.emoji, style: TextStyle(fontSize: 20.sp)),
                  title: Text(
                    s.label,
                    style: TextStyle(
                      color: s == current ? s.color : AppTheme.textPrimary,
                      fontWeight: s == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                  trailing: s == current
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: s.color,
                          size: 20.sp,
                        )
                      : null,
                  onTap: () {
                    watchlist.setStatus(animeId, s == current ? null : s);
                    Navigator.pop(context);
                  },
                ),
              ),
              if (current != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.accentPink,
                    size: 22.sp,
                  ),
                  title: Text(
                    'Remove from list',
                    style: TextStyle(
                      color: AppTheme.accentPink,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    watchlist.removeFromList(animeId);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6.r),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText(this.text);
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _expanded = !_expanded),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: 300.ms,
          curve: Curves.easeInOut,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFAAAACC),
              fontSize: 12.sp,
              height: 1.7,
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          _expanded ? 'Show less ▲' : 'Read more ▼',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
