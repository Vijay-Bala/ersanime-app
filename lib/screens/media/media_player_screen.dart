import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../services/tmdb_service.dart';
import '../../services/watchlist_service.dart';
import '../../theme/app_theme.dart';

final String _kUserAgent = Platform.isIOS
    ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
    : 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const _kAllowedHosts = {
  'vidsrc.cc',
  'vidsrc.to',
  'vidsrc.me',
  'vidsrc.icu',
  'vidsrc.mov',
  'embed.su',
  'multiembed.mov',
  'vidlink.pro',
  '2embed.stream',
  'www.2embed.stream',
};

const _kAdHosts = {
  'adexchangeclear.com',
  'usrpubtrk.com',
  'acscdn.com',
  'ieenhijxbigyt.space',
  'cloudnestra.com',
  'vsembed.ru',
  'doubleclick.net',
  'googlesyndication.com',
  'googletagmanager.com',
  'googletagservices.com',
  'google-analytics.com',
  'adservice.google.com',
  'amazon-adsystem.com',
  'outbrain.com',
  'taboola.com',
  'popads.net',
  'popcash.net',
  'propellerads.com',
  'adsterra.com',
  'trafficjunky.com',
  'exoclick.com',
  'juicyads.com',
  'trafficfactory.biz',
  'hilltopads.net',
  'ero-advertising.com',
  'adnxs.com',
  'advertising.com',
  'criteo.com',
  'rubiconproject.com',
  'openx.net',
  'pubmatic.com',
  'smartadserver.com',
  'imasdk.googleapis.com',
  'disable-devtool',
};

bool _isAdHost(String host) =>
    _kAdHosts.any((h) => host == h || host.endsWith('.$h'));

bool _isAllowedNavigation(WebUri? uri) {
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return _kAllowedHosts.any((h) => host == h || host.endsWith('.$h'));
}

const _kAutoAdvanceDelay = Duration(seconds: 12);

// Video fit modes for zoom controls
enum _VideoFit { contain, cover, fill }

class MediaPlayerScreen extends StatefulWidget {
  final MediaItem item;
  final List<String> embedUrls;
  final int? season;
  final TvEpisode? episode;
  final List<TvEpisode>? allEpisodes;
  final ValueChanged<TvEpisode>? onEpisodeChange;
  final bool startDubbed;

  const MediaPlayerScreen({
    super.key,
    required this.item,
    required this.embedUrls,
    this.season,
    this.episode,
    this.allEpisodes,
    this.onEpisodeChange,
    this.startDubbed = false,
  });

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  late TvEpisode? _currentEp;
  late List<String> _sources;
  int _sourceIndex = 0;
  bool _isDub = false;
  bool _loading = true;
  bool _autoAdvancing = false;
  int _countdown = _kAutoAdvanceDelay.inSeconds;
  Timer? _advanceTimer;
  Timer? _countdownTicker;
  bool _playerAlive = false;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  // ── KEY FIX: WebView controller kept alive — never rebuilt on fullscreen ──
  InAppWebViewController? _webCtrl;
  // Track current URL independently so we can reload if needed

  // Zoom / fit
  _VideoFit _videoFit = _VideoFit.contain;

  @override
  void initState() {
    super.initState();
    _currentEp = widget.episode;
    _isDub = widget.startDubbed;
    _sources = List.from(widget.embedUrls);
  }

  String get _currentUrl => _sources[_sourceIndex];

  void _rebuildSources({bool dubbed = false}) {
    if (widget.season != null && _currentEp != null) {
      _sources = getTvEmbedUrls(
        widget.item.id,
        widget.season!,
        _currentEp!.number,
        dubbed: dubbed,
      );
    } else {
      _sources = getMovieEmbedUrls(widget.item.id, dubbed: dubbed);
    }
    _sourceIndex = 0;
    _playerAlive = false;
  }

