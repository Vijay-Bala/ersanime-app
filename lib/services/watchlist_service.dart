import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WatchStatus {
  watching,
  completed,
  onHold,
  dropped,
  planToWatch,
  favourite,
}

extension WatchStatusExt on WatchStatus {
  String get label => switch (this) {
    WatchStatus.watching => 'Watching',
    WatchStatus.completed => 'Completed',
    WatchStatus.onHold => 'On Hold',
    WatchStatus.dropped => 'Dropped',
    WatchStatus.planToWatch => 'Plan to Watch',
    WatchStatus.favourite => 'Favourites',
  };
  String get emoji => switch (this) {
    WatchStatus.watching => '▶️',
    WatchStatus.completed => '✅',
    WatchStatus.onHold => '⏸️',
    WatchStatus.dropped => '🗑️',
    WatchStatus.planToWatch => '📌',
    WatchStatus.favourite => '❤️',
  };
  Color get color => switch (this) {
    WatchStatus.watching => const Color(0xFF00F5FF),
    WatchStatus.completed => const Color(0xFF00FF88),
    WatchStatus.onHold => const Color(0xFFFFE600),
    WatchStatus.dropped => const Color(0xFFFF007A),
    WatchStatus.planToWatch => const Color(0xFFBF00FF),
    WatchStatus.favourite => const Color(0xFFFF6200),
  };
}

class WatchlistService extends ChangeNotifier {
  static const _animeStatusKey = 'watchlist_status_v2';
  static const _animeHistoryKey = 'watch_history';
  static const _mediaStatusKey = 'media_watchlist_v1';
  static const _mediaHistoryKey = 'media_history_v1';
  static const _mangaStatusKey = 'manga_watchlist_v1';
  static const _mangaHistoryKey = 'manga_history_v1';

  Map<int, WatchStatus> _animeStatus = {};
  Map<String, int> _animeHistory = {};
  Map<int, WatchStatus> _mediaStatus = {};
  Map<String, int> _mediaHistory = {};
  Map<int, WatchStatus> _mangaStatus = {};
  Map<String, int> _mangaHistory = {};

  Map<int, WatchStatus> get animeStatusMap => _animeStatus;
  Map<int, WatchStatus> get mediaStatusMap => _mediaStatus;
  Map<int, WatchStatus> get mangaStatusMap => _mangaStatus;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final animeRaw = prefs.getString(_animeStatusKey);
    if (animeRaw != null) {
      final decoded = jsonDecode(animeRaw) as Map<String, dynamic>;
      _animeStatus = decoded.map(
        (k, v) => MapEntry(int.parse(k), WatchStatus.values[v as int]),
      );
    }
    final animeHistRaw = prefs.getString(_animeHistoryKey);
    if (animeHistRaw != null) {
      _animeHistory = Map<String, int>.from(jsonDecode(animeHistRaw));
    }

    final mediaRaw = prefs.getString(_mediaStatusKey);
    if (mediaRaw != null) {
      final decoded = jsonDecode(mediaRaw) as Map<String, dynamic>;
      _mediaStatus = decoded.map(
        (k, v) => MapEntry(int.parse(k), WatchStatus.values[v as int]),
      );
    }
    final mediaHistRaw = prefs.getString(_mediaHistoryKey);
    if (mediaHistRaw != null) {
      _mediaHistory = Map<String, int>.from(jsonDecode(mediaHistRaw));
    }

    final mangaRaw = prefs.getString(_mangaStatusKey);
    if (mangaRaw != null) {
      final decoded = jsonDecode(mangaRaw) as Map<String, dynamic>;
      _mangaStatus = decoded.map(
        (k, v) => MapEntry(int.parse(k), WatchStatus.values[v as int]),
      );
    }
    final mangaHistRaw = prefs.getString(_mangaHistoryKey);
    if (mangaHistRaw != null) {
      _mangaHistory = Map<String, int>.from(jsonDecode(mangaHistRaw));
    }

