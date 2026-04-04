import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

// ─── JioSaavn Direct Internal API ────────────────────────────────────────────
// Uses the same internal api.php endpoints as the official JioSaavn app.
// Each request comes from the user's own device IP — no shared rate limit.
// Reference: BlackHole (Sangwan5688), cyberboysumanjay/JioSaavnAPI

const _base = 'https://www.jiosaavn.com/api.php';

// Common headers — mimic the JioSaavn web client
const _headers = {
  'Accept': 'application/json, text/javascript, */*; q=0.01',
  'Accept-Language': 'en-US,en;q=0.9',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
  'Origin': 'https://www.jiosaavn.com',
  'Referer': 'https://www.jiosaavn.com/',
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Safe GET with 12-second timeout and automatic retry
Future<Map<String, dynamic>> _get(
  String url, {
  int retries = 2,
}) async {
  Exception? lastErr;
  for (int attempt = 0; attempt <= retries; attempt++) {
    try {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 600 * (1 << attempt)));
      }
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = res.body;
        // JioSaavn sometimes wraps in a callback or returns plain JSON
        final clean = body.startsWith('/*') ? body.substring(body.indexOf('*/') + 2).trim() : body;
        return jsonDecode(clean) as Map<String, dynamic>;
      }
    } catch (e) {
      lastErr = e is Exception ? e : Exception(e.toString());
    }
  }
  throw lastErr ?? Exception('Failed to fetch: $url');
}

/// Some JioSaavn endpoints return a list directly for songs
Future<dynamic> _getRaw(String url, {int retries = 2}) async {
  Exception? lastErr;
  for (int attempt = 0; attempt <= retries; attempt++) {
    try {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 600 * (1 << attempt)));
      }
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = res.body;
        final clean = body.startsWith('/*') ? body.substring(body.indexOf('*/') + 2).trim() : body;
        return jsonDecode(clean);
      }
    } catch (e) {
      lastErr = e is Exception ? e : Exception(e.toString());
    }
  }
  throw lastErr ?? Exception('Failed to fetch: $url');
}

List<Song> _parseSongsList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(Song.fromSaavnSong)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }
  if (data is Map<String, dynamic>) {
    // Some endpoints wrap: { "results": [...] }
    final results = data['results'] ?? data['data'] ?? data['songs'] ?? data['song'];
    if (results is List) {
      return _parseSongsList(results);
    }
    // Single song object
    try {
      final s = Song.fromSaavnSong(data);
      if (s.id.isNotEmpty) return [s];
    } catch (_) {}
  }
  return [];
}

// ─── Public API ───────────────────────────────────────────────────────────────

/// Search songs by query. Returns up to 20 results.
Future<List<Song>> searchSongs(String query, {int page = 1}) async {
  if (query.trim().isEmpty) return [];
  final enc = Uri.encodeComponent(query.trim());
  final url =
      '$_base?__call=search.getResults&q=$enc&p=$page&n=20&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _getRaw(url);
    return _parseSongsList(data);
  } catch (_) {
    // Fallback: autocomplete endpoint
    try {
      final url2 =
          '$_base?__call=autocomplete.get&query=$enc&_format=json&_marker=0&ctx=wap6dot0';
      final data2 = await _get(url2);
      final songs = data2['songs']?['data'];
      if (songs is List) return _parseSongsList(songs);
    } catch (_) {}
    return [];
  }
}

/// Search albums by query.
Future<List<MusicAlbum>> searchAlbums(String query) async {
  if (query.trim().isEmpty) return [];
  final enc = Uri.encodeComponent(query.trim());
  final url =
      '$_base?__call=search.getAlbumResults&q=$enc&p=1&n=15&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _getRaw(url);
    List<dynamic> list = [];
    if (data is Map) list = data['results'] as List? ?? [];
    if (data is List) list = data;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MusicAlbum.fromSaavn)
        .toList();
  } catch (_) {
    return [];
  }
}

