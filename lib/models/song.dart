import 'dart:convert';
import 'package:dart_des/dart_des.dart';

// ─── Song ────────────────────────────────────────────────────────────────────
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String imageUrl;
  final String language;
  final int durationSeconds;
  final List<String> downloadUrls; // 320kbps first, then fallbacks
  final String? lyricsId;
  final String? permaUrl;
  final int? year;
  final String? label;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.imageUrl,
    required this.language,
    required this.durationSeconds,
    required this.downloadUrls,
    this.lyricsId,
    this.permaUrl,
    this.year,
    this.label,
  });

  bool get isTamil => language.toLowerCase() == 'tamil';

  String get displayDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// JioSaavn returns encrypted 128/320 URLs — we pick highest quality available
  String get bestStreamUrl {
    if (downloadUrls.isEmpty) return '';
    // JioSaavn returns URLs with quality suffix: _96, _160, _320
    // Sort descending by quality marker
    final sorted = [...downloadUrls]..sort((a, b) {
      final qa = _qualityScore(a);
      final qb = _qualityScore(b);
      return qb.compareTo(qa);
    });
    return sorted.first;
  }

  int _qualityScore(String url) {
    if (url.contains('_320')) return 320;
    if (url.contains('_160')) return 160;
    if (url.contains('_96')) return 96;
    if (url.contains('_48')) return 48;
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'imageUrl': imageUrl,
    'language': language,
    'durationSeconds': durationSeconds,
    'downloadUrls': downloadUrls,
    'lyricsId': lyricsId,
    'permaUrl': permaUrl,
    'year': year,
    'label': label,
  };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? 'Unknown',
    artist: j['artist']?.toString() ?? 'Unknown Artist',
    album: j['album']?.toString() ?? '',
    albumId: j['albumId']?.toString() ?? '',
    imageUrl: j['imageUrl']?.toString() ?? '',
    language: j['language']?.toString() ?? '',
    durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
    downloadUrls: List<String>.from(j['downloadUrls'] ?? []),
    lyricsId: j['lyricsId']?.toString(),
    permaUrl: j['permaUrl']?.toString(),
    year: (j['year'] as num?)?.toInt(),
    label: j['label']?.toString(),
  );

  /// Parse from JioSaavn api.php raw song object
  factory Song.fromSaavnSong(Map<String, dynamic> m) {
    // Image — JioSaavn returns 150x150. Upscaling to 500x500 often 404s on older songs.
    // Safe size is 250x250 or leaving as is. Blackhole uses 500x500 but handles 404s.
    // We will use 250x250 as a safe upscale.
    String img = '';
    final imgVal = m['image'] ?? m['more_info']?['image'];
    if (imgVal != null) {
      img = _cleanHtml(imgVal.toString())
          .replaceAll('150x150', '250x250')
          .replaceAll('50x50', '250x250')
          .replaceAll('http://', 'https://')
          .trim();
    }

    // Download URLs — JioSaavn returns them in 'more_info' or directly
    final moreInfo = m['more_info'] as Map<String, dynamic>? ?? {};
    final List<String> urls = [];

    // Collect all quality URLs
    for (final q in ['320', '160', '96', '48', '12']) {
      final key = '${q}kbps';
      final url = moreInfo[key]?.toString();
      if (url != null && url.isNotEmpty) {
        urls.add(_decryptSaavnUrl(url, q));
      }
    }

    // Fallback: try encrypted_media_url / media_url
    if (urls.isEmpty) {
      final enc = m['encrypted_media_url']?.toString() ?? moreInfo['encrypted_media_url']?.toString() ?? '';
      if (enc.isNotEmpty && enc != 'null') urls.add(_decryptSaavnUrl(enc, '320'));
      final med = m['media_url']?.toString() ?? moreInfo['media_url']?.toString() ?? '';
      if (med.isNotEmpty && med != 'null' && !urls.contains(med)) urls.add(med);
    }

    final artistsRaw = m['more_info']?['artistMap']?['primary_artists'];
    String artist = 'Unknown Artist';
    if (artistsRaw is List && artistsRaw.isNotEmpty) {
      artist = artistsRaw.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
    } else if (m['primary_artists'] != null) {
      artist = m['primary_artists'].toString();
    } else if (m['singers'] != null) {
      artist = m['singers'].toString();
    }

    return Song(
      id: m['id']?.toString() ?? '',
      title: _cleanHtml(m['song']?.toString() ?? m['title']?.toString() ?? 'Unknown'),
      artist: _cleanHtml(artist),
      album: _cleanHtml(moreInfo['album']?.toString() ?? m['album']?.toString() ?? ''),
      albumId: moreInfo['albumid']?.toString() ?? '',
      imageUrl: img,
      language: m['language']?.toString() ?? '',
      durationSeconds: int.tryParse(m['duration']?.toString() ?? moreInfo['duration']?.toString() ?? '0') ?? 0,
      downloadUrls: urls,
      lyricsId: (m['has_lyrics']?.toString() == 'true' || moreInfo['has_lyrics']?.toString() == 'true') ? m['id']?.toString() : null,
      permaUrl: m['perma_url']?.toString(),
      year: int.tryParse(m['year']?.toString() ?? ''),
      label: moreInfo['label']?.toString(),
    );
  }
}

