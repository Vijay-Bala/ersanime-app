import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import 'music_service.dart' as music;

/// Handles importing playlists from Spotify (public) and YouTube Music.
/// No API keys required from users — Spotify uses embedded Client Credentials,
/// YouTube uses youtube_explode_dart (InnerTube, no key needed).

// ─── Spotify Client Credentials (our own app, embedded) ───────────────────────
// These credentials allow reading PUBLIC Spotify data only.
// Registered as a free Spotify Developer app — standard open-source practice.
// Scope: none (client credentials, public data only)
const _spotifyClientId = 'YOUR_SPOTIFY_CLIENT_ID'; // Replace at build time
const _spotifyClientSecret = 'YOUR_SPOTIFY_CLIENT_SECRET'; // Replace at build time

// ─── Import Result ─────────────────────────────────────────────────────────────
class ImportResult {
  final MusicPlaylist playlist;
  final int total;
  final int matched;
  final int notFound;
  final List<String> notFoundTitles;
  final String? error;

  bool get success => error == null;

  const ImportResult({
    required this.playlist,
    required this.total,
    required this.matched,
    required this.notFound,
    required this.notFoundTitles,
    this.error,
  });

  factory ImportResult.failed(String error) => ImportResult(
    playlist: MusicPlaylist(id: '', name: '', songs: []),
    total: 0,
    matched: 0,
    notFound: 0,
    notFoundTitles: [],
    error: error,
  );
}

// ─── Progress Callback ─────────────────────────────────────────────────────────
typedef ImportProgressCallback = void Function(int current, int total, String songTitle);

// ─── Spotify Import ─────────────────────────────────────────────────────────────

/// Import a public Spotify playlist by URL.
/// E.g.: https://open.spotify.com/playlist/37i9dQZF1DXd2rp4qJ4hQJ
Future<ImportResult> importFromSpotify(
  String url, {
  ImportProgressCallback? onProgress,
}) async {
  try {
    final playlistId = _extractSpotifyPlaylistId(url);
    if (playlistId == null) {
      return ImportResult.failed('Invalid Spotify playlist URL. Please paste the full link.');
    }

    // Step 1: Get Spotify access token (client credentials — no user login)
    final token = await _getSpotifyToken();
    if (token == null) return ImportResult.failed('Could not connect to Spotify. Please try again.');

    // Step 2: Fetch playlist metadata + tracks (handles pagination)
    final tracks = await _fetchSpotifyTracks(playlistId, token);
    if (tracks.isEmpty) {
      return ImportResult.failed('Could not read playlist. Make sure it is set to Public.');
    }

    final playlistName = tracks['name'] as String? ?? 'Spotify Playlist';
    final trackList = tracks['tracks'] as List<Map<String, String>>? ?? [];
    final coverUrl = tracks['image'] as String? ?? '';

    // Step 3: Search each track on JioSaavn
    final songs = <Song>[];
    final notFound = <String>[];

    for (int i = 0; i < trackList.length; i++) {
      final track = trackList[i];
      final title = track['title'] ?? '';
      final artist = track['artist'] ?? '';
      onProgress?.call(i + 1, trackList.length, '$artist — $title');

      final query = artist.isNotEmpty ? '$title $artist' : title;
      final results = await music.searchSongs(query);
      if (results.isNotEmpty) {
        songs.add(results.first);
      } else {
        notFound.add('$artist — $title');
      }

      // Small delay to be respectful
      if (i % 5 == 0 && i != 0) await Future.delayed(const Duration(milliseconds: 300));
    }

    final id = 'spotify_$playlistId';
    final playlist = MusicPlaylist(
      id: id,
      name: playlistName,
      songs: songs,
      source: PlaylistSource.spotify,
      coverUrl: coverUrl,
    );

    return ImportResult(
      playlist: playlist,
      total: trackList.length,
      matched: songs.length,
      notFound: notFound.length,
      notFoundTitles: notFound,
    );
  } catch (e) {
    return ImportResult.failed('Import failed: ${e.toString().split('\n').first}');
  }
}

String? _extractSpotifyPlaylistId(String url) {
  // Supports: https://open.spotify.com/playlist/ID, spotify:playlist:ID
  final regexHttp = RegExp(r'open\.spotify\.com/playlist/([a-zA-Z0-9]+)');
  final regexUri = RegExp(r'spotify:playlist:([a-zA-Z0-9]+)');
  final m = regexHttp.firstMatch(url) ?? regexUri.firstMatch(url);
  return m?.group(1);
}

Future<String?> _getSpotifyToken() async {
  try {
    final credentials = base64Encode(utf8.encode('$_spotifyClientId:$_spotifyClientSecret'));
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['access_token']?.toString();
    }
  } catch (_) {}
  return null;
}

