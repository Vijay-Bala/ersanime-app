import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/manga.dart';
import '../../services/manga_service.dart';
import '../../theme/app_theme.dart';

// ── Ad-blocking configuration (mirrors the anime/media player approach) ───────

final String _kMangaUserAgent = Platform.isIOS
    ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.0 Mobile/15E148 Safari/604.1'
    : 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Mobile Safari/537.36';

/// Hosts that are explicitly ALLOWED for external manga reading.
/// MangaPlus and Viz are the two primary hosts for external chapters.
const _kMangaAllowedHosts = {
  'mangaplus.shueisha.com',
  'mangaplus.shueisha.co.jp',
  'jump.shueisha.com',
  'viz.com',
  'www.viz.com',
  'shonenjump.com',
  'www.shonenjump.com',
};

/// Ad/tracker network blocklist — same comprehensive list as anime player.
const _kMangaAdHosts = {
  'adexchangeclear.com', 'usrpubtrk.com', 'acscdn.com',
  'ieenhijxbigyt.space', 'cloudnestra.com', 'vsembed.ru',
  'doubleclick.net', 'googlesyndication.com', 'googletagmanager.com',
  'googletagservices.com', 'google-analytics.com', 'adservice.google.com',
  'amazon-adsystem.com', 'outbrain.com', 'taboola.com',
  'popads.net', 'popcash.net', 'propellerads.com', 'adsterra.com',
  'trafficjunky.com', 'exoclick.com', 'juicyads.com',
  'trafficfactory.biz', 'hilltopads.net', 'ero-advertising.com',
  'adnxs.com', 'advertising.com', 'criteo.com', 'rubiconproject.com',
  'openx.net', 'pubmatic.com', 'smartadserver.com', 'imasdk.googleapis.com',
  'disable-devtool',
};

bool _isMangaAdHost(String host) =>
    _kMangaAdHosts.any((h) => host == h || host.endsWith('.$h'));

bool _isMangaAllowedNavigation(WebUri? uri) {
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return _kMangaAllowedHosts.any((h) => host == h || host.endsWith('.$h'));
}

// ─────────────────────────────────────────────────────────────────────────────

