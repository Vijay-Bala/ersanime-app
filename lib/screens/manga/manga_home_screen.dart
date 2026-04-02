import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/manga.dart';
import '../../services/anilist_service.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';
import 'manga_search_screen.dart';

class MangaHomeScreen extends StatefulWidget {
  const MangaHomeScreen({super.key});
  @override
  State<MangaHomeScreen> createState() => _MangaHomeScreenState();
}

class _MangaHomeScreenState extends State<MangaHomeScreen> {
  MangaHomeData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await getMangaHomeData();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(
          'Manga',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppTheme.textPrimary, size: 22.sp),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MangaSearchScreen()),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _loading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: const [AnimeRowSkeleton(), AnimeRowSkeleton(), AnimeRowSkeleton()],
            )
          : _error != null
          ? ErrorBody(onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.darkCard,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.only(bottom: 24.h),
                children: [
                  _MangaRow(title: '🔥 Trending Now', color: AppTheme.primary, items: _data!.trending, rowIndex: 0),
                  _MangaRow(title: '⚡ Top Rated', color: AppTheme.accentGreen, items: _data!.topManga, rowIndex: 1),
                  _MangaRow(title: '👑 Most Popular', color: AppTheme.accentCyan, items: _data!.popular, rowIndex: 2),
                  _MangaRow(title: '🆕 Recently Added', color: AppTheme.accentPink, items: _data!.recent, rowIndex: 3),
                ],
              ),
            ),
    );
  }
}

class _MangaRow extends StatelessWidget {
  final String title;
  final Color color;
  final List<Manga> items;
  final int rowIndex;

  const _MangaRow({required this.title, required this.color, required this.items, required this.rowIndex});

  @override
  Widget build(BuildContext context) {
    return SectionRow(
      title: title,
      color: color,
      rowIndex: rowIndex,
      child: SizedBox(
        height: 220.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          itemCount: items.length,
          itemBuilder: (ctx, i) => SizedBox(
            width: 130.w,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: MangaCard(manga: items[i], index: i),
            ),
          ),
        ),
      ),
    );
  }
}