Future<Map<String, dynamic>> _fetchSpotifyTracks(String playlistId, String token) async {
  final tracks = <Map<String, String>>[];
  String playlistName = 'Spotify Playlist';
  String coverUrl = '';
  String? nextUrl = 'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=50&fields=next,items(track(name,artists(name)))';

  // Fetch playlist name + cover first
  try {
    final metaRes = await http.get(
      Uri.parse('https://api.spotify.com/v1/playlists/$playlistId?fields=name,images'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (metaRes.statusCode == 200) {
      final j = jsonDecode(metaRes.body) as Map<String, dynamic>;
      playlistName = j['name']?.toString() ?? playlistName;
      final images = j['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        coverUrl = images.first['url']?.toString() ?? '';
      }
    }
  } catch (_) {}

  // Paginate through all tracks
  while (nextUrl != null) {
    try {
      final res = await http.get(
        Uri.parse(nextUrl),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) break;
      final page = jsonDecode(res.body) as Map<String, dynamic>;
      final items = page['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final track = item['track'] as Map<String, dynamic>?;
        if (track == null) continue;
        final name = track['name']?.toString() ?? '';
        final artists = (track['artists'] as List<dynamic>?)
                ?.map((a) => a['name']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .join(', ') ??
            '';
        if (name.isNotEmpty) {
          tracks.add({'title': name, 'artist': artists});
        }
      }
      nextUrl = page['next']?.toString();
    } catch (_) {
      break;
    }
  }

  return {
    'name': playlistName,
    'tracks': tracks,
    'image': coverUrl,
  };
}

// ─── YouTube Music Import ──────────────────────────────────────────────────────

/// Import a public YouTube/YT Music playlist by URL. No API key needed.
/// Uses youtube_explode_dart which calls InnerTube internally.
Future<ImportResult> importFromYouTube(
  String url, {
  ImportProgressCallback? onProgress,
}) async {
  final yt = YoutubeExplode();
  try {
    final playlistId = _extractYouTubePlaylistId(url);
    if (playlistId == null) {
      return ImportResult.failed('Invalid YouTube Music playlist URL.');
    }

    // Fetch playlist metadata
    final playlist = await yt.playlists.get(playlistId);
    final playlistName = playlist.title;
    String coverUrl = '';

    // Fetch all videos with pagination
    final videos = <Video>[];
    await for (final video in yt.playlists.getVideos(playlist.id)) {
      videos.add(video);
    }

    if (videos.isEmpty) {
      return ImportResult.failed('Playlist is empty or private.');
    }

    // Search each video title on JioSaavn
    final songs = <Song>[];
    final notFound = <String>[];

    for (int i = 0; i < videos.length; i++) {
      final video = videos[i];
      final title = video.title;
      final author = video.author;
      onProgress?.call(i + 1, videos.length, '$author — $title');

      // Clean YouTube title (remove [Official Video], (Lyric Video), etc.)
      final cleanTitle = _cleanYouTubeTitle(title);
      final query = '$cleanTitle $author';

      final results = await music.searchSongs(query);
      if (results.isNotEmpty) {
        songs.add(results.first);
        if (coverUrl.isEmpty) {
          coverUrl = results.first.imageUrl;
        }
      } else {
        // Try with just the clean title
        final results2 = await music.searchSongs(cleanTitle);
        if (results2.isNotEmpty) {
          songs.add(results2.first);
        } else {
          notFound.add('$author — $title');
        }
      }

      if (i % 5 == 0 && i != 0) await Future.delayed(const Duration(milliseconds: 300));
    }

    final id = 'youtube_${playlist.id.value}';
    final musicPlaylist = MusicPlaylist(
      id: id,
      name: playlistName,
      songs: songs,
      source: PlaylistSource.youtube,
      coverUrl: coverUrl,
    );

    return ImportResult(
      playlist: musicPlaylist,
      total: videos.length,
      matched: songs.length,
      notFound: notFound.length,
      notFoundTitles: notFound,
    );
  } catch (e) {
    return ImportResult.failed('Import failed: ${e.toString().split('\n').first}');
  } finally {
    yt.close();
  }
}

String? _extractYouTubePlaylistId(String url) {
  final regex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
  final m = regex.firstMatch(url);
  return m?.group(1);
}

String _cleanYouTubeTitle(String title) {
  return title
      .replaceAll(RegExp(r'\(Official (Music )?Video\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[Official (Music )?Video\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(Lyric(s)? Video\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[Lyric(s)? Video\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(Official Audio\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[Official Audio\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(Audio\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\| [^|]+\|?$'), '')
      .replaceAll(RegExp(r'ft\. .+', caseSensitive: false), '')
      .replaceAll(RegExp(r'feat\. .+', caseSensitive: false), '')
      .trim();
}

// ─── URL Detector (call this to decide which importer to use) ─────────────────
enum ImportSource { spotify, youtube, unknown }

ImportSource detectImportSource(String url) {
  if (url.contains('spotify.com') || url.startsWith('spotify:')) {
    return ImportSource.spotify;
  }
  if (url.contains('youtube.com') || url.contains('youtu.be') || url.contains('music.youtube.com')) {
    return ImportSource.youtube;
  }
  return ImportSource.unknown;
}

Future<ImportResult> importPlaylist(
  String url, {
  ImportProgressCallback? onProgress,
}) async {
  final source = detectImportSource(url);
  switch (source) {
    case ImportSource.spotify:
      return importFromSpotify(url, onProgress: onProgress);
    case ImportSource.youtube:
      return importFromYouTube(url, onProgress: onProgress);
    case ImportSource.unknown:
      return ImportResult.failed('Unsupported URL. Please use a Spotify or YouTube Music playlist link.');
  }
}