  void _beginAutoAdvance() {
    _cancelAutoAdvance();
    if (_playerAlive) return;
    setState(() {
      _autoAdvancing = true;
      _countdown = _kAutoAdvanceDelay.inSeconds;
    });
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(
        () => _countdown = (_countdown - 1).clamp(
          0,
          _kAutoAdvanceDelay.inSeconds,
        ),
      );
    });
    _advanceTimer = Timer(_kAutoAdvanceDelay, () {
      if (!mounted || _playerAlive) return;
      _goNextSource();
    });
  }

  void _cancelAutoAdvance({bool updateState = true}) {
    _advanceTimer?.cancel();
    _countdownTicker?.cancel();
    _advanceTimer = _countdownTicker = null;
    _autoAdvancing = false;
    _countdown = _kAutoAdvanceDelay.inSeconds;
    if (updateState && mounted) setState(() {});
  }

  void _onPlayerAlive() {
    if (_playerAlive) return;
    _playerAlive = true;
    _cancelAutoAdvance();
    if (mounted) {
      setState(() => _loading = false);
      _showControls();
    }
  }

  void _goNextSource() {
    if (!mounted) return;
    final next = _sourceIndex + 1;
    if (next < _sources.length)
      _switchSource(next);
    else
      setState(() {
        _autoAdvancing = false;
        _loading = false;
      });
  }

  void _switchSource(int i) {
    if (i >= _sources.length || i < 0) return;
    setState(() {
      _sourceIndex = i;
      _loading = true;
      _playerAlive = false;
    });
    _cancelAutoAdvance();
    _webCtrl?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(_sources[i]),
        headers: {'Referer': 'https://vidsrc.cc/'},
      ),
    );
  }

  void _playEpisode(TvEpisode ep) {
    _cancelAutoAdvance();
    setState(() {
      _currentEp = ep;
      _loading = true;
      _playerAlive = false;
      _sourceIndex = 0;
    });
    _rebuildSources(dubbed: _isDub);
    context.read<WatchlistService>().markMediaWatched(
      widget.item.id,
      season: widget.season!,
      episode: ep.number,
    );
    _webCtrl?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(_currentUrl),
        headers: {'Referer': 'https://vidsrc.cc/'},
      ),
    );
    widget.onEpisodeChange?.call(ep);
  }

  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (_playerAlive) {
      _controlsHideTimer = Timer(const Duration(seconds: 4), () {
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
    // ── KEY FIX: only change orientation/UI mode, never rebuild WebView ──
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
    // Re-show controls briefly after switching
    _showControls();
  }

  void _cycleVideoFit() {
    final next =
        _VideoFit.values[(_videoFit.index + 1) % _VideoFit.values.length];
    setState(() => _videoFit = next);
    _applyVideoFit(next);
  }

  Future<void> _applyVideoFit(_VideoFit fit) async {
    final css = switch (fit) {
      _VideoFit.contain => 'contain',
      _VideoFit.cover => 'cover',
      _VideoFit.fill => 'fill',
    };
    try {
      await _webCtrl?.evaluateJavascript(
        source:
            '''
        (function() {
          document.querySelectorAll('video').forEach(function(v) {
            v.style.objectFit = '$css';
            v.style.width = '100%';
            v.style.height = '100%';
          });
        })();
      ''',
      );
    } catch (_) {}
  }

  IconData get _fitIcon => switch (_videoFit) {
    _VideoFit.contain => Icons.fit_screen_rounded,
    _VideoFit.cover => Icons.crop_rounded,
    _VideoFit.fill => Icons.fullscreen_rounded,
  };

  String get _fitLabel => switch (_videoFit) {
    _VideoFit.contain => 'Fit',
    _VideoFit.cover => 'Crop',
    _VideoFit.fill => 'Fill',
  };

  @override
  void dispose() {
    _cancelAutoAdvance(updateState: false);
    _controlsHideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── The WebView — built ONCE, never recreated ────────────────────────────
  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(_currentUrl),
        headers: {'Referer': 'https://vidsrc.cc/'},
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: _kUserAgent,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useHybridComposition: true,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
        cacheEnabled: false,
        clearCache: true,
        useShouldInterceptRequest: true,
        // Allow pinch-to-zoom inside the WebView
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
      ),
      shouldInterceptRequest: (ctrl, request) async {
        final host = request.url.host.toLowerCase();
        if (_isAdHost(host))
          return WebResourceResponse(statusCode: 200, data: Uint8List(0));
        return null;
      },
      onCreateWindow: (ctrl, action) async => false,
      shouldOverrideUrlLoading: (ctrl, action) async {
        if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
        final host = action.request.url?.host.toLowerCase() ?? '';
        if (_isAdHost(host)) return NavigationActionPolicy.CANCEL;
        if (_isAllowedNavigation(action.request.url))
          return NavigationActionPolicy.ALLOW;
        return NavigationActionPolicy.CANCEL;
      },
      onWebViewCreated: (ctrl) => _webCtrl = ctrl,
      onLoadStart: (ctrl, url) {
        setState(() {
          _loading = true;
          _playerAlive = false;
        });
        _beginAutoAdvance();
      },
      onLoadStop: (ctrl, url) {
        setState(() => _loading = false);
        _probeForVideo(ctrl);
        _injectAdKiller(ctrl);
        // Re-apply fit when new page loads
        _applyVideoFit(_videoFit);
      },
      onConsoleMessage: (ctrl, msg) {
        final text = msg.message.toLowerCase();
        if (text.contains('player') ||
            text.contains('hls') ||
            text.contains('video') ||
            text.contains('stream') ||
            text.contains('m3u8') ||
            text.contains('jwplayer') ||
            text.contains('plyr') ||
            text.contains('source')) {
          _onPlayerAlive();
        }
      },
      onReceivedError: (ctrl, request, error) {
        if (request.isForMainFrame == true) {
          _cancelAutoAdvance();
          Future.microtask(_goNextSource);
        }
      },
      onReceivedHttpError: (ctrl, request, response) {
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 200) >= 400) {
          _cancelAutoAdvance();
          Future.microtask(_goNextSource);
        }
      },
    );
  }

  Future<void> _injectAdKiller(InAppWebViewController ctrl) async {
    try {
      await ctrl.evaluateJavascript(
        source: r'''
        (function() {
          window.open = function() { return null; };
          window.alert = function() {};
          window.confirm = function() { return false; };
          Object.defineProperty(window, 'onbeforeunload', {
            set: function(){}, get: function(){ return null; }
          });
          var sels = [
            '.vidlink-logo','.vidlink-branding','#vidlink-logo',
            'a[href*="vidlink.pro"]','div[class*="logo"]',
            'div[class*="brand"]','div[class*="watermark"]',
            'iframe[src*="popads"]','iframe[src*="popcash"]',
            'iframe[src*="adsterra"]','iframe[src*="exoclick"]',
            'iframe[src*="adexchangeclear"]','iframe[src*="usrpubtrk"]',
            'div[id*="ad-"]','div[class*="ad-"]',
            '.overlay-ad','#overlay-ad','#ad-overlay','.ad-overlay',
            '[data-ad]','[data-advertisement]',
            'div[style*="position:fixed"]','div[style*="position: fixed"]'
          ];
          function clean() {
            sels.forEach(function(sel) {
              document.querySelectorAll(sel).forEach(function(el) {
                if (!el.querySelector('video')) {
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

  Future<void> _probeForVideo(InAppWebViewController ctrl) async {
    try {
      final result = await ctrl.evaluateJavascript(
        source: '''
        (function() {
          var vids = document.querySelectorAll('video');
          for (var v of vids) {
            if (v.src || v.currentSrc || v.querySelector('source')) return true;
          }
          return document.querySelectorAll('iframe').length > 0;
        })();
      ''',
      );
      if (result == true) _onPlayerAlive();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // ── KEY FIX: WebView is built ONCE here at the root, never moves ──
        // We use a Stack: WebView always fills, UI layers switch on top.
        body: Stack(
          children: [
            // WebView always full-screen in the stack — never rebuilt
            Positioned.fill(child: _buildWebView()),
            // Portrait UI layer (hidden in fullscreen)
            if (!_isFullscreen)
              Positioned.fill(child: _buildPortraitOverlayUI()),
            // Fullscreen UI layer
            if (_isFullscreen)
              Positioned.fill(child: _buildFullscreenOverlayUI()),
            // Loading/advance overlay — shown in both modes
            if (_loading || _autoAdvancing)
              Positioned.fill(child: _buildOverlay()),
          ],
        ),
      ),
    );
  }

  // ── FULLSCREEN UI: controls float on top of the always-present WebView ──
  Widget _buildFullscreenOverlayUI() {
    return _buildFullscreenControls();
  }

  // ── PORTRAIT UI: black bars + controls below the 16:9 video area ─────────
  Widget _buildPortraitOverlayUI() {
    // We need to clip/constrain the WebView to 16:9 and show controls below.
    // The WebView already fills the whole Stack — we cover the non-video areas.
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          // Transparent 16:9 window — lets WebView show through
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(children: [_buildPortraitVideoControls()]),
          ),
          // Cover the rest with dark UI
          Expanded(
            child: Container(
              color: AppTheme.darkBg,
              child: Column(
                children: [
                  _buildControls(),
                  if (widget.allEpisodes != null &&
                      widget.allEpisodes!.isNotEmpty)
                    Expanded(child: _buildEpisodeGrid()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppTheme.darkBg,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary,
              size: 18.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_currentEp != null)
                  Text(
                    'S${widget.season} E${_currentEp!.number}: ${_currentEp!.name}',
                    style: TextStyle(
                      color: AppTheme.accentOrange,
                      fontSize: 10.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Portrait video overlay buttons (fullscreen + fit)
  Widget _buildPortraitVideoControls() {
    return Positioned(
      bottom: 8.h,
      right: 8.w,
      child: Row(
        children: [
          GestureDetector(
            onTap: _cycleVideoFit,
            child: Container(
              padding: EdgeInsets.all(6.w),
              margin: EdgeInsets.only(right: 6.w),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_fitIcon, color: Colors.white, size: 16.sp),
                  SizedBox(width: 3.w),
                  Text(
                    _fitLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Fullscreen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fullscreen controls: tap anywhere to toggle, back + fit buttons always visible
  Widget _buildFullscreenControls() {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Always-visible: back button (top-left) + fit button (top-right)
          Positioned(
            top: 16.h,
            left: 16.w,
            child: GestureDetector(
              onTap: _toggleFullscreen,
              child: _iconBtn(Icons.arrow_back_ios_new_rounded, 'Exit'),
            ),
          ),
          Positioned(
            top: 16.h,
            right: 16.w,
            child: GestureDetector(
              onTap: _cycleVideoFit,
              child: _iconBtn(_fitIcon, _fitLabel),
            ),
          ),
          // Fade-in controls when tapped
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Positioned(
                bottom: 20.h,
                left: 0,
                right: 0,
                child: _buildFullscreenBottomBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenBottomBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (_currentEp != null) ...[
            SizedBox(height: 2.h),
            Text(
              'S${widget.season} E${_currentEp!.number}: ${_currentEp!.name}',
              style: TextStyle(color: AppTheme.accentOrange, fontSize: 10.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 10.h),
          // Server row + SUB/DUB
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Servers:',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      for (int i = 0; i < _sources.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: GestureDetector(
                            onTap: () => _switchSource(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: i == _sourceIndex
                                    ? (_playerAlive
                                              ? AppTheme.accentGreen
                                              : AppTheme.accentOrange)
                                          .withOpacity(0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: i == _sourceIndex
                                      ? (_playerAlive
                                            ? AppTheme.accentGreen
                                            : AppTheme.accentOrange)
                                      : Colors.white30,
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == _sourceIndex
                                      ? (_playerAlive
                                            ? AppTheme.accentGreen
                                            : AppTheme.accentOrange)
                                      : Colors.white60,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _buildSubDubToggle(dark: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: AppTheme.darkSurface,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Servers:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  for (int i = 0; i < _sources.length; i++)
                    Padding(
                      padding: EdgeInsets.only(right: 4.w),
                      child: GestureDetector(
                        onTap: () => _switchSource(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: i == _sourceIndex
                                ? (_playerAlive
                                          ? AppTheme.accentGreen
                                          : AppTheme.accentOrange)
                                      .withOpacity(0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: i == _sourceIndex
                                  ? (_playerAlive
                                        ? AppTheme.accentGreen
                                        : AppTheme.accentOrange)
                                  : AppTheme.darkBorder,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == _sourceIndex
                                  ? (_playerAlive
                                        ? AppTheme.accentGreen
                                        : AppTheme.accentOrange)
                                  : AppTheme.textSecondary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          _buildSubDubToggle(),
        ],
      ),
    );
  }

  Widget _buildSubDubToggle({bool dark = false}) {
    final activeBg = dark ? AppTheme.accentOrange : AppTheme.accentOrange;
    final inactiveBg = dark ? Colors.transparent : Colors.transparent;
    final inactiveBorder = dark ? Colors.white30 : AppTheme.darkBorder;
    final cardBg = dark ? Colors.white12 : AppTheme.darkCard;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: inactiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in ['SUB', 'DUB'])
            GestureDetector(
              onTap: () {
                final newDub = t == 'DUB';
                if (newDub == _isDub) return;
                setState(() {
                  _isDub = newDub;
                  _loading = true;
                  _playerAlive = false;
                });
                _rebuildSources(dubbed: newDub);
                _webCtrl?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(_currentUrl),
                    headers: {'Referer': 'https://vidsrc.cc/'},
                  ),
                );
                _beginAutoAdvance();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (t == 'DUB') == _isDub ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(7.r),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: (t == 'DUB') == _isDub
                        ? Colors.white
                        : (dark ? Colors.white60 : AppTheme.textSecondary),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final exhausted =
        !_autoAdvancing && !_loading && _sourceIndex >= _sources.length - 1;
    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exhausted) ...[
              Icon(
                Icons.error_outline_rounded,
                color: AppTheme.accentPink,
                size: 40.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                'No working server found',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Try again later',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 14.h),
              TextButton(
                onPressed: () => _switchSource(0),
                child: Text(
                  'Retry from server 1',
                  style: TextStyle(
                    color: AppTheme.accentOrange,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: 36.w,
                height: 36.h,
                child: CircularProgressIndicator(
                  color: AppTheme.accentOrange,
                  strokeWidth: 3,
                  value: _autoAdvancing
                      ? 1 - (_countdown / _kAutoAdvanceDelay.inSeconds)
                      : null,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                _loading && !_autoAdvancing
                    ? 'Loading server ${_sourceIndex + 1} of ${_sources.length}...'
                    : 'Server ${_sourceIndex + 1} not responding...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              if (_autoAdvancing) ...[
                SizedBox(height: 6.h),
                Text(
                  'Trying next in ${_countdown}s',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _goNextSource,
                      child: Text(
                        'Skip now',
                        style: TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: _cancelAutoAdvance,
                      child: Text(
                        'Stay here',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeGrid() {
    final watchlist = context.watch<WatchlistService>();
    return GridView.builder(
      padding: EdgeInsets.all(10.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1.1,
        crossAxisSpacing: 6.w,
        mainAxisSpacing: 6.h,
      ),
      itemCount: widget.allEpisodes!.length,
      itemBuilder: (ctx, i) {
        final ep = widget.allEpisodes![i];
        final isCurrent = _currentEp?.number == ep.number;
        final isWatched = watchlist.isMediaWatched(
          widget.item.id,
          season: widget.season!,
          episode: ep.number,
        );
        return GestureDetector(
          onTap: () => _playEpisode(ep),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? const LinearGradient(
                      colors: [AppTheme.accentOrange, Color(0xFFCC4A00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isCurrent
                  ? null
                  : isWatched
                  ? AppTheme.darkCardElev
                  : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isCurrent ? AppTheme.accentOrange : AppTheme.darkBorder,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppTheme.accentOrange.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '${ep.number}',
                style: TextStyle(
                  color: isCurrent
                      ? Colors.white
                      : isWatched
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
