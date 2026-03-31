import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/media_item.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/media_card.dart';
import '../../theme/app_theme.dart';

const kLanguageFilters = [
  {'label': '🌐 All', 'code': ''},
  {'label': '🇺🇸 Hollywood', 'code': 'en'},
  {'label': '🇮🇳 Bollywood', 'code': 'hi'},
  {'label': '🇮🇳 Tamil', 'code': 'ta'},
  {'label': '🇮🇳 Telugu', 'code': 'te'},
  {'label': '🇮🇳 Malayalam', 'code': 'ml'},
  {'label': '🇰🇷 Korean', 'code': 'ko'},
  {'label': '🇯🇵 Japanese', 'code': 'ja'},
  {'label': '🇨🇳 Chinese', 'code': 'zh'},
  {'label': '🇫🇷 French', 'code': 'fr'},
  {'label': '🇪🇸 Spanish', 'code': 'es'},
];

const kMediaTypeFilters = ['All', 'Movies', 'Series'];

class MediaSearchScreen extends StatefulWidget {
  final String? initialLang;
  const MediaSearchScreen({super.key, this.initialLang});
  @override
  State<MediaSearchScreen> createState() => _MediaSearchScreenState();
}

class _MediaSearchScreenState extends State<MediaSearchScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<MediaItem> _results = [];
  List<MediaItem> _suggestions = [];
  bool _loading = false;
  bool _showSuggestions = false;
  String _lastQuery = '';
  String _selectedLang = '';
  String _typeFilter = 'All';
  Timer? _debounce;
  late AnimationController _suggestAnim;

  @override
  void initState() {
    super.initState();
    _suggestAnim = AnimationController(vsync: this, duration: 200.ms);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _hideSuggestions();
    });
    if (widget.initialLang != null) {
      _selectedLang = widget.initialLang!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLangDiscover());
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
      final res = await searchMedia(q);
      if (!mounted) return;
      final filtered = _applyTypeFilter(res);
      setState(() {
        _suggestions = filtered.take(6).toList();
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

  List<MediaItem> _applyTypeFilter(List<MediaItem> items) {
    if (_typeFilter == 'Movies') {
      return items.where((i) => !i.isSeries).toList();
    }
    if (_typeFilter == 'Series') return items.where((i) => i.isSeries).toList();
    return items;
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      if (_selectedLang.isNotEmpty) {
        _runLangDiscover();
      }
      return;
    }
    _hideSuggestions();
    _focusNode.unfocus();
    if (q == _lastQuery) return;
    _lastQuery = q;
    setState(() => _loading = true);
    try {
      var results = await searchMedia(q);
      if (_selectedLang.isNotEmpty) {
        results = results
            .where((i) => i.originalLanguage == _selectedLang)
            .toList();
      }
      results = _applyTypeFilter(results);
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

  Future<void> _runLangDiscover() async {
    if (_selectedLang.isEmpty) return;
    setState(() => _loading = true);
    try {
      final isTv = _typeFilter == 'Series';
      List<MediaItem> results;
      if (_typeFilter == 'All') {
        final both = await Future.wait([
          discoverByLanguage(_selectedLang, isTv: false),
          discoverByLanguage(_selectedLang, isTv: true),
        ]);
        results = [...both[0], ...both[1]];
        results.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      } else {
        results = await discoverByLanguage(_selectedLang, isTv: isTv);
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

  void _clearAll() {
    _ctrl.clear();
    setState(() {
      _results = [];
      _suggestions = [];
      _lastQuery = '';
      _showSuggestions = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _suggestAnim.dispose();
    super.dispose();
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
                autofocus: widget.initialLang == null,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'Search movies & series...',
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
            if (_ctrl.text.isNotEmpty)
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
          Container(
            height: 44.h,
            color: AppTheme.darkSurface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              itemCount: kLanguageFilters.length,
              itemBuilder: (_, i) {
                final f = kLanguageFilters[i];
                final active = _selectedLang == f['code'];
                return Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLang = f['code']!;
                        _results = [];
                        _lastQuery = '';
                      });
                      if (_ctrl.text.isEmpty && f['code']!.isNotEmpty) {
                        _runLangDiscover();
                      } else if (_ctrl.text.isNotEmpty)
                        _runSearch();
                    },
                    child: AnimatedContainer(
                      duration: 180.ms,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.accentOrange.withOpacity(0.2)
                            : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: active
                              ? AppTheme.accentOrange
                              : AppTheme.darkBorder,
                          width: active ? 1.5 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentOrange.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          color: active
                              ? AppTheme.accentOrange
                              : AppTheme.textSecondary,
                          fontSize: 11.sp,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 36.h,
            color: AppTheme.darkBg,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            child: Row(
              children: kMediaTypeFilters.map((t) {
                final active = _typeFilter == t;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _typeFilter = t;
                        _results = [];
                        _lastQuery = '';
                      });
                      if (_ctrl.text.isNotEmpty) {
                        _runSearch();
                      } else if (_selectedLang.isNotEmpty)
                        _runLangDiscover();
                    },
                    child: AnimatedContainer(
                      duration: 150.ms,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.accentCyan.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: active
                              ? AppTheme.accentCyan
                              : AppTheme.darkBorder,
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: active
                              ? AppTheme.accentCyan
                              : AppTheme.textSecondary,
                          fontSize: 11.sp,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _loading
                    ? _buildGridSkeleton()
                    : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedLang.isNotEmpty || _ctrl.text.isNotEmpty
                                  ? '😔'
                                  : '🎬',
                              style: TextStyle(fontSize: 48.sp),
                            ).animate().scale(
                              begin: const Offset(0.5, 0.5),
                              curve: Curves.elasticOut,
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              _selectedLang.isNotEmpty || _ctrl.text.isNotEmpty
                                  ? 'No results found'
                                  : 'Search or pick a language filter',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ).animate().fadeIn(delay: 100.ms),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(12.w),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.52,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) =>
                            MediaCard(item: _results[i], index: i),
                      ),
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
                            color: AppTheme.accentOrange.withOpacity(0.3),
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
                          children: _suggestions
                              .map(
                                (item) => InkWell(
                                  onTap: () {
                                    _ctrl.text = item.title;
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
                                          borderRadius: BorderRadius.circular(
                                            6.r,
                                          ),
                                          child: Image.network(
                                            item.image,
                                            width: 32.w,
                                            height: 44.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Container(
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
                                                item.title,
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                [
                                                  item.isSeries
                                                      ? 'Series'
                                                      : 'Movie',
                                                  if (item.year != null)
                                                    '${item.year}',
                                                ].join(' · '),
                                                style: TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 10.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (item.rating != null)
                                          Text(
                                            '★ ${item.rating!.toStringAsFixed(1)}',
                                            style: TextStyle(
                                              color: AppTheme.accentYellow,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
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

  Widget _buildGridSkeleton() {
    return GridView.builder(
      padding: EdgeInsets.all(12.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.52,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.darkBorder),
        ),
      ),
    );
  }
}
