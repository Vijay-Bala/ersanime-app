import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/anime.dart';
import '../services/anilist_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/skeleton.dart';
import '../theme/app_theme.dart';

// ── All AniList genres ────────────────────────────────────────────────────────
const kAllGenres = [
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
  'Harem',
  'Historical',
  'Isekai',
  'Martial Arts',
  'Military',
  'School',
  'Shounen',
  'Shoujo',
  'Seinen',
  'Josei',
  'Demons',
  'Game',
  'Kids',
  'Magic',
  'Parody',
  'Police',
  'Samurai',
  'Space',
  'Super Power',
  'Vampire',
  'Yaoi',
  'Yuri',
];

class SearchScreen extends StatefulWidget {
  final String? initialGenre;
  const SearchScreen({super.key, this.initialGenre});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Anime> _results = [];
  List<Anime> _suggestions = []; // live suggestions (first 5 results)
  bool _loading = false;
  bool _showSuggestions = false;
  String _lastQuery = '';
  Set<String> _selectedGenres = {};

  Timer? _debounce;
  late AnimationController _suggestAnim;

  @override
  void initState() {
    super.initState();
    _suggestAnim = AnimationController(vsync: this, duration: 200.ms);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideSuggestions();
      }
    });

    if (widget.initialGenre != null) {
      _selectedGenres = {widget.initialGenre!};
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      _hideSuggestions();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _fetchSuggestions(v.trim()),
    );
  }

  Future<void> _fetchSuggestions(String q) async {
    try {
      final res = await searchAnime(q);
      if (!mounted) return;
      setState(() {
        _suggestions = res.take(6).toList();
        _showSuggestions = _suggestions.isNotEmpty && _focusNode.hasFocus;
      });
      if (_showSuggestions) _suggestAnim.forward();
    } catch (_) {}
  }

  void _hideSuggestions() {
    _suggestAnim.reverse().then((_) {
      if (mounted) setState(() => _showSuggestions = false);
    });
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    final hasGenres = _selectedGenres.isNotEmpty;
    if (q.isEmpty && !hasGenres) return;
    _hideSuggestions();
    _focusNode.unfocus();

    if (q == _lastQuery && _selectedGenres.isEmpty) return;
    _lastQuery = q;

    setState(() => _loading = true);
    try {
      List<Anime> results;
      if (_selectedGenres.isNotEmpty && q.isEmpty) {
        // Genre-only: fetch each genre and merge unique results
        final futures = _selectedGenres.map((g) => searchByGenre(g));
        final all = await Future.wait(futures);
        final seen = <int>{};
        results = all.expand((l) => l).where((a) => seen.add(a.id)).toList();
        results.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      } else if (_selectedGenres.isNotEmpty && q.isNotEmpty) {
        // Both: text search then filter by selected genres client-side
        results = await searchAnime(q);
        results = results
            .where((a) => _selectedGenres.any((g) => a.genres.contains(g)))
            .toList();
      } else {
        results = await searchAnime(q);
      }
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleGenre(String g) {
    setState(() {
      if (_selectedGenres.contains(g)) {
        _selectedGenres.remove(g);
      } else {
        _selectedGenres.add(g);
      }
    });
    // Auto search when genre changes
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _runSearch);
  }

  void _clearAll() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _suggestions = [];
      _selectedGenres = {};
      _lastQuery = '';
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        titleSpacing: 0,
        title: Row(
          children: [
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                autofocus: widget.initialGenre == null,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'Search anime...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.textSecondary,
                    size: 20.sp,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                onChanged: _onChanged,
                onSubmitted: (_) => _runSearch(),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_ctrl.text.isNotEmpty || _selectedGenres.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppTheme.textSecondary,
                  size: 20.sp,
                ),
                onPressed: _clearAll,
              ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Genre chips ───────────────────────────────────────────────────
          _GenreChips(selected: _selectedGenres, onToggle: _toggleGenre),

          // ── Results / suggestions / empty ─────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Main results
                _loading
                    ? const AnimeGridSkeleton()
                    : _results.isEmpty
                    ? _EmptyState(
                        hasGenres: _selectedGenres.isNotEmpty,
                        query: _ctrl.text,
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(12.w),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) =>
                            AnimeCard(anime: _results[i], index: i),
                      ),

                // ── Suggestion dropdown ───────────────────────────────────
                if (_showSuggestions)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _suggestAnim,
                      builder: (_, child) => Opacity(
                        opacity: _suggestAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, -8 * (1 - _suggestAnim.value)),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardElev,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _suggestions.asMap().entries.map((e) {
                            final anime = e.value;
                            return InkWell(
                              onTap: () {
                                _ctrl.text = anime.title;
                                _hideSuggestions();
                                _focusNode.unfocus();
                                _lastQuery = '';
                                _runSearch();
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6.r),
                                      child: Image.network(
                                        anime.image,
                                        width: 32.w,
                                        height: 44.h,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 32.w,
                                          height: 44.h,
                                          color: AppTheme.darkCard,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            anime.title,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            [
                                              if (anime.format != null)
                                                anime.format!,
                                              if (anime.year != null)
                                                '${anime.year}',
                                            ].join(' · '),
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 10.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (anime.rating != null)
                                      Text(
                                        '★ ${anime.rating!.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: AppTheme.accentYellow,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _suggestAnim.dispose();
    super.dispose();
  }
}

// ── Genre chip bar ────────────────────────────────────────────────────────────
class _GenreChips extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _GenreChips({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      color: AppTheme.darkSurface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        itemCount: kAllGenres.length,
        itemBuilder: (_, i) {
          final g = kAllGenres[i];
          final active = selected.contains(g);
          return Padding(
            padding: EdgeInsets.only(right: 6.w),
            child: AnimatedContainer(
              duration: 200.ms,
              child: GestureDetector(
                onTap: () => onToggle(g),
                child: AnimatedContainer(
                  duration: 180.ms,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary.withOpacity(0.2)
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: active ? AppTheme.primary : AppTheme.darkBorder,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      color: active
                          ? AppTheme.primaryLight
                          : AppTheme.textSecondary,
                      fontSize: 11.sp,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
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

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasGenres;
  final String query;
  const _EmptyState({required this.hasGenres, required this.query});

  @override
  Widget build(BuildContext context) {
    final isFiltering = hasGenres || query.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isFiltering ? '😔' : '🔍', style: TextStyle(fontSize: 48.sp))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
          SizedBox(height: 14.h),
          Text(
            isFiltering ? 'No results found' : 'Search anime or pick genres',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 100.ms),
          SizedBox(height: 6.h),
          Text(
            isFiltering
                ? 'Try different keywords or genres'
                : 'Discover thousands of anime',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp),
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }
}
