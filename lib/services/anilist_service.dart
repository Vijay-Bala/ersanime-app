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

Future<Map<String, dynamic>> _gql(String query, [Map<String, dynamic>? variables]) async {
  final res = await http.post(
    Uri.parse(_url),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'query': query, 'variables': variables ?? {}}),
  );
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json['data'] as Map<String, dynamic>;
}

// ── Home ──────────────────────────────────────────────────────────────────────

Future<HomeData> getHomeData() async {
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
  return HomeData(
    trending: _mapList(data['trending']['media']),
    topAiring: _mapList(data['topAiring']['media']),
    popular: _mapList(data['popular']['media']),
    recent: _mapList(data['recent']['media']),
  );
}

// ── Detail ────────────────────────────────────────────────────────────────────

Future<Anime> getAnimeDetail(int id) async {
  final data = await _gql('''
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
  ''', {'id': id});
  return Anime.fromJson(data['Media'] as Map<String, dynamic>);
}

// ── Search ────────────────────────────────────────────────────────────────────

Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
  final data = await _gql('''
    query(\$search:String!,\$page:Int!) {
      Page(page:\$page,perPage:20) {
        media(search:\$search,type:ANIME,isAdult:false,sort:SEARCH_MATCH) { $_animeFields }
      }
    }
  ''', {'search': query, 'page': page});
  return _mapList(data['Page']['media']);
}

Future<List<Anime>> searchByGenre(String genre, {int page = 1}) async {
  final data = await _gql('''
    query(\$genre:String!,\$page:Int!) {
      Page(page:\$page,perPage:40) {
        media(genre:\$genre,type:ANIME,isAdult:false,sort:POPULARITY_DESC) { $_animeFields }
      }
    }
  ''', {'genre': genre, 'page': page});
  return _mapList(data['Page']['media']);
}

// ── Episodes ──────────────────────────────────────────────────────────────────

Future<List<Episode>> getEpisodes(Anime anime) async {
  try {
    final data = await _gql('''
      query(\$id:Int!) {
        Media(id:\$id,type:ANIME) {
          episodes
          airingSchedule(notYetAired:false, perPage:150) {
            nodes { episode airingAt }
          }
        }
      }
    ''', {'id': anime.id});

    final media = data['Media'] as Map<String, dynamic>?;
    if (media == null) return _fallbackEpisodes(anime);

    final aired = (media['airingSchedule']?['nodes'] as List<dynamic>?) ?? [];
    final slug = _toSlug(anime.title);

    if (aired.isNotEmpty) {
      final sorted = aired
          .map((e) => e as Map<String, dynamic>)
          .where((e) => (e['episode'] as int) >= 1)
          .toList()
        ..sort((a, b) => (a['episode'] as int).compareTo(b['episode'] as int));
      return sorted.map((e) => Episode(
        id: '$slug-episode-${e['episode']}',
        number: e['episode'] as int,
        airingAt: e['airingAt'] as int?,
      )).toList();
    }
    return _fallbackEpisodes(anime);
  } catch (_) {
    return _fallbackEpisodes(anime);
  }
}

List<Episode> _fallbackEpisodes(Anime anime) {
  final count = anime.episodes;
  if (count == null || count <= 0) return [];
  final slug = _toSlug(anime.title);
  return List.generate(count, (i) => Episode(
    id: '$slug-episode-${i + 1}',
    number: i + 1,
  ));
}

// ── Embed URLs (VidNest servers) ──────────────────────────────────────────────

const _vidnestServers = ['', 'sigma', 'alfa', 'beta', 'gama', 'hexa', 'delta', 'lamda'];

List<String> getEmbedUrls(int anilistId, int episode, {bool dub = false}) {
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

// ── Helpers ───────────────────────────────────────────────────────────────────

List<Anime> _mapList(dynamic list) =>
    (list as List<dynamic>? ?? []).map((m) => Anime.fromJson(m as Map<String, dynamic>)).toList();

String _toSlug(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r"'s "), 's ')
    .replaceAll(RegExp(r"'s"), 's')
    .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');