class MangaReaderScreen extends StatefulWidget {
  final MangaChapter chapter;
  final List<MangaChapter> chapters;
  final String mangaTitle;

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.chapters,
    required this.mangaTitle,
  });

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

  // ── External chapter (MangaPlus / Viz) WebView state ─────────────────────
  bool _isExternalChapter = false;
  String? _externalUrl;
  bool _webLoading = true;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;
  // Built ONCE in _openExternalReader, stored as a field
  Widget? _webViewWidget;

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
    _controlsHideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    // Check if this is an external chapter (MangaPlus / Viz)
    if (MangaService.isExternalChapter(_currentChapter.id)) {
      final url = MangaService.getExternalUrl(_currentChapter.id);
      if (mounted) {
        setState(() {
          _isExternalChapter = true;
          _externalUrl = url;
          _loading = false;
          _error = null;
          _pages = null;
          _currentPageIndex = 0;
          _webLoading = true;
          _isFullscreen = false;
          _controlsVisible = true;
        });
        _webViewWidget = _buildWebView(url ?? '');
      }
      return;
    }

    // Native chapter
    setState(() {
      _isExternalChapter = false;
      _externalUrl = null;
      _webViewWidget = null;
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
    if (curIdx > 0) {
      _resetAllZoom();
      setState(() => _currentChapter = widget.chapters[curIdx - 1]);
      _fetchPages();
    }
  }

  void _prevChapter() {
    final curIdx = widget.chapters.indexOf(_currentChapter);
    if (curIdx < widget.chapters.length - 1) {
      _resetAllZoom();
      setState(() => _currentChapter = widget.chapters[curIdx + 1]);
      _fetchPages();
    }
  }

  // ── Fullscreen / controls (for WebView external reader) ──────────────────

  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (!_webLoading) {
      _controlsHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => _isFullscreen = !_isFullscreen);
    _showControls();
  }

  // ── Build the ad-killed WebView for external chapters ────────────────────

  Widget _buildWebView(String url) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: _kMangaUserAgent,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: true,
        cacheEnabled: true,
        useShouldInterceptRequest: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        thirdPartyCookiesEnabled: true,
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
      ),
      // ── Network-level ad blocking ──────────────────────────────────────
      shouldInterceptRequest: (ctrl, request) async {
        final host = request.url.host.toLowerCase();
        if (_isMangaAdHost(host)) {
          return WebResourceResponse(statusCode: 200, data: Uint8List(0));
        }
        return null;
      },
      // ── Navigation whitelist ───────────────────────────────────────────
      onCreateWindow: (ctrl, action) async => false,
      shouldOverrideUrlLoading: (ctrl, action) async {
        if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
        final host = action.request.url?.host.toLowerCase() ?? '';
        if (_isMangaAdHost(host)) return NavigationActionPolicy.CANCEL;
        if (_isMangaAllowedNavigation(action.request.url)) {
          return NavigationActionPolicy.ALLOW;
        }
        return NavigationActionPolicy.CANCEL;
      },
      onWebViewCreated: (ctrl) {},
      onLoadStart: (ctrl, url) {
        debugPrint('[MANGA-EXT] Load start → $url');
        if (mounted) setState(() => _webLoading = true);
      },
      onLoadStop: (ctrl, url) {
        debugPrint('[MANGA-EXT] Load stop → $url');
        if (mounted) setState(() => _webLoading = false);
        _injectMangaAdKiller(ctrl);
        _showControls();
      },
      onReceivedError: (ctrl, request, error) {
        debugPrint('[MANGA-EXT] Error: ${error.description}');
        if (mounted) setState(() => _webLoading = false);
      },
      onReceivedHttpError: (ctrl, request, response) {
        debugPrint('[MANGA-EXT] HTTP ${response.statusCode}');
        if (mounted) setState(() => _webLoading = false);
      },
    );
  }

  /// Injects the same ad-killer JavaScript used in the anime/media players.
  /// Additionally hides MangaPlus-specific overlays that block reading.
  Future<void> _injectMangaAdKiller(InAppWebViewController ctrl) async {
    try {
      await ctrl.evaluateJavascript(
        source: r'''
        (function() {
          if (window._adKillerInjected) return;
          window._adKillerInjected = true;
          window.open = function() { return null; };
          window.alert = function() {};
          window.confirm = function() { return false; };
          Object.defineProperty(window, 'onbeforeunload', {
            set: function(){}, get: function(){ return null; }
          });
          var sels = [
            'iframe[src*="popads"]', 'iframe[src*="popcash"]',
            'iframe[src*="adsterra"]', 'iframe[src*="exoclick"]',
            'iframe[src*="adexchangeclear"]', 'iframe[src*="usrpubtrk"]',
            'div[id*="ad-"]', 'div[class*="ad-"]',
            '.overlay-ad', '#overlay-ad', '#ad-overlay', '.ad-overlay',
            '[data-ad]', '[data-advertisement]',
            'div[style*="position:fixed"]', 'div[style*="position: fixed"]',
            '.app-download-banner', '.modal-overlay',
            '#cookie-banner', '.cookie-banner', '.gdpr-banner',
            '.age-gate', '#age-gate',
          ];
          function clean() {
            sels.forEach(function(sel) {
              document.querySelectorAll(sel).forEach(function(el) {
                if (!el.querySelector('img[src*="manga"], canvas, img:not([width="1"])')) {
                  var p = el.parentNode; if (p) p.removeChild(el);
                }
              });
            });
          }
          clean();
          new MutationObserver(clean).observe(
            document.body || document.documentElement,
            { childList: true, subtree: true }
          );
        })();
        ''',
      );
    } catch (_) {}
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isExternalChapter) {
      return _buildExternalReader();
    }
    return _buildNativeReader();
  }

  // ── NATIVE READER (CachedNetworkImage pages) ────────────────────────────

  Widget _buildNativeReader() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showUI = !_showUI),
            child: _buildReaderContent(),
          ),
          if (_showUI) _buildAppBar(),
          if (_showUI && _pages != null && _pages!.isNotEmpty)
            _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildReaderContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null || _pages == null || _pages!.isEmpty) {
      final source = _currentChapter.id.startsWith('mangadex|')
          ? 'MangaDex'
          : _currentChapter.id.startsWith('manganato|')
          ? 'Manganato'
          : _currentChapter.id.startsWith('kakalot|')
          ? 'Mangakakalot'
          : _currentChapter.id.startsWith('mangapark|')
          ? 'MangaPark'
          : 'the server';

      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded,
                  color: Colors.grey.shade600, size: 52.sp),
              SizedBox(height: 16.h),
              Text(
                'Could not load chapter from $source',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'The source may be temporarily unavailable.\nTry again or switch to a different chapter.',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 12.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _fetchPages,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isVertical) {
      return ListView.builder(
        itemCount: _pages!.length,
        cacheExtent: 3000,
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
    // Set correct Referer header per source
    Map<String, String>? headers;
    if (_currentChapter.id.startsWith('mangapill|')) {
      headers = {
        'Referer': 'https://mangapill.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (_currentChapter.id.startsWith('mangadex|')) {
      headers = {'Referer': 'https://mangadex.org/'};
    }

    final controller = _zoomControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );

    return InteractiveViewer(
      transformationController: controller,
      minScale: 1.0,
      maxScale: 20.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      onInteractionUpdate: (details) {
        final matrix = controller.value;
        final isZoomed = matrix.getMaxScaleOnAxis() > 1.0;
        final isPanned =
            matrix.storage[12].abs() > 0.1 || matrix.storage[13].abs() > 0.1;
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
            child: CircularProgressIndicator(
              value: p.progress,
              color: AppTheme.primary,
            ),
          ),
        ),
        errorWidget: (c, u, e) => Container(
          height: 400.h,
          color: AppTheme.darkCard,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: AppTheme.accentPink, size: 32.sp),
              SizedBox(height: 8.h),
              Text('Image failed to load',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 12.sp)),
              if (_anyZoomed)
                Text('Try resetting zoom/pan',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 10.sp)),
              TextButton(
                  onPressed: _fetchPages,
                  child: const Text('Retry all')),
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
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8.h,
          bottom: 8.h,
          left: 8.w,
          right: 8.w,
        ),
        decoration: const BoxDecoration(
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
                  Text(
                    widget.mangaTitle,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        'Chapter ${_currentChapter.chapterNumber}',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11.sp),
                      ),
                      if (_currentChapter.group != null) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: _sourceColor(
                                    _currentChapter.group!)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                                color: _sourceColor(
                                    _currentChapter.group!),
                                width: 0.8),
                          ),
                          child: Text(
                            _currentChapter.group!,
                            style: TextStyle(
                                color: _sourceColor(
                                    _currentChapter.group!),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.zoom_out_map,
                  color: _anyZoomed ? Colors.white : Colors.white24),
              onPressed: _anyZoomed ? _resetAllZoom : null,
              tooltip: 'Reset Zoom & Pan',
            ),
            IconButton(
              icon: Icon(
                  _isVertical ? Icons.swap_vert : Icons.swap_horiz,
                  color: Colors.white),
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8.h,
          top: 12.h,
          left: 16.w,
          right: 16.w,
        ),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withOpacity(0.95),
          border: const Border(top: BorderSide(color: Colors.white10)),
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
              Text(
                '${_currentPageIndex + 1} / ${_pages!.length}',
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
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

  // ── EXTERNAL READER (InAppWebView with full ad blocking) ─────────────────

  Widget _buildExternalReader() {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor:
            _isFullscreen ? Colors.black : AppTheme.darkBg,
        body: _isFullscreen
            ? _buildExternalFullscreen()
            : _buildExternalPortrait(),
      ),
    );
  }

  Widget _buildExternalPortrait() {
    return SafeArea(
      child: Column(
        children: [
          _buildExternalTopBar(),
          _buildExternalInfoCard(),
          Expanded(child: _buildExternalWebContent()),
          _buildExternalBottomBar(),
        ],
      ),
    );
  }

  Widget _buildExternalTopBar() {
    final curIdx = widget.chapters.indexOf(_currentChapter);
    final hasNext = curIdx > 0;
    final hasPrev = curIdx < widget.chapters.length - 1;

    return Container(
      color: AppTheme.darkBg,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 18.sp),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mangaTitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  'Chapter ${_currentChapter.chapterNumber} · External',
                  style: TextStyle(
                      color: AppTheme.accentCyan, fontSize: 10.sp),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.skip_previous_rounded,
                color: hasPrev ? Colors.white : Colors.white30,
                size: 20.sp),
            onPressed: hasPrev ? _prevChapter : null,
          ),
          IconButton(
            icon: Icon(Icons.skip_next_rounded,
                color: hasNext ? Colors.white : Colors.white30,
                size: 20.sp),
            onPressed: hasNext ? _nextChapter : null,
          ),
        ],
      ),
    );
  }

  Widget _buildExternalInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.15),
            AppTheme.primaryDark.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.open_in_browser_rounded,
              color: AppTheme.primary, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'This chapter is exclusively hosted by the publisher. '
              'Reading in a protected, ad-free view.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalWebContent() {
    if (_externalUrl == null || _externalUrl!.isEmpty) {
      return Center(
        child: Text(
          'External URL not available.',
          style: TextStyle(color: Colors.grey, fontSize: 13.sp),
        ),
      );
    }

    return Stack(
      children: [
        _webViewWidget!,
        if (_webLoading)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 14.h),
                  Text(
                    'Loading publisher reader...',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Ads & popups are being blocked',
                    style: TextStyle(
                        color: AppTheme.accentCyan.withOpacity(0.7),
                        fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          ),
        // Fullscreen button (bottom-right)
        if (!_webLoading)
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: _toggleFullscreen,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 16.sp),
                    SizedBox(width: 4.w),
                    Text('Fullscreen',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExternalBottomBar() {
    return Container(
      color: AppTheme.darkSurface,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded,
              color: AppTheme.accentGreen, size: 14.sp),
          SizedBox(width: 6.w),
          Text(
            'Ad-blocked · No popups · No redirections',
            style: TextStyle(
                color: AppTheme.accentGreen.withOpacity(0.8),
                fontSize: 10.sp,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalFullscreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: _webViewWidget!),
          if (_webLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleControls,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    top: 16.h,
                    left: 16.w,
                    child: GestureDetector(
                      onTap: _toggleFullscreen,
                      behavior: HitTestBehavior.opaque,
                      child: _fsBtn(
                          Icons.fullscreen_exit_rounded, 'Exit Fullscreen'),
                    ),
                  ),
                  Positioned(
                    bottom: 20.h,
                    left: 16.w,
                    right: 16.w,
                    child: _buildFsInfo(),
                  ),
                ],
              ),
            ),
          ),
          if (!_controlsVisible && !_webLoading)
            Positioned(
              top: 12.h,
              left: 12.w,
              child: GestureDetector(
                onTap: _showControls,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(Icons.touch_app_rounded,
                      color: Colors.white38, size: 16.sp),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fsBtn(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18.sp),
          SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFsInfo() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mangaTitle,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Chapter ${_currentChapter.chapterNumber} · External',
            style: TextStyle(color: AppTheme.accentCyan, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  // ── Source badge color ────────────────────────────────────────────────────

  Color _sourceColor(String group) {
    switch (group.toLowerCase()) {
      case 'mangadex':
      case 'mangadex (external)':
        return const Color(0xFFFF6740);
      case 'manganato':
        return const Color(0xFF4CAF50);
      case 'mangakakalot':
        return const Color(0xFF2196F3);
      case 'mangapark':
        return const Color(0xFFAB47BC);
      default:
        return Colors.grey;
    }
  }
}
