class MediaItem {
  final int id;
  final String title;
  final String image;
  final String? cover;
  final String? description;
  final bool isSeries;
  final double? rating;
  final int? year;
  final int? runtime;
  final List<String> genres;
  final String? status;
  final String? originalLanguage;
  final int? totalSeasons;
  final List<TvSeason>? seasons;
  final List<MediaItem>? recommendations;

  const MediaItem({
    required this.id,
    required this.title,
    required this.image,
    this.cover,
    this.description,
    required this.isSeries,
    this.rating,
    this.year,
    this.runtime,
    required this.genres,
    this.status,
    this.originalLanguage,
    this.totalSeasons,
    this.seasons,
    this.recommendations,
  });

  factory MediaItem.fromTmdbMovie(Map<String, dynamic> m) {
    return MediaItem(
      id: m['id'] ?? 0,
      title: (m['title'] ?? m['original_title'] ?? 'Unknown').toString(),
      image: _img(m['poster_path']?.toString()),
      cover: _img(m['backdrop_path']?.toString()),
      description: m['overview']?.toString(),
      isSeries: false,
      rating: m['vote_average'] != null
          ? (m['vote_average'] as num).toDouble()
          : null,
      year: _parseYear(m['release_date']?.toString()),
      runtime: m['runtime'] as int?,
      genres: _parseGenres(m),
      status: m['status']?.toString(),
      originalLanguage: m['original_language']?.toString(),
      recommendations: _parseRecommendations(m, false),
    );
  }

  factory MediaItem.fromTmdbTv(Map<String, dynamic> m) {
    final seasons = (m['seasons'] as List<dynamic>?)
        ?.map((s) => TvSeason.fromJson(s as Map<String, dynamic>))
        .where((s) => s.seasonNumber > 0)
        .toList();

    return MediaItem(
      id: m['id'] ?? 0,
      title: (m['name'] ?? m['original_name'] ?? 'Unknown').toString(),
      image: _img(m['poster_path']?.toString()),
      cover: _img(m['backdrop_path']?.toString()),
      description: m['overview']?.toString(),
      isSeries: true,
      rating: m['vote_average'] != null
          ? (m['vote_average'] as num).toDouble()
          : null,
      year: _parseYear((m['first_air_date'] ?? m['release_date'])?.toString()),
      genres: _parseGenres(m),
      status: m['status']?.toString(),
      originalLanguage: m['original_language']?.toString(),
      totalSeasons: m['number_of_seasons'] as int?,
      seasons: seasons,
      recommendations: _parseRecommendations(m, true),
    );
  }

  factory MediaItem.fromTmdbSearch(Map<String, dynamic> m) {
    final isTv = m['media_type'] == 'tv' || m['name'] != null;
    return MediaItem(
      id: m['id'] ?? 0,
      title:
          (m['title'] ??
                  m['name'] ??
                  m['original_title'] ??
                  m['original_name'] ??
                  'Unknown')
              .toString(),
      image: _img(m['poster_path']?.toString()),
      cover: _img(m['backdrop_path']?.toString()),
      description: m['overview']?.toString(),
      isSeries: isTv,
      rating: m['vote_average'] != null
          ? (m['vote_average'] as num).toDouble()
          : null,
      year: _parseYear((m['release_date'] ?? m['first_air_date'])?.toString()),
      genres: [],
      originalLanguage: m['original_language']?.toString(),
    );
  }

  static String _img(String? path) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  static int? _parseYear(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  static List<String> _parseGenres(Map<String, dynamic> m) {
    final genres = m['genres'] as List<dynamic>?;
    if (genres != null) {
      return genres.map((g) => (g as Map)['name'].toString()).toList();
    }
    final ids = m['genre_ids'] as List<dynamic>?;
    if (ids != null) {
      return ids
          .map((id) => _genreIdToName(id as int))
          .where((g) => g.isNotEmpty)
          .toList();
    }
    return [];
  }

  static List<MediaItem>? _parseRecommendations(
    Map<String, dynamic> m,
    bool isTv,
  ) {
    final recs =
        (m['recommendations'] as Map<String, dynamic>?)?['results']
            as List<dynamic>?;
    return recs?.map((r) {
      final item = r as Map<String, dynamic>;
      return MediaItem(
        id: item['id'] ?? 0,
        title: (item['title'] ?? item['name'] ?? 'Unknown').toString(),
        image: _img(item['poster_path']?.toString()),
        isSeries: isTv,
        genres: [],
        year: _parseYear(
          (item['release_date'] ?? item['first_air_date'])?.toString(),
        ),
        rating: item['vote_average'] != null
            ? (item['vote_average'] as num).toDouble()
            : null,
      );
    }).toList();
  }

  static String _genreIdToName(int id) {
    const map = {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Sci-Fi',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
      10759: 'Action & Adventure',
      10762: 'Kids',
      10763: 'News',
      10764: 'Reality',
      10765: 'Sci-Fi & Fantasy',
      10766: 'Soap',
      10767: 'Talk',
      10768: 'War & Politics',
    };
    return map[id] ?? '';
  }
}

class TvSeason {
  final int seasonNumber;
  final int episodeCount;
  final String? name;
  final String? posterPath;
  final String? airDate;

  const TvSeason({
    required this.seasonNumber,
    required this.episodeCount,
    this.name,
    this.posterPath,
    this.airDate,
  });

  factory TvSeason.fromJson(Map<String, dynamic> j) => TvSeason(
    seasonNumber: j['season_number'] ?? 0,
    episodeCount: j['episode_count'] ?? 0,
    name: j['name']?.toString(),
    posterPath: j['poster_path']?.toString(),
    airDate: j['air_date']?.toString(),
  );

  String get image {
    if (posterPath == null || posterPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w300$posterPath';
  }
}

class MediaHomeData {
  final List<MediaItem> trendingMovies;
  final List<MediaItem> trendingSeries;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> topRatedSeries;
  final List<MediaItem> bollywood;
  final List<MediaItem> korean;
  final List<MediaItem> tamil;
  final List<MediaItem> malayalam;
  final List<MediaItem> japanese;
  final List<MediaItem> chinese;
  final List<MediaItem> telugu;

  const MediaHomeData({
    required this.trendingMovies,
    required this.trendingSeries,
    required this.topRatedMovies,
    required this.topRatedSeries,
    required this.bollywood,
    required this.korean,
    required this.tamil,
    required this.malayalam,
    required this.japanese,
    required this.chinese,
    required this.telugu,
  });
}
