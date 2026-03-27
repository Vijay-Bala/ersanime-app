import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/anime.dart';
import '../services/anilist_service.dart';
import '../services/watchlist_service.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';

// Platform-aware UA: iOS needs a real Safari UA — sending an Android Chrome UA
// on iOS WebKit causes VidNest to serve an ad-heavy page variant.
final String _kUserAgent = Platform.isIOS
    ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.0 Mobile/15E148 Safari/604.1'
    : 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Mobile Safari/537.36';

// Allowlist: only these hosts may trigger a top-level navigation.
// All ad redirects, trackers, and app-store links are blocked.
const _kAllowedHosts = {'vidnest.fun', 'nhdapi.xyz'};

bool _isAllowedNavigation(WebUri? uri) {
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return _kAllowedHosts.any((h) => host == h || host.endsWith('.$h'));
}

const _kAutoAdvanceDelay = Duration(seconds: 12);

class PlayerScreen extends StatefulWidget {
  final Anime anime;
  final Episode episode;
  final List<Episode> allEpisodes;

  const PlayerScreen({
    super.key,
    required this.anime,
    required this.episode,
    required this.allEpisodes,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late Episode _currentEp;
  bool _isDub = false;
  int _sourceIndex = 0;
  List<String> _sources = [];

  bool _loading = true;

  bool _autoAdvancing = false;
  int _countdown = _kAutoAdvanceDelay.inSeconds;
  Timer? _advanceTimer;
  Timer? _countdownTicker;

  bool _playerAlive = false;

  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  late Widget _webViewWidget;
  InAppWebViewController? _webCtrl;

  @override
  void initState() {
    super.initState();
    _currentEp = widget.episode;
    _buildSources();
    _webViewWidget = _buildWebView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchlistService>().markWatched(
        widget.anime.id,
        _currentEp.number,
      );
    });
  }

  void _buildSources() {
    _sources = getEmbedUrls(widget.anime.id, _currentEp.number, dub: _isDub);
    _sourceIndex = 0;
    _playerAlive = false;
  }

  String get _currentUrl => _sources[_sourceIndex];

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

