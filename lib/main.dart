import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/watchlist_service.dart';
import 'services/music_playlist_service.dart';
import 'services/music_player_service.dart';
import 'screens/anime/anime_home_screen.dart';
import 'screens/anime/anime_search_screen.dart';
import 'screens/anime/anime_library_screen.dart';
import 'screens/media/media_home_screen.dart';
import 'screens/media/media_search_screen.dart';
import 'screens/media/media_library_screen.dart';
import 'screens/manga/manga_home_screen.dart';
import 'screens/manga/manga_search_screen.dart';
import 'screens/manga/manga_library_screen.dart';
import 'screens/music/music_home_screen.dart';
import 'screens/music/music_search_screen.dart';
import 'screens/music/music_library_screen.dart';
import 'widgets/music_mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background audio (just_audio_background)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ersa.music.channel',
    androidNotificationChannelName: 'ERSA Music',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  Animate.defaultDuration = 350.ms;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final watchlist = WatchlistService();
  await watchlist.load();

  final musicPlaylist = MusicPlaylistService();
  await musicPlaylist.load();

  final musicPlayer = MusicPlayerService();
  await musicPlayer.init(musicPlaylist);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: watchlist),
        ChangeNotifierProvider.value(value: musicPlaylist),
        ChangeNotifierProvider.value(value: musicPlayer),
        ChangeNotifierProvider(create: (_) => AppModeNotifier()),
      ],
      child: const ERSAApp(),
    ),
  );
}

enum AppMode { anime, movies, manga, music }

class AppModeNotifier extends ChangeNotifier {
  AppMode _mode = AppMode.anime;
  AppMode get mode => _mode;
  void setMode(AppMode m) {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
  }
}

class ERSAApp extends StatelessWidget {
  const ERSAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => MaterialApp(
        title: 'ERSA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: child,
      ),
      child: const MainNav(),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _animeIndex = 0;
  int _moviesIndex = 0;
  int _mangaIndex = 0;
  int _musicIndex = 0;

  static const _animeScreens = [
    AnimeHomeScreen(),
    AnimeSearchScreen(),
    AnimeLibraryScreen(),
  ];

  static const _moviesScreens = [
    MediaHomeScreen(),
    MediaSearchScreen(),
    MediaLibraryScreen(),
  ];

  static const _mangaScreens = [
    MangaHomeScreen(),
    MangaSearchScreen(),
    MangaLibraryScreen(),
  ];

  static const _musicScreens = [
    MusicHomeScreen(),
    MusicSearchScreen(),
    MusicLibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final modeNotifier = context.watch<AppModeNotifier>();
    final mode = modeNotifier.mode;

    final isAnime = mode == AppMode.anime;
    final isManga = mode == AppMode.manga;
    final isMusic = mode == AppMode.music;

    int currentIndex;
    if (isAnime)
      currentIndex = _animeIndex;
    else if (isManga)
      currentIndex = _mangaIndex;
    else if (isMusic)
      currentIndex = _musicIndex;
    else
      currentIndex = _moviesIndex;

    Color activeColor;
    if (isAnime)
      activeColor = AppTheme.primary;
    else if (isManga)
      activeColor = AppTheme.accentGreen;
    else if (isMusic)
      activeColor = const Color(0xFFFF1493);
    else
      activeColor = AppTheme.accentOrange;

    Widget body;
    if (isAnime)
      body = IndexedStack(index: _animeIndex, children: _animeScreens);
    else if (isManga)
      body = IndexedStack(index: _mangaIndex, children: _mangaScreens);
    else if (isMusic)
      body = IndexedStack(index: _musicIndex, children: _musicScreens);
    else
      body = IndexedStack(index: _moviesIndex, children: _moviesScreens);

    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player (visible across all sections)
          const MusicMiniPlayer(),
          // Bottom navigation
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.darkBorder, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              selectedItemColor: activeColor,
              unselectedItemColor: AppTheme.textSecondary,
              onTap: (i) => setState(() {
                if (isAnime)
                  _animeIndex = i;
                else if (isManga)
                  _mangaIndex = i;
                else if (isMusic)
                  _musicIndex = i;
                else
                  _moviesIndex = i;
              }),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_rounded),
                  label: 'Library',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModeSwitcherTitle extends StatelessWidget {
  const ModeSwitcherTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final modeNotifier = context.watch<AppModeNotifier>();
    final mode = modeNotifier.mode;

    final isAnime = mode == AppMode.anime;
    final isManga = mode == AppMode.manga;
    final isMusic = mode == AppMode.music;

    List<Color> gradColors;
    if (isAnime)
      gradColors = [AppTheme.primary, AppTheme.accentCyan];
    else if (isManga)
      gradColors = [AppTheme.accentGreen, AppTheme.accentCyan];
    else if (isMusic)
      gradColors = [const Color(0xFFFF1493), const Color(0xFF9B00FF)];
    else
      gradColors = [AppTheme.accentOrange, AppTheme.accentPink];

    String label;
    if (isAnime)
      label = 'ERSA-Anime';
    else if (isManga)
      label = 'ERSA-Manga';
    else if (isMusic)
      label = 'ERSA-Music';
    else
      label = 'ERSA-Movies';

    return GestureDetector(
      onTap: () => _showDropdown(context, modeNotifier),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                LinearGradient(colors: gradColors).createShader(bounds),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Icon(
            Icons.arrow_drop_down_rounded,
            color: gradColors.first,
            size: 20.sp,
          ),
        ],
      ),
    );
  }

  void _showDropdown(BuildContext context, AppModeNotifier notifier) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    showMenu<AppMode>(
      context: context,
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height + 4,
        offset.dx + 240,
        0,
      ),
      items: [
        PopupMenuItem(
          value: AppMode.anime,
          child: _ModeOption(
            icon: '🎌',
            label: 'ERSA-Anime',
            sublabel: 'Anime streaming',
            gradColors: [AppTheme.primary, AppTheme.accentCyan],
            selected: notifier.mode == AppMode.anime,
          ),
        ),
        PopupMenuItem(
          value: AppMode.movies,
          child: _ModeOption(
            icon: '🎬',
            label: 'ERSA-Movies',
            sublabel: 'Movies & Series streaming',
            gradColors: [AppTheme.accentOrange, AppTheme.accentPink],
            selected: notifier.mode == AppMode.movies,
          ),
        ),
        PopupMenuItem(
          value: AppMode.manga,
          child: _ModeOption(
            icon: '📖',
            label: 'ERSA-Manga',
            sublabel: 'Manga & Manhwa reader',
            gradColors: [AppTheme.accentGreen, AppTheme.accentCyan],
            selected: notifier.mode == AppMode.manga,
          ),
        ),
        PopupMenuItem(
          value: AppMode.music,
          child: _ModeOption(
            icon: '🎵',
            label: 'ERSA-Music',
            sublabel: 'Songs, Playlists & Lyrics',
            gradColors: [const Color(0xFFFF1493), const Color(0xFF9B00FF)],
            selected: notifier.mode == AppMode.music,
          ),
        ),
      ],
    ).then((val) {
      if (val != null) notifier.setMode(val);
    });
  }
}

class _ModeOption extends StatelessWidget {
  final String icon;
  final String label;
  final String sublabel;
  final List<Color> gradColors;
  final bool selected;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradColors,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 18.sp)),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    LinearGradient(colors: gradColors).createShader(b),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
        if (selected)
          Icon(Icons.check_rounded, color: gradColors.first, size: 16.sp),
      ],
    );
  }
}
