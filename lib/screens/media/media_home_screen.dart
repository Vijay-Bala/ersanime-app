import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/media_item.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/media_card.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';
import 'media_search_screen.dart';
import '../../main.dart';

class MediaHomeScreen extends StatefulWidget {
  const MediaHomeScreen({super.key});
  @override
  State<MediaHomeScreen> createState() => _MediaHomeScreenState();
}

class _MediaHomeScreenState extends State<MediaHomeScreen> {
  MediaHomeData? _data;
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
      final data = await getMediaHomeData();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
              MaterialPageRoute(builder: (_) => const MediaSearchScreen()),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _loading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                MediaRowSkeleton(),
                MediaRowSkeleton(),
                MediaRowSkeleton(),
              ],
            )
          : _error != null
          ? ErrorBody(onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.accentOrange,
              backgroundColor: AppTheme.darkCard,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.only(bottom: 24.h),
                children: [
                  _MediaRow(
                    title: '🔥 Trending Movies',
                    color: AppTheme.accentOrange,
                    items: _data!.trendingMovies,
                    rowIndex: 0,
                  ),
                  _MediaRow(
                    title: '📺 Trending Series',
                    color: AppTheme.accentCyan,
                    items: _data!.trendingSeries,
                    rowIndex: 1,
                  ),
                  _MediaRow(
                    title: '👑 Top Rated Movies',
                    color: AppTheme.primary,
                    items: _data!.topRatedMovies,
                    rowIndex: 2,
                  ),
                  _MediaRow(
                    title: '🏆 Top Rated Series',
                    color: AppTheme.accentGreen,
                    items: _data!.topRatedSeries,
                    rowIndex: 3,
                  ),
                  _MediaRow(
                    title: '🇮🇳 Bollywood',
                    color: const Color(0xFFFF9933),
                    items: _data!.bollywood,
                    rowIndex: 4,
                  ),
                  _MediaRow(
                    title: '🇰🇷 Korean',
                    color: AppTheme.accentPink,
                    items: _data!.korean,
                    rowIndex: 5,
                  ),
                  _MediaRow(
                    title: '🎬 Tamil',
                    color: AppTheme.accentYellow,
                    items: _data!.tamil,
                    rowIndex: 6,
                  ),
                  _MediaRow(
                    title: '🎞 Malayalam',
                    color: AppTheme.accentGreen,
                    items: _data!.malayalam,
                    rowIndex: 7,
                  ),
                  _MediaRow(
                    title: '🇯🇵 Japanese',
                    color: AppTheme.accentCyan,
                    items: _data!.japanese,
                    rowIndex: 8,
                  ),
                  _MediaRow(
                    title: '🇨🇳 Chinese',
                    color: const Color(0xFFFF4444),
                    items: _data!.chinese,
                    rowIndex: 9,
                  ),
                  _MediaRow(
                    title: '🎭 Telugu',
                    color: AppTheme.accentOrange,
                    items: _data!.telugu,
                    rowIndex: 10,
                  ),
                ],
              ),
            ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final String title;
  final Color color;
  final List<MediaItem> items;
  final int rowIndex;
  const _MediaRow({
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
              child: MediaCard(item: items[i], index: i),
            ),
          ),
        ),
      ),
    );
  }
}
