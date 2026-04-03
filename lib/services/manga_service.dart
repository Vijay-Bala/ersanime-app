import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/manga.dart';

/// MangaService — Reliable chapter aggregator
/// Primary Source: MangaPill (No Cloudflare, 100% native chapters for One Piece, etc.)
/// Secondary Fallback: MangaDex (GraphQL-based API)
class MangaService {
  static const _mpBase = 'https://mangapill.com';
  static const _mpHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  static const _dxBase = 'https://api.mangadex.org';
  static const _dxHeaders = {
    'User-Agent': 'ERSA-App/1.0 (Flutter; Android)',
    'Accept': 'application/json',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static String _normalizeKey(String raw) {
    final stripped = raw
        .replaceAll(RegExp(r'chapter\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'ch\.?\s*', caseSensitive: false), '')
        .trim();
    final d = double.tryParse(stripped);
    if (d == null) return raw.toLowerCase().trim();
    return d == d.floorToDouble() ? '${d.toInt()}.0' : d.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOURCE 1: MANGAPILL (Primary, Native Images, No Cloudflare)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String?> _findMangaPillRoute(String title) async {
    debugPrint('[MANGA] MangaPill: Searching for "$title"');
    try {
      final query = Uri.encodeComponent(title);
      final res = await http.get(
        Uri.parse('$_mpBase/search?q=$query'),
        headers: _mpHeaders,
      ).timeout(const Duration(seconds: 15));
      debugPrint('[MANGA] MangaPill search response: ${res.statusCode}');

      if (res.statusCode != 200) return null;

      // Extract first manga link: href="/manga/2/one-piece"
      final match = RegExp(r'href="(/manga/[^"]+)"').firstMatch(res.body);
      if (match != null) {
        final route = match.group(1)!;
        debugPrint('[MANGA] ✅ Found MangaPill route: $route');
        return route;
      }
      debugPrint('[MANGA] ❌ MangaPill search found no results');
      return null;
    } catch (e, st) {
      debugPrint('[MANGA] MangaPill exception: $e\n$st');
      return null;
    }
  }

  static Future<List<MangaChapter>> _getMangaPillChapters(String route, String mangaTitle) async {
    debugPrint('[MANGA] Fetching MangaPill chapters for route: $route');
    try {
      final res = await http.get(
        Uri.parse('$_mpBase$route'),
        headers: _mpHeaders,
      ).timeout(const Duration(seconds: 15));

      debugPrint('[MANGA] MangaPill chapter list response: ${res.statusCode}');
      if (res.statusCode != 200) return [];

      // Extract chapter links: href="/chapters/2-10000000/one-piece-chapter-100"
      // the chapter number is usually at the end, but we can also extract text from the anchor tag
      final matches = RegExp(r'<a[^>]+href="(/chapters/[^"]+)"[^>]*>(.*?)</a>')
          .allMatches(res.body);

      debugPrint('[MANGA] MangaPill matched ${matches.length} chapter anchors');
      final List<MangaChapter> chapters = [];

      for (final match in matches) {
        final chapRoute = match.group(1)!;
        final rawTitle = match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        // Extract chapter number from title (e.g., "Chapter 101" or "Chapter 1117.9")
        String chapNum = '';
        final chapMatch = RegExp(r'chapter\s+([0-9.]+|[0-9]+-[0-9]+)', caseSensitive: false).firstMatch(rawTitle);
        if (chapMatch != null) {
          chapNum = chapMatch.group(1)!;
        } else {
          // If no "Chapter X" in text, try to extract last number from url route
          final urlNumMatch = RegExp(r'-([0-9.]+)$').firstMatch(chapRoute);
          if (urlNumMatch != null) {
            chapNum = urlNumMatch.group(1)!;
          } else {
            chapNum = chapters.length.toString(); // Fallback
          }
        }

        chapters.add(MangaChapter(
          id: 'mangapill|$chapRoute',
          title: rawTitle.isNotEmpty ? rawTitle : 'Chapter $chapNum',
          chapterNumber: chapNum,
          group: 'MangaPill',
        ));
      }

      debugPrint('[MANGA] Total MangaPill chapters collected: ${chapters.length}');
      return chapters;
    } catch (e, st) {
      debugPrint('[MANGA] MangaPill chapter fetch exception: $e\n$st');
      return [];
    }
  }

  static Future<List<MangaPage>> _getMangaPillPages(String chapterRoute) async {
    debugPrint('[MANGA] Fetching MangaPill pages for: $chapterRoute');
    try {
      final res = await http.get(
        Uri.parse('$_mpBase$chapterRoute'),
        headers: _mpHeaders,
      ).timeout(const Duration(seconds: 20));

      debugPrint('[MANGA] MangaPill pages response: ${res.statusCode}');
      if (res.statusCode != 200) return [];

      // Extract image data-src tags
      final matches = RegExp(r'<img[^>]+data-src="([^"]+)"').allMatches(res.body);
      debugPrint('[MANGA] MangaPill found ${matches.length} raw images');

      final List<MangaPage> pages = [];
      int idx = 0;
      for (final match in matches) {
        final imgUrl = match.group(1)!;
        pages.add(MangaPage(index: idx++, imageUrl: imgUrl));
      }
      return pages;
    } catch (e, st) {
      debugPrint('[MANGA] MangaPill pages exception: $e\n$st');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOURCE 2: MANGADEX (Secondary Fallback)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String?> _findMangaDexId(Manga manga) async {
    debugPrint('[MANGA] MangaDex: Searching | AniList:${manga.id} | MAL:${manga.idMal}');
    if (manga.idMal != null) {
      final id = await _fetchDxByMalId(manga.idMal!);
      if (id != null) return id;
    }
    final byAl = await _fetchDxByAniListId(manga.id);
    if (byAl != null) return byAl;
    return _fetchDxByTitle(manga.title);
  }

  static Future<String?> _fetchDxByMalId(int malId) async {
    final url = '$_dxBase/manga?links[mal]=$malId&limit=5&order[relevance]=desc';
    try {
      final res = await http.get(Uri.parse(url), headers: _dxHeaders).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final results = jsonDecode(res.body)['data'] as List? ?? [];
      return results.isNotEmpty ? results[0]['id'] as String? : null;
    } catch (_) { return null; }
  }

  static Future<String?> _fetchDxByAniListId(int alId) async {
    final url = '$_dxBase/manga?links[al]=$alId&limit=5&order[relevance]=desc';
    try {
      final res = await http.get(Uri.parse(url), headers: _dxHeaders).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final results = jsonDecode(res.body)['data'] as List? ?? [];
      return results.isNotEmpty ? results[0]['id'] as String? : null;
    } catch (_) { return null; }
  }

  static Future<String?> _fetchDxByTitle(String title) async {
    final url = '$_dxBase/manga?title=${Uri.encodeComponent(title)}&limit=5&order[relevance]=desc';
    try {
      final res = await http.get(Uri.parse(url), headers: _dxHeaders).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final results = jsonDecode(res.body)['data'] as List? ?? [];
      return results.isNotEmpty ? results[0]['id'] as String? : null;
    } catch (_) { return null; }
  }

  static Future<List<MangaChapter>> _getMangaDexChapters(String mangaDexId) async {
    debugPrint('[MANGA] Fetching MangaDex chapters for ID: $mangaDexId');
    try {
      final countRes = await http.get(
        Uri.parse('$_dxBase/manga/$mangaDexId/feed?translatedLanguage[]=en&limit=1&offset=0&order[chapter]=asc'),
        headers: _dxHeaders,
      ).timeout(const Duration(seconds: 15));
      
      if (countRes.statusCode != 200) return [];
      final totalCount = jsonDecode(countRes.body)['total'] as int? ?? 0;
      if (totalCount == 0) return [];

      final pageCount = (totalCount / 500).ceil().clamp(1, 40);
      final futures = List.generate(pageCount, (i) {
        return http.get(
          Uri.parse('$_dxBase/manga/$mangaDexId/feed?translatedLanguage[]=en&limit=500&offset=${i * 500}&order[chapter]=asc'),
          headers: _dxHeaders,
        ).timeout(const Duration(seconds: 30));
      });
      
      final responses = await Future.wait(futures);
      final List<MangaChapter> allChapters = [];
      
      for (final res in responses) {
        if (res.statusCode != 200) continue;
        final chapData = (jsonDecode(res.body)['data'] as List?) ?? [];
        for (final c in chapData) {
          final attrs = c['attributes'] as Map<String, dynamic>;
          final chapNum = attrs['chapter']?.toString();
          if (chapNum == null || chapNum.isEmpty) continue;

          final externalUrl = attrs['externalUrl']?.toString();
          final pages = attrs['pages'] as int? ?? 0;

          if (externalUrl == null && pages == 0) continue;

          final rawTitle = attrs['title']?.toString() ?? '';
          final chapterId = externalUrl != null
              ? 'mangadex-ext|${c['id']}|${Uri.encodeComponent(externalUrl)}'
              : 'mangadex|${c['id']}';

          allChapters.add(MangaChapter(
            id: chapterId,
            title: rawTitle.isNotEmpty ? rawTitle : 'Chapter $chapNum',
            chapterNumber: chapNum,
            volumeNumber: attrs['volume']?.toString(),
            publishedAt: attrs['publishAt'] != null ? DateTime.tryParse(attrs['publishAt'].toString()) : null,
            group: externalUrl != null ? 'MangaPlus / Viz' : 'MangaDex',
          ));
        }
      }
      debugPrint('[MANGA] Total MangaDex chapters collected: ${allChapters.length}');
      return allChapters;
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaPage>> _getMangaDexPages(String chapterId) async {
    try {
      final id = chapterId.split('|')[1];
      final res = await http.get(Uri.parse('$_dxBase/at-home/server/$id'), headers: _dxHeaders).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final baseUrl = data['baseUrl']?.toString() ?? '';
      final hash = data['chapter']?['hash']?.toString() ?? '';
      final dataArray = data['chapter']?['data'] as List? ?? [];
      return dataArray.asMap().entries.map((e) => MangaPage(index: e.key, imageUrl: '$baseUrl/data/$hash/${e.value}')).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<MangaChapter>> fetchAvailableChapters(Manga manga) async {
    debugPrint('[MANGA] ═══════════════════════════════════════════');
    debugPrint('[MANGA] fetchAvailableChapters("${manga.title}")');
    debugPrint('[MANGA] ═══════════════════════════════════════════');

    final List<MangaChapter> chapters = [];

    // Priority 1: MangaPill
    final pillRoute = await _findMangaPillRoute(manga.title);
    if (pillRoute != null) {
      chapters.addAll(await _getMangaPillChapters(pillRoute, manga.title));
    }

    // Priority 2: MangaDex (if no MangaPill chapters found, or just to supplement)
    if (chapters.isEmpty) {
      final dxId = await _findMangaDexId(manga);
      if (dxId != null) {
        chapters.addAll(await _getMangaDexChapters(dxId));
      }
    }

    if (chapters.isEmpty) {
      debugPrint('[MANGA] ❌ No chapters found from any source.');
      return [];
    }

    // Deduplicate
    final Map<String, MangaChapter> dedupMap = {};
    for (final ch in chapters) {
      final key = _normalizeKey(ch.chapterNumber);
      final existing = dedupMap[key];
      if (existing == null) {
        dedupMap[key] = ch;
      } else {
        // Prefer native over external
        final chIsNative = !ch.id.startsWith('mangadex-ext|');
        final existingIsNative = !existing.id.startsWith('mangadex-ext|');
        if (chIsNative && !existingIsNative) dedupMap[key] = ch;
      }
    }

    final result = dedupMap.values.toList()
      ..sort((a, b) {
        final aNum = double.tryParse(a.chapterNumber) ?? 0.0;
        final bNum = double.tryParse(b.chapterNumber) ?? 0.0;
        return bNum.compareTo(aNum);
      });

    debugPrint('[MANGA] ✅ Final chapter count: ${result.length}');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXTERNAL CHAPTER HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static bool isExternalChapter(String chapterId) => chapterId.startsWith('mangadex-ext|');

  static String? getExternalUrl(String chapterId) {
    if (!isExternalChapter(chapterId)) return null;
    final parts = chapterId.split('|');
    return parts.length >= 3 ? Uri.decodeComponent(parts[2]) : null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE FETCHING ROUTER
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<MangaPage>> fetchChapterPages(String chapterId) async {
    debugPrint('[MANGA] fetchChapterPages: $chapterId');
    if (chapterId.startsWith('mangapill|')) {
      final route = chapterId.substring('mangapill|'.length);
      return _getMangaPillPages(route);
    }
    if (chapterId.startsWith('mangadex|')) {
      return _getMangaDexPages(chapterId);
    }
    return [];
  }
}