/// Search artists by query.
Future<List<MusicArtist>> searchArtists(String query) async {
  if (query.trim().isEmpty) return [];
  final enc = Uri.encodeComponent(query.trim());
  final url =
      '$_base?__call=search.getArtistResults&q=$enc&p=1&n=15&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _getRaw(url);
    List<dynamic> list = [];
    if (data is Map) list = data['results'] as List? ?? [];
    if (data is List) list = data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => MusicArtist(
              id: m['id']?.toString() ?? '',
              name: m['name']?.toString() ?? '',
              imageUrl: (m['image']?.toString() ?? '')
                  .replaceAll('http://', 'https://')
                  .trim(),
              topSongs: const [],
              albums: const [],
            ))
        .where((a) => a.id.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

/// Retrieve songs from the top playlist matching the genre query
Future<List<Song>> searchGenrePlaylistSongs(String genre) async {
  if (genre.trim().isEmpty) return [];
  // Use "hits" or "top 50" to reliably get a genre playlist
  final enc = Uri.encodeComponent('$genre top 50');
  final url =
      '$_base?__call=search.getPlaylistResults&q=$enc&p=1&n=1&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _getRaw(url);
    final results = data['results'];
    if (results is List && results.isNotEmpty) {
      final listId = results[0]['listid']?.toString() ?? results[0]['id']?.toString();
      if (listId != null) {
        return getJioSaavnPlaylistSongs(listId);
      }
    }
  } catch (_) {}
  return [];
}

/// Get detailed song info including download URLs.
Future<Song?> getSongDetail(String id) async {
  final url =
      '$_base?__call=song.getDetails&pids=$id&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _get(url);
    if (data['songs'] is List && (data['songs'] as List).isNotEmpty) {
      return Song.fromSaavnSong(data['songs'][0] as Map<String, dynamic>);
    }
    // Fallback if it returns the id map format
    final songData = data[id] ?? data.values.firstOrNull;
    if (songData is Map<String, dynamic>) return Song.fromSaavnSong(songData);
  } catch (_) {}
  return null;
}

/// Fetch lyrics for a song. Tries lrclib.net first (for synced/romanized LRC), then fallback to JioSaavn.
Future<SongLyrics> getLyrics(Song song) async {
  final isEngOrTamil = song.language.toLowerCase() == 'english' || song.isTamil;
  final artist = song.artist.split(',').first.trim();
  final baseQuery = '${song.title} $artist';

  // 1. Try LRCLIB for synced lyrics
  // We try two searches if it's a "foreign" language to the user (non-Tamil/English)
  final queries = [
    baseQuery,
    if (!isEngOrTamil) '$baseQuery romanized',
    if (!isEngOrTamil) '$baseQuery english transliteration',
  ];

  for (final q in queries) {
    try {
      final encQuery = Uri.encodeComponent(q);
      final searchUri = Uri.parse('https://lrclib.net/api/search?q=$encQuery');
      final res = await http.get(searchUri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final sData = jsonDecode(res.body) as List;
        if (sData.isNotEmpty) {
          // Find best match with synced lyrics
          final best = sData.firstWhere(
              (e) => e['syncedLyrics'] != null && e['syncedLyrics'].toString().isNotEmpty,
              orElse: () => sData.first);

          if (best['syncedLyrics'] != null && best['syncedLyrics'].toString().isNotEmpty) {
            return SongLyrics.fromLrc(best['syncedLyrics'].toString(), isTamil: song.isTamil);
          } else if (best['plainLyrics'] != null && best['plainLyrics'].toString().isNotEmpty) {
            return SongLyrics.plain(best['plainLyrics'].toString(), isTamil: song.isTamil);
          }
        }
      }
    } catch (_) {}
  }

  // 2. Fallback to JioSaavn native
  if (song.lyricsId != null && song.lyricsId!.isNotEmpty) {
    try {
      final url = '$_base?__call=lyrics.getLyrics&lyrics_id=${song.lyricsId}&ctx=wap6dot0&api_version=4&_format=json&_marker=0';
      final data = await _get(url);
      final lyrics = SongLyrics.fromSaavn(data, isTamil: song.isTamil);
      if (lyrics.hasLyrics) return lyrics;
    } catch (_) {}
  }

  return SongLyrics.empty();
}

