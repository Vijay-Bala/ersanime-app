import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/anime.dart';
import '../../services/anilist_service.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import 'anime_search_screen.dart';

class AnimeHomeScreen extends StatefulWidget {
  const AnimeHomeScreen({super.key});
  @override
  State<AnimeHomeScreen> createState() => _AnimeHomeScreenState();
}

class _AnimeHomeScreenState extends State<AnimeHomeScreen> {
  AnimeHomeData? _data;
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
      final data = await getAnimeHomeData();
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: const ModeSwitcherTitle(),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: AppTheme.textPrimary,
              size: 22.sp,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnimeSearchScreen()),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _loading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                AnimeRowSkeleton(),
                AnimeRowSkeleton(),
                AnimeRowSkeleton(),
              ],
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
                  _AnimeRow(
                    title: '🔥 Trending Now',
                    color: AppTheme.primary,
                    items: _data!.trending,
                    rowIndex: 0,
                  ),
                  _AnimeRow(
                    title: '⚡ Top Airing',
                    color: AppTheme.accentGreen,
                    items: _data!.topAiring,
                    rowIndex: 1,
                  ),
                  _AnimeRow(
                    title: '👑 Most Popular',
                    color: AppTheme.accentCyan,
                    items: _data!.popular,
                    rowIndex: 2,
                  ),
                  _AnimeRow(
                    title: '🆕 Recently Added',
                    color: AppTheme.accentPink,
                    items: _data!.recent,
                    rowIndex: 3,
                  ),
                ],
              ),
            ),
    );
  }
}

class _AnimeRow extends StatelessWidget {
  final String title;
  final Color color;
  final List<Anime> items;
  final int rowIndex;
  const _AnimeRow({
    required this.title,
    required this.color,
    required this.items,
    required this.rowIndex,
  });

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
              child: AnimeCard(anime: items[i], index: i),
            ),
          ),
        ),
      ),
    );
  }
}
