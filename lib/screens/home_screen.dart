import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/anime.dart';
import '../services/anilist_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/skeleton.dart';
import '../theme/app_theme.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _data;
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
      final data = await getHomeData();
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
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accentCyan],
          ).createShader(bounds),
          child: Text(
            'ERSAnime',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: AppTheme.textPrimary,
              size: 22.sp,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : _error != null
          ? _buildError()
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

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AnimeRowSkeleton(),
        AnimeRowSkeleton(),
        AnimeRowSkeleton(),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 52.sp,
          ).animate().shake(),
          SizedBox(height: 14.h),
          Text(
            'Could not connect',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 100.ms),
          SizedBox(height: 6.h),
          Text(
            'Check your internet and try again',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.sp),
          ).animate().fadeIn(delay: 150.ms),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.r),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(color: color.withOpacity(0.4), blurRadius: 12),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: (rowIndex * 80).ms).fadeIn().slideX(begin: -0.05),
        SizedBox(
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
      ],
    );
  }
}
