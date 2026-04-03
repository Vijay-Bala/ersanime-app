import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/manga.dart';
import '../../services/anilist_service.dart';
import '../../services/manga_service.dart';
import '../../theme/app_theme.dart';
import '../../services/watchlist_service.dart';
import '../../widgets/manga_card.dart';
import 'package:provider/provider.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final Manga manga;
  const MangaDetailScreen({super.key, required this.manga});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  Manga? _manga;
  List<MangaChapter>? _chapters;
  bool _loading = true;
  bool _loadingChapters = true;
  int _chapterDisplayCount = 50;

  @override
  void initState() {
    super.initState();
    _manga = widget.manga;
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await getMangaDetail(widget.manga.id);
      if (mounted) setState(() { _manga = detail; _loading = false; });
    } catch (e, st) {
      debugPrint('[MANGA-DETAIL] getMangaDetail error: $e\n$st');
      if (mounted) setState(() { _loading = false; });
    }

    try {
      debugPrint('[MANGA-DETAIL] Calling fetchAvailableChapters for "${widget.manga.title}" (AniList:${widget.manga.id}, MAL:${widget.manga.idMal})');
      final chapters = await MangaService.fetchAvailableChapters(widget.manga);
      debugPrint('[MANGA-DETAIL] fetchAvailableChapters returned ${chapters.length} chapters');
      if (mounted) setState(() { _chapters = chapters; _loadingChapters = false; });
    } catch (e, st) {
      debugPrint('[MANGA-DETAIL] fetchAvailableChapters EXCEPTION: $e\n$st');
      if (mounted) setState(() { _chapters = []; _loadingChapters = false; });
    }
  }


  void _readChapter(MangaChapter chapter) {
    context.read<WatchlistService>().markMangaRead(_manga!.id, chapter.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          chapter: chapter,
          chapters: _chapters!,
          mangaTitle: _manga!.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final manga = _manga;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.h,
            pinned: true,
            backgroundColor: AppTheme.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              background: manga?.cover != null || manga?.image != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black54,
                            BlendMode.darken,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: manga!.cover ?? manga.image,
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
                              colors: [Colors.transparent, AppTheme.darkBg],
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            actions: [
              if (manga != null) _StatusPickerButton(mangaId: manga.id),
              SizedBox(width: 4.w),
            ],
          ),
          if (manga != null)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 110.w,
                          height: 160.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                                color: AppTheme.accentGreen.withOpacity(0.4),
                                width: 1.5),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: CachedNetworkImage(
                            imageUrl: manga.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.title,
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w900),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 5.w,
                                runSpacing: 5.h,
                                children: [
                                  if (manga.rating != null)
                                    _Badge('★ ${manga.rating!.toStringAsFixed(1)}',
                                        AppTheme.accentYellow),
                                  if (manga.format != null)
                                    _Badge(manga.format!, AppTheme.accentGreen),
                                  if (manga.status != null)
                                    _Badge(
                                        manga.status!,
                                        manga.status == 'Ongoing'
                                            ? AppTheme.accentGreen
                                            : AppTheme.accentCyan),
                                  if (manga.year != null)
                                    _Badge('${manga.year}', AppTheme.textSecondary),
                                ],
                              ),
                              if (watchlist.getMangaStatus(manga.id) != null) ...[
                                SizedBox(height: 8.h),
                                _StatusIndicator(status: watchlist.getMangaStatus(manga.id)!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  if (_chapters != null && _chapters!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _readChapter(_chapters!.last),
                          icon: const Icon(Icons.menu_book_rounded, size: 20),
                          label: const Text('Read Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (manga.description != null) ...[
                          Text('SYNOPSIS',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0)),
                          SizedBox(height: 6.h),
                          ExpandableText(text: manga.description!),
                          SizedBox(height: 24.h),
                        ],
                        _buildChaptersSection(),
                        SizedBox(height: 24.h),
                        if (!_loading &&
                            manga.recommendations != null &&
                            manga.recommendations!.isNotEmpty) ...[
                          Text('Recommended',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 12.h),
                          SizedBox(
                            height: 220.h,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: manga.recommendations!.length,
                              itemBuilder: (c, i) => SizedBox(
                                width: 130.w,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8.w),
                                  child: MangaCard(
                                      manga: manga.recommendations![i], index: i),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 48.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChaptersSection() {
    if (_loadingChapters) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.h),
          child: const CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    if (_chapters == null || _chapters!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Text('No chapters available', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp)),
        ),
      );
    }

    // Use actual fetched count, falling back to AniList metadata if still loading
    final totalCount = _chapters!.length;
    // Clamp display count so we never exceed what we have
    final displayCount = _chapterDisplayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters ($totalCount)',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.sort, color: AppTheme.textSecondary),
              onPressed: () {
                setState(() {
                  _chapters = _chapters!.reversed.toList();
                });
              },
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (c, i) => Divider(color: AppTheme.darkBorder, height: 1),
          itemBuilder: (c, i) {
            final chap = _chapters![i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Chapter ${chap.chapterNumber}', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(chap.title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Icon(Icons.menu_book, color: AppTheme.primary, size: 20.sp),
              onTap: () => _readChapter(chap),
            );
          },
        ),
        if (hasMore) ...[
          SizedBox(height: 12.h),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _chapterDisplayCount += 100),
              icon: Icon(Icons.expand_more, color: AppTheme.accentGreen),
              label: Text(
                'Show more (${totalCount - displayCount} remaining)',
                style: TextStyle(color: AppTheme.accentGreen, fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusPickerButton extends StatelessWidget {
  final int mangaId;
  const _StatusPickerButton({required this.mangaId});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final status = watchlist.getMangaStatus(mangaId);

    return GestureDetector(
      onTap: () => _showPicker(context, watchlist, status),
      child: Container(
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

  void _showPicker(BuildContext context, WatchlistService watchlist, WatchStatus? current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16.h),
            Text('Add to List', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 8.h),
            ...WatchStatus.values.map(
              (s) => ListTile(
                leading: Text(s.emoji, style: TextStyle(fontSize: 20.sp)),
                title: Text(s.label, style: TextStyle(color: s == current ? s.color : AppTheme.textPrimary, fontWeight: s == current ? FontWeight.w800 : FontWeight.w500)),
                trailing: s == current ? Icon(Icons.check_circle_rounded, color: s.color) : null,
                onTap: () {
                  watchlist.setMangaStatus(mangaId, s == current ? null : s);
                  Navigator.pop(context);
                },
              ),
            ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentPink),
                title: const Text('Remove from list', style: TextStyle(color: AppTheme.accentPink)),
                onTap: () {
                  watchlist.removeMangaFromList(mangaId);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final WatchStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        '${status.emoji} ${status.label}',
        style: TextStyle(color: status.color, fontSize: 10.sp, fontWeight: FontWeight.w700),
      ),
    );
  }
}

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
    child: Text(text, style: TextStyle(color: color, fontSize: 9.sp, fontWeight: FontWeight.w700)),
  );
}

class ExpandableText extends StatefulWidget {
  final String text;
  const ExpandableText({super.key, required this.text});
  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _expanded = !_expanded),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: TextStyle(color: const Color(0xFFAAAACC), fontSize: 12.sp, height: 1.7),
        ),
        SizedBox(height: 4.h),
        Text(_expanded ? 'Show less ▲' : 'Read more ▼', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11.sp, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
