import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/manga.dart';
import '../../services/anilist_service.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';
import 'dart:async';

class MangaSearchScreen extends StatefulWidget {
  final String? initialGenre;
  const MangaSearchScreen({super.key, this.initialGenre});

  @override
  State<MangaSearchScreen> createState() => _MangaSearchScreenState();
}

class _MangaSearchScreenState extends State<MangaSearchScreen> {
  final _ctl = TextEditingController();
  final List<String> _selectedGenres = [];
  Timer? _timer;
  List<Manga>? _results;
  bool _loading = false;
  String? _error;

  static const _allGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGenre != null) {
      _selectedGenres.add(widget.initialGenre!);
    }
    _doSearch(_ctl.text);
  }

  void _onChanged(String q) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  void _toggleGenre(String g) {
    setState(() {
      if (_selectedGenres.contains(g)) {
        _selectedGenres.remove(g);
      } else {
        _selectedGenres.add(g);
      }
    });
    _doSearch(_ctl.text);
  }

  Future<void> _doSearch(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await searchManga(q, genres: _selectedGenres);
      if (mounted)
        setState(() {
          _results = res;
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
        title: TextField(
          controller: _ctl,
          autofocus: widget.initialGenre == null,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'Search manga, manhwa...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: Column(
        children: [
          _buildGenreFilter(),
          Expanded(
            child: _loading
                ? GridView.builder(
                    padding: EdgeInsets.all(12.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 16.h,
                    ),
                    itemCount: 12,
                    itemBuilder: (c, i) => const AnimeRowSkeleton(),
                  )
                : _error != null
                ? ErrorBody(onRetry: () => _doSearch(_ctl.text))
                : _results == null || _results!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64.sp,
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No results found',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(12.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 16.h,
                    ),
                    itemCount: _results!.length,
                    itemBuilder: (c, i) =>
                        MangaCard(manga: _results![i], index: i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreFilter() {
    return Container(
      height: 40.h,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: _allGenres.length,
        itemBuilder: (c, i) {
          final g = _allGenres[i];
          final selected = _selectedGenres.contains(g);
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FilterChip(
              label: Text(
                g,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              selected: selected,
              onSelected: (_) => _toggleGenre(g),
              backgroundColor: AppTheme.darkCard,
              selectedColor: AppTheme.primary,
              checkmarkColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.darkBorder,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
