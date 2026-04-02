import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../services/watchlist_service.dart';
import '../../services/anilist_service.dart';
import '../../models/manga.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/skeleton.dart';
import '../../theme/app_theme.dart';

class MangaLibraryScreen extends StatefulWidget {
  const MangaLibraryScreen({super.key});
  @override
  State<MangaLibraryScreen> createState() => _MangaLibraryScreenState();
}

class _MangaLibraryScreenState extends State<MangaLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _cache = <int, Manga>{};
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

  Future<List<Manga>> _loadMangas(List<int> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      if (mounted) setState(() => _loading = true);
      try {
        final mangas = await Future.wait(
          missing.map((id) => getMangaDetail(id)),
        );
        for (final m in mangas) {
          _cache[m.id] = m;
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
    return ids.map((id) => _cache[id]).whereType<Manga>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(
          'Manga Library',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accentGreen,
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
                loadMangas: _loadMangas,
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
  final Future<List<Manga>> Function(List<int>) loadMangas;
  final bool loading;
  const _StatusTab({
    required this.status,
    required this.loadMangas,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final ids = watchlist.getMangaByStatus(status);

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
              'No manga in ${status.label}',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 100.ms),
            SizedBox(height: 6.h),
            Text(
              'Add manga from their detail page',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
            ).animate().fadeIn(delay: 150.ms),
          ],
        ),
      );
    }

    return FutureBuilder<List<Manga>>(
      future: loadMangas(ids),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AnimeGridSkeleton();
        }
        final mangas = snap.data ?? [];
        return GridView.builder(
          padding: EdgeInsets.all(12.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
          ),
          itemCount: mangas.length,
          itemBuilder: (ctx, i) => MangaCard(manga: mangas[i], index: i),
        );
      },
    );
  }
}