    notifyListeners();
  }

  WatchStatus? getStatus(int id) => _animeStatus[id];
  bool isInAnyList(int id) => _animeStatus.containsKey(id);
  bool isFavourite(int id) => _animeStatus[id] == WatchStatus.favourite;
  bool isInWatchlist(int id) => isInAnyList(id);

  List<int> getByStatus(WatchStatus status) => _animeStatus.entries
      .where((e) => e.value == status)
      .map((e) => e.key)
      .toList();

  Future<void> setStatus(int id, WatchStatus? status) async {
    if (status == null) {
      _animeStatus.remove(id);
    } else {
      _animeStatus[id] = status;
    }
    await _saveAnimeStatus();
    notifyListeners();
  }

  Future<void> removeFromList(int id) async {
    _animeStatus.remove(id);
    await _saveAnimeStatus();
    notifyListeners();
  }

  Future<void> markWatched(int animeId, int episode) async {
    _animeHistory['$animeId-$episode'] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_animeHistoryKey, jsonEncode(_animeHistory));
    notifyListeners();
  }

  bool isWatched(int animeId, int episode) =>
      _animeHistory.containsKey('$animeId-$episode');

  int lastWatchedEpisode(int animeId) {
    int last = 0;
    for (final key in _animeHistory.keys) {
      if (key.startsWith('$animeId-')) {
        final ep = int.tryParse(key.split('-').last) ?? 0;
        if (ep > last) last = ep;
      }
    }
    return last;
  }

  Future<void> _saveAnimeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _animeStatusKey,
      jsonEncode(_animeStatus.map((k, v) => MapEntry(k.toString(), v.index))),
    );
  }

  WatchStatus? getMediaStatus(int id) => _mediaStatus[id];
  bool isMediaInAnyList(int id) => _mediaStatus.containsKey(id);
  bool isMediaFavourite(int id) => _mediaStatus[id] == WatchStatus.favourite;

  List<int> getMediaByStatus(WatchStatus status) => _mediaStatus.entries
      .where((e) => e.value == status)
      .map((e) => e.key)
      .toList();

  Future<void> setMediaStatus(int id, WatchStatus? status) async {
    if (status == null) {
      _mediaStatus.remove(id);
    } else {
      _mediaStatus[id] = status;
    }
    await _saveMediaStatus();
    notifyListeners();
  }

  Future<void> removeMediaFromList(int id) async {
    _mediaStatus.remove(id);
    await _saveMediaStatus();
    notifyListeners();
  }

  Future<void> markMediaWatched(
    int mediaId, {
    int season = 0,
    int episode = 0,
  }) async {
    final key =
        episode == 0 ? '$mediaId-movie' : '$mediaId-s${season}e$episode';
    _mediaHistory[key] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mediaHistoryKey, jsonEncode(_mediaHistory));
    notifyListeners();
  }

  bool isMediaWatched(int mediaId, {int season = 0, int episode = 0}) {
    final key =
        episode == 0 ? '$mediaId-movie' : '$mediaId-s${season}e$episode';
    return _mediaHistory.containsKey(key);
  }

  int lastWatchedMediaEpisode(int mediaId, int season) {
    int last = 0;
    for (final key in _mediaHistory.keys) {
      final prefix = '$mediaId-s${season}e';
      if (key.startsWith(prefix)) {
        final ep = int.tryParse(key.replaceFirst(prefix, '')) ?? 0;
        if (ep > last) last = ep;
      }
    }
    return last;
  }

  Future<void> _saveMediaStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _mediaStatusKey,
      jsonEncode(_mediaStatus.map((k, v) => MapEntry(k.toString(), v.index))),
    );
  }

  // Manga Methods
  WatchStatus? getMangaStatus(int id) => _mangaStatus[id];
  bool isMangaInAnyList(int id) => _mangaStatus.containsKey(id);
  bool isMangaFavourite(int id) => _mangaStatus[id] == WatchStatus.favourite;

  List<int> getMangaByStatus(WatchStatus status) => _mangaStatus.entries
      .where((e) => e.value == status)
      .map((e) => e.key)
      .toList();

  Future<void> setMangaStatus(int id, WatchStatus? status) async {
    if (status == null) {
      _mangaStatus.remove(id);
    } else {
      _mangaStatus[id] = status;
    }
    await _saveMangaStatus();
    notifyListeners();
  }

  Future<void> removeMangaFromList(int id) async {
    _mangaStatus.remove(id);
    await _saveMangaMatus();
    notifyListeners();
  }

  Future<void> markMangaRead(int mangaId, String chapterId) async {
    _mangaHistory['$mangaId-$chapterId'] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mangaHistoryKey, jsonEncode(_mangaHistory));
    notifyListeners();
  }

  bool isMangaRead(int mangaId, String chapterId) =>
      _mangaHistory.containsKey('$mangaId-$chapterId');

  Future<void> _saveMangaStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _mangaStatusKey,
      jsonEncode(_mangaStatus.map((k, v) => MapEntry(k.toString(), v.index))),
    );
  }

  Future<void> _saveMangaMatus() => _saveMangaStatus();
}
