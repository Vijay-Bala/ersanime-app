import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

/// Manages local playlists, liked songs, and recently played history.
/// Mirrors the pattern of WatchlistService for data persistence.
class MusicPlaylistService extends ChangeNotifier {
  static const _playlistsKey = 'music_playlists_v1';
  static const _likedKey = 'music_liked_v1';
  static const _recentKey = 'music_recent_v1';

  List<MusicPlaylist> _playlists = [];
  List<Song> _likedSongs = [];
  final List<Song> _recentlyPlayed = [];

  List<MusicPlaylist> get playlists => List.unmodifiable(_playlists);
  List<Song> get likedSongs => List.unmodifiable(_likedSongs);
  List<Song> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load playlists
    final playlistsRaw = prefs.getString(_playlistsKey);
    if (playlistsRaw != null) {
      try {
        final list = jsonDecode(playlistsRaw) as List<dynamic>;
        _playlists = list
            .map((j) => MusicPlaylist.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _playlists = [];
      }
    }

    // Load liked songs
    final likedRaw = prefs.getString(_likedKey);
    if (likedRaw != null) {
      try {
        final list = jsonDecode(likedRaw) as List<dynamic>;
        _likedSongs = list
            .map((j) => Song.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _likedSongs = [];
      }
    }

    // Load recently played (last 50)
    final recentRaw = prefs.getString(_recentKey);
    if (recentRaw != null) {
      try {
        final list = jsonDecode(recentRaw) as List<dynamic>;
        _recentlyPlayed.clear();
        _recentlyPlayed.addAll(
          list.map((j) => Song.fromJson(j as Map<String, dynamic>)),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  // ─── Playlists ─────────────────────────────────────────────────────────────

  Future<MusicPlaylist> createPlaylist(String name) async {
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final pl = MusicPlaylist(id: id, name: name, songs: []);
    _playlists.insert(0, pl);
    await _savePlaylists();
    notifyListeners();
    return pl;
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _playlists[idx].name = newName;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    // Avoid duplicates
    if (_playlists[idx].songs.any((s) => s.id == song.id)) return;
    _playlists[idx].songs.add(song);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    _playlists[idx].songs.removeWhere((s) => s.id == songId);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> reorderSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    final songs = _playlists[idx].songs;
    if (oldIndex < newIndex) newIndex -= 1;
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
    await _savePlaylists();
    notifyListeners();
  }

  /// Bulk-add songs from an import (Spotify/YT) — used by playlist_import_service
  Future<MusicPlaylist> importPlaylist(MusicPlaylist playlist) async {
    // Avoid duplicate playlist by source ID
    final exists = _playlists.where((p) => p.id == playlist.id).toList();
    if (exists.isNotEmpty) {
      // Update songs
      final idx = _playlists.indexOf(exists.first);
      _playlists[idx].songs = playlist.songs;
      _playlists[idx].name = playlist.name;
      await _savePlaylists();
      notifyListeners();
      return _playlists[idx];
    }
    _playlists.insert(0, playlist);
    await _savePlaylists();
    notifyListeners();
    return playlist;
  }

  bool isInPlaylist(String playlistId, String songId) {
    final pl = _playlists.where((p) => p.id == playlistId).firstOrNull;
    return pl?.songs.any((s) => s.id == songId) ?? false;
  }

  MusicPlaylist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Liked Songs ───────────────────────────────────────────────────────────

  bool isLiked(String songId) => _likedSongs.any((s) => s.id == songId);

  Future<void> toggleLike(Song song) async {
    if (isLiked(song.id)) {
      _likedSongs.removeWhere((s) => s.id == song.id);
    } else {
      _likedSongs.insert(0, song);
    }
    await _saveLiked();
    notifyListeners();
  }

  // ─── Recently Played ───────────────────────────────────────────────────────

  Future<void> addToRecent(Song song) async {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 50) {
      _recentlyPlayed.removeRange(50, _recentlyPlayed.length);
    }
    await _saveRecent();
    notifyListeners();
  }

  // ─── Persistence ───────────────────────────────────────────────────────────

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _playlistsKey,
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> _saveLiked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _likedKey,
      jsonEncode(_likedSongs.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recentKey,
      jsonEncode(_recentlyPlayed.map((s) => s.toJson()).toList()),
    );
  }
}
