import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// Cloudflare Worker proxy — routes around Indian ISP blocks on mobile data.
// The worker forwards requests to api.themoviedb.org transparently.
// Free tier: 100,000 requests/day — more than enough.
const _tmdbBase = 'https://ersa-tmdb.vijaybala7604.workers.dev/3';
const _tmdbKey = '54efc8bcc2f9f3a1a1eed68f22e2c55a';

Future<Map<String, dynamic>> _get(
  String path, [
  Map<String, String>? params,
]) async {
  final query = {'api_key': _tmdbKey, 'language': 'en-US', ...?params};
  final uri = Uri.parse('$_tmdbBase$path').replace(queryParameters: query);
  final res = await http.get(uri);
  return jsonDecode(res.body) as Map<String, dynamic>;
}

Future<List<MediaItem>> _getMovieList(
  String path, [
  Map<String, String>? params,
]) async {
  final data = await _get(path, params);
  final results = (data['results'] as List<dynamic>? ?? []);
  return results
      .map((r) => MediaItem.fromTmdbMovie(r as Map<String, dynamic>))
      .toList();
}

Future<List<MediaItem>> _getTvList(
  String path, [
  Map<String, String>? params,
]) async {
  final data = await _get(path, params);
  final results = (data['results'] as List<dynamic>? ?? []);
  return results
      .map((r) => MediaItem.fromTmdbTv(r as Map<String, dynamic>))
      .toList();
}

Future<MediaHomeData> getMediaHomeData() async {
  final results = await Future.wait([
    _getMovieList('/trending/movie/week'),
    _getTvList('/trending/tv/week'),
    _getMovieList('/movie/top_rated'),
    _getTvList('/tv/top_rated'),
    _getMovieList('/discover/movie', {
      'with_original_language': 'hi',
      'sort_by': 'popularity.desc',
    }),
    _getTvList('/discover/tv', {
      'with_original_language': 'ko',
      'sort_by': 'popularity.desc',
    }),
    _getMovieList('/discover/movie', {
      'with_original_language': 'ta',
      'sort_by': 'popularity.desc',
    }),
    _getMovieList('/discover/movie', {
      'with_original_language': 'ml',
      'sort_by': 'popularity.desc',
    }),
    _getMovieList('/discover/movie', {
      'with_original_language': 'ja',
      'sort_by': 'popularity.desc',
    }),
    _getMovieList('/discover/movie', {
      'with_original_language': 'zh',
      'sort_by': 'popularity.desc',
    }),
    _getMovieList('/discover/movie', {
      'with_original_language': 'te',
      'sort_by': 'popularity.desc',
    }),
  ]);
  return MediaHomeData(
    trendingMovies: results[0],
    trendingSeries: results[1],
    topRatedMovies: results[2],
    topRatedSeries: results[3],
    bollywood: results[4],
    korean: results[5],
    tamil: results[6],
    malayalam: results[7],
    japanese: results[8],
    chinese: results[9],
    telugu: results[10],
  );
}

Future<MediaItem> getMovieDetail(int id) async {
  final data = await _get('/movie/$id', {
    'append_to_response': 'recommendations',
  });
  return MediaItem.fromTmdbMovie(data);
}

Future<MediaItem> getTvDetail(int id) async {
  final data = await _get('/tv/$id', {'append_to_response': 'recommendations'});
  return MediaItem.fromTmdbTv(data);
}

Future<List<TvEpisode>> getSeasonEpisodes(int tvId, int season) async {
  final data = await _get('/tv/$tvId/season/$season');
  final eps = (data['episodes'] as List<dynamic>? ?? []);
  return eps.map((e) => TvEpisode.fromJson(e as Map<String, dynamic>)).toList();
}

Future<List<MediaItem>> searchMedia(String query) async {
  final data = await _get('/search/multi', {
    'query': query,
    'include_adult': 'false',
    'page': '1',
  });
  final results = (data['results'] as List<dynamic>? ?? [])
      .where((r) {
        final type = (r as Map)['media_type'];
        return type == 'movie' || type == 'tv';
      })
      .map((r) => MediaItem.fromTmdbSearch(r as Map<String, dynamic>))
      .toList();
  return results;
}

Future<List<MediaItem>> discoverByLanguage(
  String langCode, {
  bool isTv = false,
  int page = 1,
}) async {
  final path = isTv ? '/discover/tv' : '/discover/movie';
  final data = await _get(path, {
    'with_original_language': langCode,
    'sort_by': 'popularity.desc',
    'page': '$page',
  });
  final results = (data['results'] as List<dynamic>? ?? []);
  return results.map((r) {
    return isTv
        ? MediaItem.fromTmdbTv(r as Map<String, dynamic>)
        : MediaItem.fromTmdbMovie(r as Map<String, dynamic>);
  }).toList();
}

Future<List<MediaItem>> discoverByGenre(
  int genreId, {
  bool isTv = false,
  int page = 1,
}) async {
  final path = isTv ? '/discover/tv' : '/discover/movie';
  final data = await _get(path, {
    'with_genres': '$genreId',
    'sort_by': 'popularity.desc',
    'page': '$page',
  });
  final results = (data['results'] as List<dynamic>? ?? []);
  return results.map((r) {
    return isTv
        ? MediaItem.fromTmdbTv(r as Map<String, dynamic>)
        : MediaItem.fromTmdbMovie(r as Map<String, dynamic>);
  }).toList();
}

