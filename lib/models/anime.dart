class NextAiringEpisode {
  final int episode;
  final int airingAt;
  final int timeUntilAiring;

  const NextAiringEpisode({
    required this.episode,
    required this.airingAt,
    required this.timeUntilAiring,
  });

  factory NextAiringEpisode.fromJson(Map<String, dynamic> j) => NextAiringEpisode(
    episode: j['episode'] ?? 0,
    airingAt: j['airingAt'] ?? 0,
    timeUntilAiring: j['timeUntilAiring'] ?? 0,
  );
}

class Anime {
  final int id;
  final String title;
  final String image;
  final String? cover;
  final String? description;
  final String? format;
  final String? status;
  final double? rating;
  final int? episodes;
  final List<String> genres;
  final int? year;
  final List<String>? studios;
  final List<Anime>? recommendations;
  final NextAiringEpisode? nextAiringEpisode;

  const Anime({
    required this.id,
    required this.title,
    required this.image,
    this.cover,
    this.description,
    this.format,
    this.status,
    this.rating,
    this.episodes,
    required this.genres,
    this.year,
    this.studios,
    this.recommendations,
    this.nextAiringEpisode,
  });

  factory Anime.fromJson(Map<String, dynamic> m) {
    final t = m['title'] as Map<String, dynamic>? ?? {};
    final c = m['coverImage'] as Map<String, dynamic>? ?? {};
    return Anime(
      id: m['id'] ?? 0,
      title: (t['english'] ?? t['romaji'] ?? t['userPreferred'] ?? 'Unknown').toString(),
      image: (c['extraLarge'] ?? c['large'] ?? '').toString(),
      cover: m['bannerImage']?.toString(),
      description: m['description']?.toString().replaceAll(RegExp(r'<[^>]*>'), ''),
      format: m['format']?.toString(),
      status: _parseStatus(m['status']?.toString()),
      rating: m['averageScore'] != null ? (m['averageScore'] as num) / 10.0 : null,
      episodes: m['episodes'] as int?,
      genres: List<String>.from(m['genres'] ?? []),
      year: (m['startDate'] as Map<String, dynamic>?)?['year'] as int?,
      studios: ((m['studios'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?)
          ?.map((n) => n['name'].toString())
          .toList(),
      nextAiringEpisode: m['nextAiringEpisode'] != null
          ? NextAiringEpisode.fromJson(m['nextAiringEpisode'])
          : null,
      recommendations: ((m['recommendations'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?)
          ?.map((n) => n['mediaRecommendation'])
          .where((r) => r != null)
          .map((r) => Anime.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  static String? _parseStatus(String? s) {
    switch (s) {
      case 'RELEASING': return 'Ongoing';
      case 'FINISHED': return 'Completed';
      case 'NOT_YET_RELEASED': return 'Upcoming';
      default: return s;
    }
  }
}

class Episode {
  final String id;
  final int number;
  final String? title;
  final bool isFiller;
  final int? airingAt;

  const Episode({
    required this.id,
    required this.number,
    this.title,
    this.isFiller = false,
    this.airingAt,
  });
}

class HomeData {
  final List<Anime> trending;
  final List<Anime> topAiring;
  final List<Anime> popular;
  final List<Anime> recent;

  const HomeData({
    required this.trending,
    required this.topAiring,
    required this.popular,
    required this.recent,
  });
}
