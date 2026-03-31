import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../services/watchlist_service.dart';
import '../../services/tmdb_service.dart';
import '../../models/media_item.dart';
import '../../widgets/media_card.dart';
import '../../theme/app_theme.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});
  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _cache = <int, MediaItem>{};

  static const _statuses = WatchStatus.values;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<MediaItem>> _loadItems(List<int> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      try {
        await Future.wait(
          missing.map((id) async {
            try {
              final item = await getMovieDetail(id);
              _cache[id] = item;
            } catch (_) {
              try {
                final item = await getTvDetail(id);
                _cache[id] = item;
              } catch (_) {}
            }
          }),
        );
      } catch (_) {}
    }
    return ids.map((id) => _cache[id]).whereType<MediaItem>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(
          'My Watchlist',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accentOrange,
          indicatorWeight: 2.5,
          labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
          tabs: _statuses
              .map(
                (s) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.emoji, style: TextStyle(fontSize: 13.sp)),
                      SizedBox(width: 5.w),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _statuses
            .map((status) => _StatusTab(status: status, loadItems: _loadItems))
            .toList(),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final WatchStatus status;
  final Future<List<MediaItem>> Function(List<int>) loadItems;
  const _StatusTab({required this.status, required this.loadItems});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final ids = watchlist.getMediaByStatus(status);

    if (ids.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status.emoji, style: TextStyle(fontSize: 52.sp))
                .animate()
                .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
            SizedBox(height: 14.h),
            Text(
              'Nothing in ${status.label}',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 100.ms),
            SizedBox(height: 6.h),
            Text(
              'Add movies/series from their detail page',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
            ).animate().fadeIn(delay: 150.ms),
          ],
        ),
      );
    }

    return FutureBuilder<List<MediaItem>>(
      future: loadItems(ids),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            padding: EdgeInsets.all(12.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.52,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.darkBorder),
              ),
            ),
          );
        }
        final items = snap.data ?? [];
        return GridView.builder(
          padding: EdgeInsets.all(12.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.52,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => MediaCard(item: items[i], index: i),
        );
      },
    );
  }
}
