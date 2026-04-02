

class Manga {
  final int id;
  final String title;
  final String image;
  final String? cover;
  final String? description;
  final String? format;
  final String? status;
  final double? rating;
  final int? chapters;
  final int? volumes;
  final List<String> genres;
  final int? year;
  final List<Manga>? recommendations;

  const Manga({
    required this.id,
    required this.title,
    required this.image,
    this.cover,
    this.description,
    this.format,
    this.status,
    this.rating,
    this.chapters,
    this.volumes,
    required this.genres,
    this.year,
    this.recommendations,
  });

  factory Manga.fromJson(Map<String, dynamic> m) {
    final t = m['title'] as Map<String, dynamic>? ?? {};
    final c = m['coverImage'] as Map<String, dynamic>? ?? {};
    return Manga(
      id: m['id'] ?? 0,
      title: (t['english'] ?? t['romaji'] ?? t['userPreferred'] ?? 'Unknown').toString(),
      image: (c['extraLarge'] ?? c['large'] ?? '').toString(),
      cover: m['bannerImage']?.toString(),
      description: m['description']?.toString().replaceAll(RegExp(r'<[^>]*>'), ''),
      format: m['format']?.toString(),
      status: _parseStatus(m['status']?.toString()),
      rating: m['averageScore'] != null ? (m['averageScore'] as num) / 10.0 : null,
      chapters: m['chapters'] as int?,
      volumes: m['volumes'] as int?,
      genres: List<String>.from(m['genres'] ?? []),
      year: (m['startDate'] as Map<String, dynamic>?)?['year'] as int?,
      recommendations: ((m['recommendations'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?)
          ?.map((n) => n['mediaRecommendation'])
          .where((r) => r != null)
          .map((r) => Manga.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  static String? _parseStatus(String? s) {
    switch (s) {
      case 'RELEASING': return 'Ongoing';
      case 'FINISHED': return 'Completed';
      case 'NOT_YET_RELEASED': return 'Upcoming';
      case 'CANCELLED': return 'Cancelled';
      case 'HIATUS': return 'Hiatus';
      default: return s;
    }
  }
}

class MangaChapter {
  final String id;
  final String title;
  final String chapterNumber;
  final String? volumeNumber;
  final DateTime? publishedAt;
  final String? externalUrl;
  final String? group;

  const MangaChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    this.volumeNumber,
    this.publishedAt,
    this.externalUrl,
    this.group,
  });
}

class MangaPage {
  final int index;
  final String imageUrl;

  const MangaPage({
    required this.index,
    required this.imageUrl,
  });
}

class MangaHomeData {
  final List<Manga> trending;
  final List<Manga> topManga;
  final List<Manga> popular;
  final List<Manga> recent;

  const MangaHomeData({
    required this.trending,
    required this.topManga,
    required this.popular,
    required this.recent,
  });
}