  void _cancelAutoAdvance() {
    _advanceTimer?.cancel();
    _countdownTicker?.cancel();
    _advanceTimer = null;
    _countdownTicker = null;
    if (mounted) {
      setState(() {
        _autoAdvancing = false;
        _countdown = _kAutoAdvanceDelay.inSeconds;
      });
    }
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
        headers: {'Referer': 'https://vidnest.fun/'},
      ),
    );
  }

  void _playEpisode(Episode ep) {
    _cancelAutoAdvance();
    setState(() {
      _currentEp = ep;
      _loading = true;
      _playerAlive = false;
    });
    _buildSources();
    context.read<WatchlistService>().markWatched(widget.anime.id, ep.number);
    _webCtrl?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(_currentUrl),
        headers: {'Referer': 'https://vidnest.fun/'},
      ),
    );
    _webViewWidget = _buildWebView();
    setState(() {});
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
  }

  @override
  void dispose() {
    _cancelAutoAdvance();
    _controlsHideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(_currentUrl),
        headers: {'Referer': 'https://vidnest.fun/'},
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: _kUserAgent,

        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useHybridComposition: true,
        // iOS: allowing multiple windows gives ad scripts a second WebView surface.
        supportMultipleWindows: !Platform.isIOS,
        javaScriptCanOpenWindowsAutomatically: false,

        cacheEnabled: false,
        clearCache: true,
      ),

      // Block popup / new-window attempts.
      onCreateWindow: (ctrl, action) async {
        debugPrint('[AD-BLOCK] Blocked popup → ${action.request.url}');
        return false;
      },

      // Block ad redirects that navigate the main frame (window.location tricks).
      // Only vidnest.fun and nhdapi.xyz may load in the top-level frame.
      shouldOverrideUrlLoading: (ctrl, action) async {
        final isMainFrame = action.isForMainFrame;
        if (!isMainFrame) return NavigationActionPolicy.ALLOW;
        if (_isAllowedNavigation(action.request.url)) {
          return NavigationActionPolicy.ALLOW;
        }
        debugPrint('[AD-BLOCK] Blocked navigation → ${action.request.url}');
        return NavigationActionPolicy.CANCEL;
      },

      onWebViewCreated: (ctrl) => _webCtrl = ctrl,

      onLoadStart: (ctrl, url) {
        debugPrint('[PLAYER] Load start → $url');
        setState(() {
          _loading = true;
          _playerAlive = false;
        });
        _beginAutoAdvance();
      },

      onLoadStop: (ctrl, url) {
        debugPrint('[PLAYER] Load stop → $url');
        setState(() => _loading = false);

        _probeForVideo(ctrl);
      },

      onConsoleMessage: (ctrl, msg) {
        final text = msg.message.toLowerCase();
        debugPrint('[PLAYER][console] $text');

        if (text.contains('player') ||
            text.contains('hls') ||
            text.contains('video') ||
            text.contains('stream') ||
            text.contains('source') ||
            text.contains('m3u8') ||
            text.contains('jwplayer') ||
            text.contains('plyr')) {
          _onPlayerAlive();
        }
      },

      onReceivedError: (ctrl, request, error) {
        debugPrint(
          '[PLAYER] Network error on ${request.url}: ${error.description}',
        );

        if (request.isForMainFrame == true) {
          _cancelAutoAdvance();
          Future.microtask(_goNextSource);
        }
      },

      onReceivedHttpError: (ctrl, request, response) {
        debugPrint('[PLAYER] HTTP ${response.statusCode} on ${request.url}');
        if (request.isForMainFrame == true &&
            (response.statusCode ?? 200) >= 400) {
          _cancelAutoAdvance();
          Future.microtask(_goNextSource);
        }
      },
    );
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
          
          var iframes = document.querySelectorAll('iframe');
          return iframes.length > 0;
        })();
      ''',
      );
      if (result == true) {
        debugPrint(
          '[PLAYER] Video probe: found video/iframe element → player alive',
        );
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

  Widget _buildPortrait() {
    return SafeArea(
      child: Column(
        children: [
          Container(
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
                  child: Text(
                    widget.anime.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildPlayerBox(),
          _buildControls(),
          Expanded(child: _buildEpisodeGrid()),
        ],
      ),
    );
  }

  Widget _buildFullscreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: _webViewWidget),
          if (_loading || _autoAdvancing) _buildOverlay(),

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
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_exit_rounded,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Exit Fullscreen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
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
            ),
          ),

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

  Widget _buildPlayerBox() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          _webViewWidget,
          if (_loading || _autoAdvancing) _buildOverlay(),

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
                  style: TextStyle(color: AppTheme.primary, fontSize: 12.sp),
                ),
              ),
            ] else ...[
              SizedBox(
                width: 36.w,
                height: 36.h,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
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
                          color: AppTheme.primary,
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

  Widget _buildControls() {
    return Container(
      color: AppTheme.darkSurface,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.anime.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Episode ${_currentEp.number}',
                      style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
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
                          final wasDub = _isDub;
                          setState(() => _isDub = t == 'DUB');
                          if (_isDub != wasDub) {
                            _buildSources();
                            _webCtrl?.loadUrl(
                              urlRequest: URLRequest(
                                url: WebUri(_currentUrl),
                                headers: {'Referer': 'https://vidnest.fun/'},
                              ),
                            );
                            _beginAutoAdvance();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: (t == 'DUB') == _isDub
                                ? AppTheme.primary
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
              ),
            ],
          ),
          SizedBox(height: 8.h),

          SingleChildScrollView(
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
                                        : AppTheme.primary)
                                    .withOpacity(0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: i == _sourceIndex
                                ? (_playerAlive
                                      ? AppTheme.accentGreen
                                      : AppTheme.primary)
                                : AppTheme.darkBorder,
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == _sourceIndex
                                ? (_playerAlive
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryLight)
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
        ],
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
      itemCount: widget.allEpisodes.length,
      itemBuilder: (ctx, i) {
        final ep = widget.allEpisodes[i];
        final isCurrent = ep.number == _currentEp.number;
        final isWatched = watchlist.isWatched(widget.anime.id, ep.number);
        return GestureDetector(
          onTap: () => _playEpisode(ep),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
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
                color: isCurrent ? AppTheme.primary : AppTheme.darkBorder,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.5),
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
