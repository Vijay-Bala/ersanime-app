import 'package:flutter/material.dart' hide Badge;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../services/tmdb_service.dart';
import '../../services/watchlist_service.dart';
import '../../widgets/media_card.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';
import 'media_player_screen.dart';

class MediaDetailScreen extends StatefulWidget {
  final int itemId;
  final bool isSeries;
  final MediaItem? item;
  const MediaDetailScreen({
    super.key,
    required this.itemId,
    required this.isSeries,
    this.item,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  MediaItem? _item;
  List<TvEpisode> _episodes = [];
  bool _loading = true;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _load();
  }

  Future<void> _load() async {
    try {
      final item = widget.isSeries
          ? await getTvDetail(widget.itemId)
          : await getMovieDetail(widget.itemId);
      if (mounted) {
        setState(() {
          _item = item;
          _loading = false;
        });
        if (widget.isSeries &&
            item.seasons != null &&
            item.seasons!.isNotEmpty) {
          _loadEpisodes(_selectedSeason);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEpisodes(int season) async {
    setState(() {
      _selectedSeason = season;
      _episodes = [];
    });
    try {
      final eps = await getSeasonEpisodes(widget.itemId, season);
      if (mounted) setState(() => _episodes = eps);
    } catch (_) {}
  }

  void _playMovie({bool dubbed = false}) {
    if (_item == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => MediaPlayerScreen(
          item: _item!,
          embedUrls: getMovieEmbedUrls(_item!.id, dubbed: dubbed),
          startDubbed: dubbed,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    context.read<WatchlistService>().markMediaWatched(_item!.id);
  }

  void _playEpisode(TvEpisode ep, {bool dubbed = false}) {
    if (_item == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => MediaPlayerScreen(
          item: _item!,
          embedUrls: getTvEmbedUrls(_item!.id, _selectedSeason, ep.number,
              dubbed: dubbed),
          season: _selectedSeason,
          episode: ep,
          allEpisodes: _episodes,
          startDubbed: dubbed,
          onEpisodeChange: (newEp) => _playEpisode(newEp),
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    context.read<WatchlistService>().markMediaWatched(
      _item!.id,
      season: _selectedSeason,
      episode: ep.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WatchlistService>();
    final item = _item;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _loading && item == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 240.h,
                  pinned: true,
                  backgroundColor: AppTheme.darkBg,
                  flexibleSpace: FlexibleSpaceBar(
                    background: item?.cover != null || item?.image != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.black54,
                                  BlendMode.darken,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: item!.cover?.isNotEmpty == true
                                      ? item.cover!
                                      : item.image,
                                  fit: BoxFit.cover,
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
                    if (item != null) _StatusPickerButton(itemId: item.id),
                    SizedBox(width: 4.w),
                  ],
                ),
                if (item != null)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 110.w,
                                height: 160.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppTheme.accentOrange.withOpacity(
                                      0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentOrange.withOpacity(
                                        0.25,
                                      ),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: CachedNetworkImage(
                                  imageUrl: item.image,
                                  fit: BoxFit.cover,
                                ),
                              ).animate().fadeIn().slideY(begin: 0.1),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ).animate().fadeIn(delay: 80.ms),
                                    SizedBox(height: 8.h),
                                    Wrap(
                                      spacing: 5.w,
                                      runSpacing: 5.h,
                                      children: [
                                        if (item.rating != null)
                                          Badge(
                                            '★ ${item.rating!.toStringAsFixed(1)}',
                                            AppTheme.accentYellow,
                                          ),
                                        Badge(
                                          item.isSeries ? 'Series' : 'Movie',
                                          item.isSeries
                                              ? AppTheme.accentCyan
                                              : AppTheme.accentOrange,
                                        ),
                                        if (item.totalSeasons != null)
                                          Badge(
                                            '${item.totalSeasons} Seasons',
                                            AppTheme.primary,
                                          ),
                                        if (item.year != null)
                                          Badge(
                                            '${item.year}',
                                            AppTheme.accentGreen,
                                          ),
                                        if (item.status != null)
                                          Badge(
                                            item.status!,
                                            AppTheme.accentPink,
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    if (!item.isSeries)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _playMovie(dubbed: false),
                                            icon: const Icon(
                                              Icons.play_arrow_rounded,
                                            ),
                                            label: const Text('SUB'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.accentOrange,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 10.h,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  10.r,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _playMovie(dubbed: true),
                                            icon: const Icon(
                                              Icons.translate_rounded,
                                            ),
                                            label: const Text('DUB'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.darkCard,
                                              foregroundColor:
                                                  AppTheme.textPrimary,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 10.h,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  10.r,
                                                ),
                                                side: BorderSide(
                                                    color: AppTheme.darkBorder),
                                              ),
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
                        SizedBox(height: 16.h),
                        if (item.genres.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 6.h,
                              children: item.genres
                                  .map((g) => Badge(g, AppTheme.primary))
                                  .toList(),
                            ),
                          ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: _ExpandableDescription(
                              text: item.description!,
                            ),
                          ),
                        ],
                        if (item.isSeries && item.seasons != null) ...[
                          SizedBox(height: 20.h),
                          _SeasonSelector(
                            seasons: item.seasons!,
                            selectedSeason: _selectedSeason,
                            onSelect: _loadEpisodes,
                          ),
                          SizedBox(height: 8.h),
                          if (_episodes.isEmpty)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.h),
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentOrange,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            _EpisodeList(
                              episodes: _episodes,
                              onPlay: (ep, {bool dubbed = false}) =>
                                  _playEpisode(ep, dubbed: dubbed),
                              itemId: item.id,
                              season: _selectedSeason,
                            ),
                        ],
                        if (item.recommendations != null &&
                            item.recommendations!.isNotEmpty) ...[
                          SizedBox(height: 24.h),
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                            child: Text(
                              'More Like This',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 220.h,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              itemCount: item.recommendations!.length,
                              itemBuilder: (ctx, i) => SizedBox(
                                width: 130.w,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                  ),
                                  child: MediaCard(
                                    item: item.recommendations![i],
                                    index: i,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusPickerButton extends StatelessWidget {
  final int itemId;
  const _StatusPickerButton({required this.itemId});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final current = watchlist.getMediaStatus(itemId);
    return IconButton(
      icon: Icon(
        current != null
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        color: current != null ? AppTheme.accentOrange : AppTheme.textPrimary,
        size: 22.sp,
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorder,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              ...WatchStatus.values.map(
                (s) => ListTile(
                  leading: Text(s.emoji, style: TextStyle(fontSize: 18.sp)),
                  title: Text(
                    s.label,
                    style: TextStyle(
                      color: s == current
                          ? AppTheme.accentOrange
                          : AppTheme.textPrimary,
                      fontWeight: s == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: s == current
                      ? Icon(
                          Icons.check_rounded,
                          color: AppTheme.accentOrange,
                          size: 18.sp,
                        )
                      : null,
                  onTap: () {
                    watchlist.setMediaStatus(itemId, s == current ? null : s);
                    Navigator.pop(context);
                  },
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  final List<TvSeason> seasons;
  final int selectedSeason;
  final ValueChanged<int> onSelect;
  const _SeasonSelector({
    required this.seasons,
    required this.selectedSeason,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: seasons.length,
        itemBuilder: (_, i) {
          final s = seasons[i];
          final active = s.seasonNumber == selectedSeason;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => onSelect(s.seasonNumber),
              child: AnimatedContainer(
                duration: 150.ms,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.accentOrange.withOpacity(0.2)
                      : AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: active ? AppTheme.accentOrange : AppTheme.darkBorder,
                  ),
                ),
                child: Text(
                  'S${s.seasonNumber}',
                  style: TextStyle(
                    color: active
                        ? AppTheme.accentOrange
                        : AppTheme.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeList extends StatelessWidget {
  final List<TvEpisode> episodes;
  final void Function(TvEpisode ep, {bool dubbed}) onPlay;
  final int itemId;
  final int season;
  const _EpisodeList({
    required this.episodes,
    required this.onPlay,
    required this.itemId,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: episodes.length,
      itemBuilder: (_, i) {
        final ep = episodes[i];
        final watched = watchlist.isMediaWatched(itemId, season: season, episode: ep.number);
        return GestureDetector(
          onTap: () => _showAudioSheet(context, ep),
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: watched
                    ? AppTheme.accentGreen.withOpacity(0.3)
                    : AppTheme.darkBorder,
              ),
            ),
            child: Row(
              children: [
                if (ep.image.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: CachedNetworkImage(
                      imageUrl: ep.image,
                      width: 80.w,
                      height: 50.h,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 80.w,
                        height: 50.h,
                        color: AppTheme.darkCardElev,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardElev,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 22.sp,
                    ),
                  ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E${ep.number}: ${ep.name}',
                        style: TextStyle(
                          color: watched
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ep.overview != null && ep.overview!.isNotEmpty)
                        Text(
                          ep.overview!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(
                  watched
                      ? Icons.check_circle_rounded
                      : Icons.play_arrow_rounded,
                  color: watched ? AppTheme.accentGreen : AppTheme.accentOrange,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAudioSheet(BuildContext context, TvEpisode ep) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E${ep.number}: ${ep.name}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select audio track',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AudioBtn(
                      label: 'SUB (Original)',
                      icon: Icons.subtitles_rounded,
                      color: AppTheme.accentOrange,
                      onTap: () {
                        Navigator.pop(context);
                        onPlay(ep, dubbed: false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AudioBtn(
                      label: 'DUB (Dubbed)',
                      icon: Icons.translate_rounded,
                      color: AppTheme.accentCyan,
                      onTap: () {
                        Navigator.pop(context);
                        onPlay(ep, dubbed: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AudioBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});
  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            firstChild: Text(
              widget.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
            secondChild: Text(
              widget.text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          SizedBox(height: 4.h),
          Text(
            _expanded ? 'Show less' : 'Read more',
            style: TextStyle(
              color: AppTheme.accentOrange,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