/// Returns embed URLs for a movie.
///
/// Source priority:
///  1. vidlink.pro    — Primary; clean UI, multi-audio, no ads. (Keep this!)
///  2. vidsrc.in      — Fresh Vidsrc mirror; unblocked in India.
///  3. smashy.stream  — Great Indian regional aggregator.
///  4. vidsrc.pm      — Alternate premium proxy.
///  5. embed.su       — Stable, lightweight.
///  6. rive.stream    — Multi-server aggregator (good for regional content).
///  7. primewire       — Large regional + Hollywood database.
///  8. player.videasy.net — Clean embed, good regional coverage.
///  9. multiembed.mov / SuperEmbed — Multi-source aggregator.
/// 10. autoembed.cc   — Auto-selects best source.
/// 11. 2embed.cc      — Reliable TMDB-based embed.
/// 12. vidsrc.to      — Classic VidSrc mirror.
/// 13. vidsrc.me      — Another classic VidSrc mirror.
/// 14. vidsrc.cc      — Additional VidSrc fallback.
List<String> getMovieEmbedUrls(int tmdbId, {bool dubbed = false}) {
  return [
    // ── Keep first — works great for Hollywood ──
    'https://vidlink.pro/movie/$tmdbId?autoplay=true&primaryColor=FF6B35',
    // ── Existing reliable fallbacks ──
    'https://vidsrc.in/embed/movie/$tmdbId',
    'https://player.smashy.stream/movie/$tmdbId?tmdb=1',
    'https://vidsrc.pm/embed/movie/$tmdbId',
    'https://embed.su/embed/movie/$tmdbId',
    // ── Rive Mirrors ──
    'https://rivestream.net/embed?type=movie&id=$tmdbId',
    'https://rivestream.xyz/embed?type=movie&id=$tmdbId',
    'https://rive.icu/embed?type=movie&id=$tmdbId',
    // ── Fixed & New regional sources ──
    'https://primewire.tf/embed/movie/?tmdb=$tmdbId',
    'https://player.videasy.net/movie/$tmdbId',
    'https://multiembed.mov/directstream.php?video_id=$tmdbId&tmdb=1',
    'https://filmku.stream/embed/movie?tmdb=$tmdbId',
    'https://www.nontongo.win/embed/movie/$tmdbId',
    'https://autoembed.co/movie/tmdb/$tmdbId',
    'https://www.2embed.cc/embed/$tmdbId',
    'https://vidsrc.to/embed/movie/$tmdbId',
    'https://vidsrc.me/embed/movie?tmdb=$tmdbId',
    'https://vidsrc.cc/v2/embed/movie/$tmdbId',
  ];
}

/// Returns embed URLs for a TV episode.
/// Same priority as movies — keep first source, new regional fallbacks added.
List<String> getTvEmbedUrls(int tmdbId, int season, int episode,
    {bool dubbed = false}) {
  return [
    // ── Keep first — works great for Hollywood series ──
    'https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true&primaryColor=FF6B35',
    // ── Existing reliable fallbacks ──
    'https://vidsrc.in/embed/tv/$tmdbId/$season/$episode',
    'https://player.smashy.stream/tv/$tmdbId?s=$season&e=$episode',
    'https://vidsrc.pm/embed/tv/$tmdbId/$season/$episode',
    'https://embed.su/embed/tv/$tmdbId/$season/$episode',
    // ── Rive Mirrors ──
    'https://rivestream.net/embed?type=tv&id=$tmdbId&s=$season&e=$episode',
    'https://rivestream.xyz/embed?type=tv&id=$tmdbId&s=$season&e=$episode',
    'https://rive.icu/embed?type=tv&id=$tmdbId&s=$season&e=$episode',
    // ── Fixed & New regional sources ──
    'https://primewire.tf/embed/tv/?tmdb=$tmdbId&season=$season&episode=$episode',
    'https://player.videasy.net/tv/$tmdbId/$season/$episode',
    'https://multiembed.mov/directstream.php?video_id=$tmdbId&tmdb=1&s=$season&e=$episode',
    'https://filmku.stream/embed/tv?tmdb=$tmdbId&s=$season&e=$episode',
    'https://www.nontongo.win/embed/tv/$tmdbId/$season/$episode',
    'https://autoembed.co/tv/tmdb/$tmdbId/$season/$episode',
    'https://www.2embed.cc/embedtv/$tmdbId?s=$season&e=$episode',
    'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode',
    'https://vidsrc.me/embed/tv?tmdb=$tmdbId&s=$season&e=$episode',
    'https://vidsrc.cc/v2/embed/tv/$tmdbId/$season/$episode',
  ];
}

class TvEpisode {
  final int number;
  final String name;
  final String? overview;
  final String? stillPath;
  final double? rating;
  final String? airDate;

  const TvEpisode({
    required this.number,
    required this.name,
    this.overview,
    this.stillPath,
    this.rating,
    this.airDate,
  });

  factory TvEpisode.fromJson(Map<String, dynamic> j) => TvEpisode(
    number: j['episode_number'] ?? 0,
    name: (j['name'] ?? 'Episode ${j['episode_number']}').toString(),
    overview: j['overview']?.toString(),
    stillPath: j['still_path']?.toString(),
    rating: j['vote_average'] != null
        ? (j['vote_average'] as num).toDouble()
        : null,
    airDate: j['air_date']?.toString(),
  );

  String get image {
    if (stillPath == null || stillPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w300$stillPath';
  }
}
