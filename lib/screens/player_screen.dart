import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/anime.dart';
import '../services/anilist_service.dart';
import '../services/watchlist_service.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';

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
  InAppWebViewController? _webCtrl;
  bool _isFullscreen = false;
  int _countdown = 8;
  bool _autoAdvancing = false;

  @override
  void initState() {
    super.initState();
    _currentEp = widget.episode;
    _buildSources();
    // Mark as watched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchlistService>().markWatched(widget.anime.id, _currentEp.number);
    });
  }

  void _buildSources() {
    _sources = getEmbedUrls(widget.anime.id, _currentEp.number, dub: _isDub);
    _sourceIndex = 0;
  }

  String get _currentUrl => _sources[_sourceIndex];

  void _switchSource(int i) {
    if (i >= _sources.length) return;
    setState(() { _sourceIndex = i; _loading = true; _autoAdvancing = false; _countdown = 8; });
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentUrl)));
  }

  void _startAutoAdvance() {
    if (_autoAdvancing) return;
    setState(() { _autoAdvancing = true; _countdown = 8; });
    _tick();
  }

  void _tick() {
    if (!mounted || !_autoAdvancing) return;
    if (_countdown <= 0) {
      if (_sourceIndex < _sources.length - 1) {
        _switchSource(_sourceIndex + 1);
      } else {
        setState(() { _autoAdvancing = false; _loading = false; });
      }
      return;
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_autoAdvancing) return;
      setState(() => _countdown--);
      _tick();
    });
  }

  void _cancelAutoAdvance() {
    setState(() { _autoAdvancing = false; _countdown = 8; });
  }

  void _playEpisode(Episode ep) {
    setState(() {
      _currentEp = ep;
      _loading = true;
      _autoAdvancing = false;
      _countdown = 8;
    });
    _buildSources();
    context.read<WatchlistService>().markWatched(widget.anime.id, ep.number);
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentUrl)));
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _isFullscreen ? _buildFullscreenPlayer() : _buildPortraitLayout(),
    );
  }

  Widget _buildPortraitLayout() {
    return SafeArea(
      child: Column(children: [
        _buildPlayerBox(),
        _buildControls(),
        Expanded(child: _buildEpisodeGrid()),
      ]),
    );
  }

  Widget _buildFullscreenPlayer() {
    return Stack(children: [
      _buildWebView(),
      if (_loading) _buildLoadingOverlay(),
      Positioned(
        top: 16, right: 16,
        child: IconButton(
          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
          onPressed: _toggleFullscreen,
        ),
      ),
    ]);
  }

  Widget _buildPlayerBox() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(children: [
        _buildWebView(),
        if (_loading) _buildLoadingOverlay(),
        // Fullscreen button overlay (bottom right)
        Positioned(
          bottom: 8, right: 8,
          child: GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useHybridComposition: true,        // Android: fixes rendering glitches
        supportMultipleWindows: true,      // Required for onCreateWindow to fire
        javaScriptCanOpenWindowsAutomatically: false,
      ),

      // ── THE KEY FIX: Block every popup/new tab ────────────────────────────
      // This is what was impossible in the web version.
      // Any attempt by VidNest or its ad scripts to open a new window
      // is caught here and dropped. return false = popup blocked.
      onCreateWindow: (controller, createWindowAction) async {
        // Returning false blocks the popup entirely. Done.
        debugPrint('[AD-BLOCK] Blocked popup: ${createWindowAction.request.url}');
        return false;
      },

      onWebViewCreated: (ctrl) => _webCtrl = ctrl,

      onLoadStart: (ctrl, url) {
        setState(() => _loading = true);
        _startAutoAdvance();
      },

      onLoadStop: (ctrl, url) {
        // onLoadStop fires for 404 and error pages too.
        // We DON'T cancel auto-advance here — only a real video player message would.
        setState(() => _loading = false);
      },

      onConsoleMessage: (ctrl, msg) {
        // If the page prints anything to console, JS is running = player is alive
        if (_autoAdvancing) _cancelAutoAdvance();
      },

      onReceivedError: (ctrl, request, error) {
        // Hard error (connection refused, DNS fail, etc.) — skip immediately
        debugPrint('[PLAYER] Error on ${request.url}: ${error.description}');
        if (_sourceIndex < _sources.length - 1) {
          Future.microtask(() => _switchSource(_sourceIndex + 1));
        }
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Loading server ${_sourceIndex + 1}...',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (_autoAdvancing) ...[
            const SizedBox(height: 8),
            Text(
              'Trying next server in ${_countdown}s',
              style: const TextStyle(
                color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _cancelAutoAdvance,
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + episode
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.anime.title, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Episode ${_currentEp.number}',
                style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11)),
            ]),
          ),
          // SUB / DUB toggle
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final t in ['SUB', 'DUB'])
                GestureDetector(
                  onTap: () { setState(() { _isDub = t == 'DUB'; _buildSources(); }); _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentUrl))); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: (t == 'DUB') == _isDub ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(t, style: TextStyle(
                      color: (t == 'DUB') == _isDub ? Colors.white : AppTheme.textSecondary,
                      fontSize: 10, fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        // Server selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('Servers:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            for (int i = 0; i < _sources.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => _switchSource(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == _sourceIndex ? AppTheme.primary.withOpacity(0.25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: i == _sourceIndex ? AppTheme.primary : AppTheme.darkBorder,
                      ),
                    ),
                    child: Text('${i + 1}', style: TextStyle(
                      color: i == _sourceIndex ? AppTheme.primaryLight : AppTheme.textSecondary,
                      fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEpisodeGrid() {
    final watchlist = context.watch<WatchlistService>();
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6, childAspectRatio: 1.1,
        crossAxisSpacing: 6, mainAxisSpacing: 6,
      ),
      itemCount: widget.allEpisodes.length,
      itemBuilder: (ctx, i) {
        final ep = widget.allEpisodes[i];
        final isCurrent = ep.number == _currentEp.number;
        final isWatched = watchlist.isWatched(widget.anime.id, ep.number);
        return GestureDetector(
          onTap: () => _playEpisode(ep),
          child: Container(
            decoration: BoxDecoration(
              gradient: isCurrent ? const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ) : null,
              color: isCurrent ? null : isWatched ? AppTheme.darkCardElev : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCurrent ? AppTheme.primary : AppTheme.darkBorder),
              boxShadow: isCurrent ? [const BoxShadow(color: AppTheme.primary, blurRadius: 8, spreadRadius: 0, offset: Offset(0, 0))] : null,
            ),
            child: Center(
              child: Text('${ep.number}', style: TextStyle(
                color: isCurrent ? Colors.white : isWatched ? AppTheme.textSecondary : AppTheme.textPrimary,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
            ),
          ),
        );
      },
    );
  }
}