/// JioSaavn URL decryption (same algo used by BlackHole / cyberboysumanjay)
/// The server returns DES-encrypted URLs; we decrypt using the known key.
String _decryptSaavnUrl(String encrypted, String quality) {
  String url = encrypted;
  if (url.isEmpty) return url;
  if (!url.contains('.mp4') && !url.contains('.m4a') && !url.contains('http')) {
    try {
      final key = '38346591'.codeUnits;
      final des = DES(key: key, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      // Added trim() to fix base64Decode whitespace exception
      final decoded = base64Decode(url.trim());
      final decrypted = des.decrypt(decoded);
      url = utf8.decode(decrypted);
    } catch (e) {
      print('Error decrypting Saavn URL: $e');
    }
  }
  
  if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
  
  // Some versions return _96.mp4 style — replace with correct quality
  url = url
      .replaceAll('_96.', '_$quality.')
      .replaceAll('_160.', '_$quality.')
      .replaceAll('_320.', '_$quality.');
  return url;
}

String _cleanHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'<[^>]*>'), '');

// ─── Lyrics ──────────────────────────────────────────────────────────────────
class SongLyrics {
  final String text;
  final bool isTamil;
  final bool hasLyrics;

  const SongLyrics({
    required this.text,
    required this.isTamil,
    required this.hasLyrics,
  });

  factory SongLyrics.empty() => const SongLyrics(text: '', isTamil: false, hasLyrics: false);

  factory SongLyrics.fromSaavn(Map<String, dynamic> m, {bool isTamil = false}) {
    final raw = m['lyrics']?.toString() ?? '';
    final clean = raw
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .trim();
    return SongLyrics(text: clean, isTamil: isTamil, hasLyrics: clean.isNotEmpty);
  }
}

// ─── Music Playlist ───────────────────────────────────────────────────────────
enum PlaylistSource { local, spotify, youtube }

class MusicPlaylist {
  final String id;
  String name;
  List<Song> songs;
  final PlaylistSource source;
  final DateTime createdAt;
  String? coverUrl;

