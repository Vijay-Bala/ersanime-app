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
  // Ultra-clean verified sources 
  'vidbinge.dev',
  'vidlink.pro',
  'embed.su',
  // Regional Aggregators
  'smashy.stream', 'player.smashy.stream', 'embed.smashystream.com',
  // vidsrc proxies
  'vidsrc.xyz', 'vidsrc.net', 'vidsrc.pm', 'vidsrc.in',
  // Base vidsrc (in case of fallback)
  'vidsrc.cc', 'vidsrc.to', 'vidsrc.me', 'vidsrc.icu', 'vidsrc.mov',
};

const _kAdHosts = {
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

bool _isAdHost(String host) =>
    _kAdHosts.any((h) => host == h || host.endsWith('.$h'));

bool _isAllowedNavigation(WebUri? uri) {
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return _kAllowedHosts.any((h) => host == h || host.endsWith('.$h'));
}

const _kAutoAdvanceDelay = Duration(seconds: 12);

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

  // WebView built ONCE in initState, stored as a field
  late Widget _webViewWidget;
  InAppWebViewController? _webCtrl;

  @override
  void initState() {
    super.initState();
    _currentEp = widget.episode;
    _isDub = widget.startDubbed;
    _sources = List.from(widget.embedUrls);
    _webViewWidget = _buildWebView();
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
    if (next < _sources.length) {
      _switchSource(next);
    } else {
      setState(() {
        _autoAdvancing = false;
        _loading = false;
      });
    }
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
      ),
    );
    widget.onEpisodeChange?.call(ep);
  }

  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (_playerAlive) {
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

  // ── WebView built ONCE in initState ─────────────────────────────────────
  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(_currentUrl),
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: _kUserAgent,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: false,
        cacheEnabled: false,
        clearCache: true,
        useShouldInterceptRequest: true,
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        thirdPartyCookiesEnabled: true,
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
        debugPrint('[MEDIA] Load start → $url');
        setState(() {
          _loading = true;
          _playerAlive = false;
        });
        _beginAutoAdvance();
      },
      onLoadStop: (ctrl, url) {
        debugPrint('[MEDIA] Load stop → $url');
        setState(() => _loading = false);
        _probeForVideo(ctrl);
        _injectAdKiller(ctrl);
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
        debugPrint('[MEDIA] Error: ${error.description}');
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
          if (window._adKillerInjected) return;
          window._adKillerInjected = true;
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
          var title = document.title ? document.title.toLowerCase() : '';
          var text = document.body ? document.body.innerText.toLowerCase() : '';
          
          if (title.includes('just a moment') || 
              text.includes('checking your browser') || 
              text.includes('verify you are human')) {
            return 'cloudflare';
          }

          if (text.includes('not found') || 
              text.includes('media is not available') || 
              text.includes('check later') ||
              text.includes('404 ') ||
              text.includes('webpage not available') ||
              text.includes('no video with supported format')) {
            return 'error';
          }
          
          var vids = document.querySelectorAll('video');
          for (var v of vids) {
            if (v.src || v.currentSrc || v.querySelector('source')) return 'video';
          }
          
          var iframes = document.querySelectorAll('iframe');
          for (var i of iframes) {
             var s = i.src.toLowerCase();
             // Ignore pure ad/analytics iframes 
             if (s && !s.includes('ad') && !s.includes('google') && !s.includes('analytics') && !s.includes('pop')) {
               return 'video';
             }
          }
          return 'none';
        })();
      ''',
      );
      
      if (result == 'cloudflare') {
        debugPrint('[MEDIA] Cloudflare verification detected. Halting auto-skip timer to let user solve it.');
        _cancelAutoAdvance(updateState: true);
      } else if (result == 'error') {
        debugPrint('[MEDIA] Server reported error page natively. Skipping automatically.');
        _cancelAutoAdvance();
        Future.microtask(_goNextSource);
      } else if (result == 'video') {
        _onPlayerAlive();
      }
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
        backgroundColor: _isFullscreen ? Colors.black : AppTheme.darkBg,
        body: _isFullscreen ? _buildFullscreen() : _buildPortrait(),
      ),
    );
  }

  // ── PORTRAIT: WebView in AspectRatio — correct sizing ───────────────────
  Widget _buildPortrait() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          _buildPlayerBox(),
          _buildControls(),
          if (widget.allEpisodes != null && widget.allEpisodes!.isNotEmpty)
            Expanded(child: _buildEpisodeGrid()),
        ],
      ),
    );
  }

  // ── FULLSCREEN: WebView fills the entire screen ──────────────────────────
  Widget _buildFullscreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: _webViewWidget),
          if (_loading || _autoAdvancing) _buildOverlay(),

          // Fade-able controls
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                children: [
                  // Tap anywhere to toggle
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleControls,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Exit fullscreen (top-left)
                  Positioned(
                    top: 16.h,
                    left: 16.w,
                    child: GestureDetector(
                      onTap: _toggleFullscreen,
                      behavior: HitTestBehavior.opaque,
                      child: _iconBtn(
                        Icons.fullscreen_exit_rounded,
                        'Exit Fullscreen',
                      ),
                    ),
                  ),
                  // Title + episode info (bottom)
                  Positioned(
                    bottom: 20.h,
                    left: 16.w,
                    right: 16.w,
                    child: _buildFullscreenInfo(),
                  ),
                ],
              ),
            ),
          ),

          // Touch hint when controls are hidden
          if (!_controlsVisible && !_loading && !_autoAdvancing)
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
                  child: Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white38,
                    size: 16.sp,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Portrait video player box: WebView in a 16:9 AspectRatio
  Widget _buildPlayerBox() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          _webViewWidget,
          if (_loading || _autoAdvancing) _buildOverlay(),
          // Fullscreen button
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: _toggleFullscreen,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.all(8.w),
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
                    SizedBox(width: 4.w),
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
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label) {
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
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenInfo() {
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

  Widget _buildSubDubToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.darkBorder),
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
                  color: (t == 'DUB') == _isDub
                      ? AppTheme.accentOrange
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7.r),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: (t == 'DUB') == _isDub
                        ? Colors.white
                        : AppTheme.textSecondary,
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
