import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/manga.dart';
import '../../services/manga_service.dart';
import '../../theme/app_theme.dart';

class MangaReaderScreen extends StatefulWidget {
  final MangaChapter chapter;
  final List<MangaChapter> chapters;
  final String mangaTitle;

  const MangaReaderScreen({super.key, required this.chapter, required this.chapters, required this.mangaTitle});

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaChapter _currentChapter;
  List<MangaPage>? _pages;
  bool _loading = true;
  String? _error;
  bool _showUI = true;
  bool _isVertical = true;
  late PageController _pageController;
  int _currentPageIndex = 0;
  final Map<int, TransformationController> _zoomControllers = {};
  bool _anyZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _pageController = PageController();
    _loadPreferences();
    _fetchPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isVertical = prefs.getBool('manga_is_vertical') ?? true;
      });
    }
  }

  Future<void> _toggleDirection() async {
    final prefs = await SharedPreferences.getInstance();
    _resetAllZoom();
    setState(() {
      _isVertical = !_isVertical;
      _currentPageIndex = 0;
    });
    await prefs.setBool('manga_is_vertical', _isVertical);
  }

  void _resetAllZoom() {
    for (final c in _zoomControllers.values) {
      c.value = Matrix4.identity();
    }
    setState(() => _anyZoomed = false);
  }

  Future<void> _fetchPages() async {
    setState(() {
      _loading = true;
      _error = null;
      _pages = null;
      _currentPageIndex = 0;
      for (final c in _zoomControllers.values) c.dispose();
      _zoomControllers.clear();
      _anyZoomed = false;
    });
    try {
      final pages = await MangaService.fetchChapterPages(_currentChapter.id);
      if (mounted) {
        setState(() {
          _pages = pages;
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

  void _nextChapter() {
    final curIdx = widget.chapters.indexOf(_currentChapter);
    if (curIdx > 0) { // Chapters are ordered desc
      _resetAllZoom();
      setState(() {
        _currentChapter = widget.chapters[curIdx - 1];
      });
      _fetchPages();
    }
  }

  void _prevChapter() {
    final curIdx = widget.chapters.indexOf(_currentChapter);
    if (curIdx < widget.chapters.length - 1) {
      _resetAllZoom();
      setState(() {
        _currentChapter = widget.chapters[curIdx + 1];
      });
      _fetchPages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showUI = !_showUI),
            child: _buildReader(),
          ),
          if (_showUI) _buildAppBar(),
          if (_showUI && _pages != null) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildReader() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null || _pages == null || _pages!.isEmpty) {
      final source = _currentChapter.id.startsWith('comick|') ? 'ComicK'
          : _currentChapter.id.startsWith('mangadex|') ? 'MangaDex'
          : 'server';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: Colors.grey, size: 48.sp),
            SizedBox(height: 16.h),
            Text(
              'Failed to load images from $source.',
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Try a different chapter or tap Retry.',
              style: TextStyle(color: Colors.grey, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            TextButton(onPressed: _fetchPages, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_isVertical) {
      return ListView.builder(
        itemCount: _pages!.length,
        cacheExtent: 3000, // Preload more for smoother scrolling
        itemBuilder: (c, i) => _buildPage(_pages![i], i),
      );
    } else {
      return PageView.builder(
        controller: _pageController,
        itemCount: _pages!.length,
        onPageChanged: (i) => setState(() => _currentPageIndex = i),
        itemBuilder: (c, i) => _buildPage(_pages![i], i),
      );
    }
  }

  Widget _buildPage(MangaPage page, int index) {
    Map<String, String>? headers;
    if (_currentChapter.id.startsWith('comick|')) {
      headers = {'Referer': 'https://comick.app/'};
    } else if (_currentChapter.id.startsWith('mangadex|')) {
      headers = {'Referer': 'https://mangadex.org/'};
    }

    final controller = _zoomControllers.putIfAbsent(index, () => TransformationController());

    return InteractiveViewer(
      transformationController: controller,
      minScale: 1.0,
      maxScale: 20.0, // Significant increase for high detail
      boundaryMargin: const EdgeInsets.all(double.infinity), // Allow free panning when zoomed
      onInteractionUpdate: (details) {
        // Detect if the user has either zoomed (scale != 1.0) or panned (translation != 0)
        final matrix = controller.value;
        final isZoomed = matrix.getMaxScaleOnAxis() > 1.0;
        final isPanned = matrix.storage[12] != 0 || matrix.storage[13] != 0;
        
        if (!_anyZoomed && (isZoomed || isPanned)) {
          setState(() => _anyZoomed = true);
        }
      },
      child: CachedNetworkImage(
        imageUrl: page.imageUrl,
        httpHeaders: headers,
        fit: _isVertical ? BoxFit.fitWidth : BoxFit.contain,
        width: double.infinity,
        alignment: Alignment.topCenter,
        progressIndicatorBuilder: (c, u, p) => Container(
          height: _isVertical ? 400.h : double.infinity,
          color: Colors.black12,
          child: Center(
            child: CircularProgressIndicator(value: p.progress, color: AppTheme.primary),
          ),
        ),
        errorWidget: (c, u, e) => Container(
          height: 400.h,
          color: AppTheme.darkCard,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppTheme.accentPink, size: 32.sp),
              SizedBox(height: 8.h),
              Text('Image Error', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              TextButton(onPressed: _fetchPages, child: const Text('Retry All')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8.h, bottom: 8.h, left: 8.w, right: 8.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.mangaTitle, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold), maxLines: 1),
                  Text('Chapter ${_currentChapter.chapterNumber}', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.zoom_out_map, color: _anyZoomed ? Colors.white : Colors.white24),
              onPressed: _anyZoomed ? _resetAllZoom : null,
              tooltip: 'Reset Zoom',
            ),
            IconButton(
              icon: Icon(_isVertical ? Icons.swap_vert : Icons.swap_horiz, color: Colors.white),
              tooltip: 'Toggle Scroll Direction',
              onPressed: _toggleDirection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final curIdx = widget.chapters.indexOf(_currentChapter);
    final hasNext = curIdx > 0;
    final hasPrev = curIdx < widget.chapters.length - 1;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8.h, top: 12.h, left: 16.w, right: 16.w),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: hasPrev ? _prevChapter : null,
              color: hasPrev ? Colors.white : Colors.white30,
            ),
            if (!_isVertical)
              Text('${_currentPageIndex + 1} / ${_pages!.length}', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: hasNext ? _nextChapter : null,
              color: hasNext ? Colors.white : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }
}
