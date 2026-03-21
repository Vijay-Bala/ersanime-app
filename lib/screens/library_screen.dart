import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/watchlist_service.dart';
import '../services/anilist_service.dart';
import '../models/anime.dart';
import '../widgets/anime_card.dart';
import '../widgets/skeleton.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _cache = <int, Anime>{};
  bool _loading = false;

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

  Future<List<Anime>> _loadAnimes(List<int> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      setState(() => _loading = true);
      try {
        final animes = await Future.wait(
          missing.map((id) => getAnimeDetail(id)),
        );
        for (final a in animes) {
          _cache[a.id] = a;
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
    return ids.map((id) => _cache[id]).whereType<Anime>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(
          'My Library',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
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
            .map(
              (status) => _StatusTab(
                status: status,
                loadAnimes: _loadAnimes,
                loading: _loading,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final WatchStatus status;
  final Future<List<Anime>> Function(List<int>) loadAnimes;
  final bool loading;
  const _StatusTab({
    required this.status,
    required this.loadAnimes,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final ids = watchlist.getByStatus(status);

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
              'No anime in ${status.label}',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 100.ms),
            SizedBox(height: 6.h),
            Text(
              'Add anime from their detail page',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
            ).animate().fadeIn(delay: 150.ms),
          ],
        ),
      );
    }

    return FutureBuilder<List<Anime>>(
      future: loadAnimes(ids),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AnimeGridSkeleton();
        }
        final animes = snap.data ?? [];
        return GridView.builder(
          padding: EdgeInsets.all(12.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
          ),
          itemCount: animes.length,
          itemBuilder: (ctx, i) => AnimeCard(anime: animes[i], index: i),
        );
      },
    );
  }
}