  MusicPlaylist({
    required this.id,
    required this.name,
    required this.songs,
    this.source = PlaylistSource.local,
    DateTime? createdAt,
    this.coverUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayCoverUrl {
    if (coverUrl != null && coverUrl!.isNotEmpty) return coverUrl!;
    if (songs.isNotEmpty) return songs.first.imageUrl;
    return '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': songs.map((s) => s.toJson()).toList(),
    'source': source.index,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'coverUrl': coverUrl,
  };

  factory MusicPlaylist.fromJson(Map<String, dynamic> j) => MusicPlaylist(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? 'Playlist',
    songs: (j['songs'] as List<dynamic>? ?? [])
        .map((s) => Song.fromJson(s as Map<String, dynamic>))
        .toList(),
    source: PlaylistSource.values[(j['source'] as num?)?.toInt() ?? 0],
    createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
    coverUrl: j['coverUrl']?.toString(),
  );
}

// ─── Music Album ──────────────────────────────────────────────────────────────
class MusicAlbum {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final String year;
  final String language;
  final List<Song> songs;
  final String? permaUrl;

  const MusicAlbum({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.year,
    required this.language,
    required this.songs,
    this.permaUrl,
  });

  factory MusicAlbum.fromSaavn(Map<String, dynamic> m) {
    final songs = (m['songs'] as List<dynamic>? ?? [])
        .map((s) => Song.fromSaavnSong(s as Map<String, dynamic>))
        .toList();
    String img = m['image']?.toString() ?? '';
    img = img.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
    return MusicAlbum(
      id: m['albumid']?.toString() ?? m['id']?.toString() ?? '',
      name: _cleanHtml(m['title']?.toString() ?? m['name']?.toString() ?? ''),
      artist: _cleanHtml(m['primary_artists']?.toString() ?? ''),
      imageUrl: img,
      year: m['year']?.toString() ?? '',
      language: m['language']?.toString() ?? '',
      songs: songs,
      permaUrl: m['perma_url']?.toString(),
    );
  }
}

// ─── Music Artist ─────────────────────────────────────────────────────────────
class MusicArtist {
  final String id;
  final String name;
  final String imageUrl;
  final String? bio;
  final List<Song> topSongs;
  final List<MusicAlbum> albums;

  const MusicArtist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.bio,
    required this.topSongs,
    required this.albums,
  });

  factory MusicArtist.fromSaavn(Map<String, dynamic> m) {
    String img = m['image']?.toString() ?? '';
    img = img.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
    final topSongs = (m['topSongs'] as List<dynamic>? ?? [])
        .map((s) => Song.fromSaavnSong(s as Map<String, dynamic>))
        .toList();
    final albums = (m['topAlbums'] as List<dynamic>? ?? [])
        .map((a) => MusicAlbum.fromSaavn(a as Map<String, dynamic>))
        .toList();
    return MusicArtist(
      id: m['artistid']?.toString() ?? m['id']?.toString() ?? '',
      name: _cleanHtml(m['name']?.toString() ?? ''),
      imageUrl: img,
      bio: m['bio']?.toString(),
      topSongs: topSongs,
      albums: albums,
    );
  }
}

// ─── Home Data ────────────────────────────────────────────────────────────────
class MusicHomeData {
  final List<Song> trending;
  final List<Song> tamilHits;
  final List<Song> hindiFeatured;
  final List<Song> englishTop;
  final List<MusicAlbum> newReleases;
  final List<Song> recentlyPlayed;

  const MusicHomeData({
    required this.trending,
    required this.tamilHits,
    required this.hindiFeatured,
    required this.englishTop,
    required this.newReleases,
    required this.recentlyPlayed,
  });

  factory MusicHomeData.empty() => const MusicHomeData(
    trending: [],
    tamilHits: [],
    hindiFeatured: [],
    englishTop: [],
    newReleases: [],
    recentlyPlayed: [],
  );
}

// ─── Search Results ───────────────────────────────────────────────────────────
class MusicSearchResults {
  final List<Song> songs;
  final List<MusicAlbum> albums;
  final List<MusicArtist> artists;

  const MusicSearchResults({
    required this.songs,
    required this.albums,
    required this.artists,
  });

  factory MusicSearchResults.empty() =>
      const MusicSearchResults(songs: [], albums: [], artists: []);
}

// ─── Repeat Mode ─────────────────────────────────────────────────────────────
enum PlayerRepeatMode { none, one, all }