/// Get top charts.
Future<MusicHomeData> getMusicHomeData({
  List<Song> recentlyPlayed = const [],
}) async {
  // Parallel fetching of different charts
  final results = await Future.wait([
    _fetchChart('tamil'),
    _fetchChart('hindi'),
    _fetchChart('english'),
    _fetchChart('telugu'),
    _fetchChart('malayalam'),
    _fetchNewReleases(),
  ]);

  return MusicHomeData(
    trending: [...results[0] as List<Song>, ...results[1] as List<Song>]
        .take(20)
        .toList(),
    tamilHits: results[0] as List<Song>,
    hindiFeatured: results[1] as List<Song>,
    englishTop: results[2] as List<Song>,
    teluguHits: results[3] as List<Song>,
    malayalamHits: results[4] as List<Song>,
    newReleases: results[5] as List<MusicAlbum>,
    recentlyPlayed: recentlyPlayed,
  );
}

Future<List<Song>> _fetchChart(String lang) async {
  return await searchGenrePlaylistSongs(lang);
}

Future<List<MusicAlbum>> _fetchNewReleases() async {
  final url =
      '$_base?__call=search.getAlbumResults&q=new+releases+2025&p=1&n=10&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _getRaw(url);
    List<dynamic> list = [];
    if (data is Map) list = data['results'] as List? ?? [];
    if (data is List) list = data;
    return list.whereType<Map<String, dynamic>>().map(MusicAlbum.fromSaavn).take(10).toList();
  } catch (_) {
    return [];
  }
}

/// Get full album detail with songs.
Future<MusicAlbum?> getAlbumDetail(String albumId) async {
  final url =
      '$_base?__call=content.getAlbumDetails&albumid=$albumId&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _get(url);
    return MusicAlbum.fromSaavn(data);
  } catch (_) {
    return null;
  }
}

/// Get artist detail with top songs and albums.
Future<MusicArtist?> getArtistDetail(String artistId) async {
  final url =
      '$_base?__call=webapi.getArtistDetails&artistid=$artistId&n_song=20&n_album=10&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _get(url);
    return MusicArtist.fromSaavn(data);
  } catch (_) {
    return null;
  }
}

/// Resolve a fresh stream URL for a song (called right before playback).
/// Refreshes URLs because JioSaavn stream URLs can expire.
Future<String> resolveStreamUrl(Song song) async {
  // Try existing URLs first
  if (song.downloadUrls.isNotEmpty) return song.bestStreamUrl;

  // Re-fetch song detail to get fresh URLs
  final fresh = await getSongDetail(song.id);
  if (fresh != null && fresh.downloadUrls.isNotEmpty) return fresh.bestStreamUrl;

  return '';
}

/// Get songs from a JioSaavn playlist token/ID.
Future<List<Song>> getJioSaavnPlaylistSongs(String listId) async {
  final url =
      '$_base?__call=playlist.getDetails&listid=$listId&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _get(url);
    final songs = data['list'] ?? data['songs'];
    if (songs is List) return _parseSongsList(songs);
  } catch (_) {}
  return [];
}

/// Fetch multiple song details by IDs (batch, max 50).
Future<List<Song>> getSongsByIds(List<String> ids) async {
  if (ids.isEmpty) return [];
  final batch = ids.take(50).join(',');
  final url =
      '$_base?__call=song.getDetails&pids=$batch&_format=json&_marker=0&ctx=wap6dot0';
  try {
    final data = await _get(url);
    final songs = <Song>[];
    if (data['songs'] is List) {
      for (final val in data['songs']) {
        if (val is Map<String, dynamic>) {
          try { songs.add(Song.fromSaavnSong(val)); } catch (_) {}
        }
      }
    } else {
      for (final key in data.keys) {
        final val = data[key];
        if (val is Map<String, dynamic>) {
          try { songs.add(Song.fromSaavnSong(val)); } catch (_) {}
        }
      }
    }
    return songs;
  } catch (_) {
    return [];
  }
}

/// Language-filtered search for home chips (Tamil, Hindi, English, etc.)
Future<List<Song>> searchByLanguage(String language, {int page = 1}) async {
  return searchSongs('top songs $language 2025', page: page);
}
