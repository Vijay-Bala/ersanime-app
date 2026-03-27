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
  static const _statusKey = 'watchlist_status_v2';
  static const _historyKey = 'watch_history';

  Map<int, WatchStatus> _statusMap = {};

  Map<String, int> _history = {};

  Map<int, WatchStatus> get statusMap => _statusMap;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_statusKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _statusMap = decoded.map(
        (k, v) => MapEntry(int.parse(k), WatchStatus.values[v as int]),
      );
    }

    final histRaw = prefs.getString(_historyKey);
    if (histRaw != null) {
      _history = Map<String, int>.from(jsonDecode(histRaw));
    }
    notifyListeners();
  }

  Future<void> _saveStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _statusKey,
      jsonEncode(_statusMap.map((k, v) => MapEntry(k.toString(), v.index))),
    );
  }

  WatchStatus? getStatus(int id) => _statusMap[id];
  bool isInAnyList(int id) => _statusMap.containsKey(id);
  bool isFavourite(int id) => _statusMap[id] == WatchStatus.favourite;

  List<int> getByStatus(WatchStatus status) => _statusMap.entries
      .where((e) => e.value == status)
      .map((e) => e.key)
      .toList();

  Future<void> setStatus(int id, WatchStatus? status) async {
    if (status == null) {
      _statusMap.remove(id);
    } else {
      _statusMap[id] = status;
    }
    await _saveStatus();
    notifyListeners();
  }

  Future<void> removeFromList(int id) async {
    _statusMap.remove(id);
    await _saveStatus();
    notifyListeners();
  }

  Future<void> markWatched(int animeId, int episode) async {
    _history['$animeId-$episode'] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
    notifyListeners();
  }

  bool isWatched(int animeId, int episode) =>
      _history.containsKey('$animeId-$episode');

  int lastWatchedEpisode(int animeId) {
    int last = 0;
    for (final key in _history.keys) {
      if (key.startsWith('$animeId-')) {
        final ep = int.tryParse(key.split('-').last) ?? 0;
        if (ep > last) last = ep;
      }
    }
    return last;
  }

  bool isInWatchlist(int id) => isInAnyList(id);
}
