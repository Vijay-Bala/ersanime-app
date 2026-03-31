import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';

const _url = 'https://graphql.anilist.co';

const _animeFields = '''
  id
  title { english romaji userPreferred }
  coverImage { extraLarge large }
  bannerImage
  description(asHtml: false)
  format
  status
  averageScore
  episodes
  genres
  startDate { year }
  nextAiringEpisode { episode airingAt timeUntilAiring }
''';

Future<Map<String, dynamic>> _gql(
  String query, [
  Map<String, dynamic>? variables,
]) async {
  final res = await http.post(
    Uri.parse(_url),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'query': query, 'variables': variables ?? {}}),
  );
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json['data'] as Map<String, dynamic>;
}

Future<AnimeHomeData> getAnimeHomeData() async {
  final data = await _gql('''
    query {
      trending: Page(page:1,perPage:15) {
        media(sort:TRENDING_DESC,type:ANIME,isAdult:false) { $_animeFields }
      }
      topAiring: Page(page:1,perPage:15) {
        media(sort:SCORE_DESC,type:ANIME,status:RELEASING,isAdult:false) { $_animeFields }
      }
      popular: Page(page:1,perPage:15) {
        media(sort:POPULARITY_DESC,type:ANIME,isAdult:false) { $_animeFields }
      }
      recent: Page(page:1,perPage:15) {
        media(sort:START_DATE_DESC,type:ANIME,status:RELEASING,isAdult:false) { $_animeFields }
      }
    }
  ''');
  return AnimeHomeData(
    trending: _mapList(data['trending']['media']),
    topAiring: _mapList(data['topAiring']['media']),
    popular: _mapList(data['popular']['media']),
    recent: _mapList(data['recent']['media']),
  );
}

Future<Anime> getAnimeDetail(int id) async {
  final data = await _gql(
    '''
    query(\$id:Int!) {
      Media(id:\$id,type:ANIME) {
        $_animeFields
        studios(isMain:true) { nodes { name } }
        recommendations(perPage:8) {
          nodes {
            mediaRecommendation {
              id
              title { english romaji userPreferred }
              coverImage { extraLarge large }
              format averageScore episodes
            }
          }
        }
      }
    }
  ''',
    {'id': id},
  );
  return Anime.fromJson(data['Media'] as Map<String, dynamic>);
}

Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
  final data = await _gql(
    '''
    query(\$search:String!,\$page:Int!) {
      Page(page:\$page,perPage:20) {
        media(search:\$search,type:ANIME,isAdult:false,sort:SEARCH_MATCH) { $_animeFields }
      }
    }
  ''',
    {'search': query, 'page': page},
  );
  return _mapList(data['Page']['media']);
}

Future<List<Anime>> searchByGenre(String genre, {int page = 1}) async {
  final data = await _gql(
    '''
    query(\$genre:String!,\$page:Int!) {
      Page(page:\$page,perPage:40) {
        media(genre:\$genre,type:ANIME,isAdult:false,sort:POPULARITY_DESC) { $_animeFields }
      }
    }
  ''',
    {'genre': genre, 'page': page},
  );
  return _mapList(data['Page']['media']);
}

Future<List<Episode>> getEpisodes(Anime anime) async {
  final knownTotal = anime.episodes;

  if (knownTotal != null && knownTotal > 0) {
    return _generateEpisodes(knownTotal, anime.title);
  }

  if (anime.nextAiringEpisode != null) {
    final airedCount = anime.nextAiringEpisode!.episode - 1;
    if (airedCount > 0) {
      return _generateEpisodes(airedCount, anime.title);
    }
  }

  try {
    final data = await _gql(
      '''
      query(\$id:Int!) {
        Media(id:\$id,type:ANIME) {
          episodes
          nextAiringEpisode { episode }
        }
      }
    ''',
      {'id': anime.id},
    );

    final media = data['Media'] as Map<String, dynamic>?;
    if (media != null) {
      final fetchedTotal = media['episodes'] as int?;
      if (fetchedTotal != null && fetchedTotal > 0) {
        return _generateEpisodes(fetchedTotal, anime.title);
      }
      final nextEp =
          (media['nextAiringEpisode'] as Map<String, dynamic>?)?['episode']
              as int?;
      if (nextEp != null && nextEp > 1) {
        return _generateEpisodes(nextEp - 1, anime.title);
      }
    }
  } catch (_) {}

  return [];
}

List<Episode> _generateEpisodes(int count, String title) {
  final slug = _toSlug(title);
  return List.generate(
    count,
    (i) => Episode(id: '$slug-episode-${i + 1}', number: i + 1),
  );
}

const _vidnestServers = [
  '',
  'sigma',
  'alfa',
  'beta',
  'gama',
  'hexa',
  'delta',
  'lamda',
];

List<String> getAnimeEmbedUrls(int anilistId, int episode, {bool dub = false}) {
  final sub = dub ? 'dub' : 'sub';
  return [
    for (final srv in _vidnestServers)
      'https://vidnest.fun/animepahe/$anilistId/$episode/$sub${srv.isEmpty ? '' : '?server=$srv'}',
    for (final srv in ['', 'sigma', 'alfa'])
      'https://vidnest.fun/anime/$anilistId/$episode/$sub${srv.isEmpty ? '' : '?server=$srv'}',
    for (final srv in ['', 'sigma', 'alfa'])
      'https://nhdapi.xyz/animepahe/$anilistId/$episode/$sub${srv.isEmpty ? '' : '?server=$srv'}',
  ];
}

List<Anime> _mapList(dynamic list) => (list as List<dynamic>? ?? [])
    .map((m) => Anime.fromJson(m as Map<String, dynamic>))
    .toList();

String _toSlug(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r"'s "), 's ')
    .replaceAll(RegExp(r"'s"), 's')
    .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');
