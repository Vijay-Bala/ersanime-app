import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';

class MangaService {
  // ===========================================================================
  // 1. COMICK API (Primary: Fast, high-quality, JSON)
  // ===========================================================================
  static Future<List<MangaChapter>> getComicKChapters(String title) async {
    try {
      final searchRes = await http.get(Uri.parse(
          'https://api.comick.app/v1.0/search?q=${Uri.encodeComponent(title)}&limit=1'));
      if (searchRes.statusCode != 200) return [];
      final searchJson = jsonDecode(searchRes.body) as List;
      if (searchJson.isEmpty) return [];

      final hid = searchJson[0]['hid'];
      final chapRes = await http.get(Uri.parse(
          'https://api.comick.app/comic/$hid/chapters?lang=en&limit=500'));
      if (chapRes.statusCode != 200) return [];

      final chapData = jsonDecode(chapRes.body);
      final chapters = chapData['chapters'] as List;

      return chapters.map((c) {
        return MangaChapter(
          id: 'comick|${c['hid']}',
          title: c['title'] ?? 'Chapter ${c['chap']}',
          chapterNumber: c['chap'] ?? '0',
          volumeNumber: c['vol'],
          publishedAt: c['created_at'] != null ? DateTime.parse(c['created_at']) : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaPage>> getComicKPages(String chapterId) async {
    try {
      final hid = chapterId.split('|')[1];
      final res = await http.get(Uri.parse('https://api.comick.app/chapter/$hid'));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final images = data['chapter']['md_images'] as List;

      return images.asMap().entries.map((e) {
        return MangaPage(
          index: e.key,
          imageUrl: 'https://meo.comick.pictures/${e.value['b2key']}',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // 2. MANGADEX API (Secondary: Huge library, strict JSON)
  // ===========================================================================
  static Future<List<MangaChapter>> getMangaDexChapters(String title) async {
    try {
      final searchRes = await http.get(Uri.parse(
          'https://api.mangadex.org/manga?title=${Uri.encodeComponent(title)}&limit=1&order[relevance]=desc'));
      if (searchRes.statusCode != 200) return [];
      final searchJson = jsonDecode(searchRes.body);
      if (searchJson['data'].isEmpty) return [];

      final mangaId = searchJson['data'][0]['id'];
      final chapRes = await http.get(Uri.parse(
          'https://api.mangadex.org/manga/$mangaId/feed?translatedLanguage[]=en&limit=500&order[chapter]=desc'));
      if (chapRes.statusCode != 200) return [];

      final chapData = jsonDecode(chapRes.body)['data'] as List;
      return chapData.map((c) {
        return MangaChapter(
          id: 'mangadex|${c['id']}',
          title: c['attributes']['title'] ?? 'Chapter ${c['attributes']['chapter']}',
          chapterNumber: c['attributes']['chapter'] ?? '0',
          volumeNumber: c['attributes']['volume'],
          publishedAt: c['attributes']['publishAt'] != null ? DateTime.parse(c['attributes']['publishAt']) : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaPage>> getMangaDexPages(String chapterId) async {
    try {
      final id = chapterId.split('|')[1];
      final res = await http.get(Uri.parse('https://api.mangadex.org/at-home/server/$id'));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final baseUrl = data['baseUrl'];
      final hash = data['chapter']['hash'];
      final dataArray = data['chapter']['data'] as List;

      return dataArray.asMap().entries.map((e) {
        return MangaPage(
          index: e.key,
          imageUrl: '$baseUrl/data/$hash/${e.value}',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // 3 & 4. CONSUMET MULTI-PROVIDER FALLBACKS (MangaKakalot, MangaHere)
  // ===========================================================================
  static const _consumetUrl = 'https://api-consumet-org-taupe.vercel.app/meta/anilist-manga';

  static Future<List<MangaChapter>> getConsumetChapters(int anilistId, String provider) async {
    try {
      final res = await http.get(Uri.parse('$_consumetUrl/$anilistId?provider=$provider'));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final chapters = data['chapters'] as List;

      return chapters.map((c) {
        return MangaChapter(
          id: 'consumet|$provider|${c['id']}|$anilistId',
          title: c['title']?.toString() ?? 'Chapter',
          chapterNumber: c['chapterNumber']?.toString() ?? '0',
          volumeNumber: c['volumeNumber']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaPage>> getConsumetPages(String encodedId) async {
    try {
      final parts = encodedId.split('|');
      final provider = parts[1];
      final chapterId = parts[2];
      final anilistId = parts[3];

      final res = await http.get(Uri.parse('$_consumetUrl/read?chapterId=$chapterId&provider=$provider&mangaId=$anilistId'));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as List;
      return data.map((p) {
        return MangaPage(
          index: p['page'] ?? 0,
          imageUrl: p['img'] ?? p['url'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // UNIFIED FETCHING LOGIC (With 5 fallback strategies)
  // ===========================================================================
  static Future<List<MangaChapter>> _getComicKChaptersPaged(String title) async {
    try {
      final searchRes = await http.get(Uri.parse(
          'https://api.comick.app/v1.0/search?q=${Uri.encodeComponent(title)}&limit=1'));
      if (searchRes.statusCode != 200) return [];
      final searchJson = jsonDecode(searchRes.body) as List;
      if (searchJson.isEmpty) return [];

      final hid = searchJson[0]['hid'];
      final List<MangaChapter> allChapters = [];
      int page = 1;
      bool hasMore = true;

      // Recursive loop to fetch ALL chapters (exhaust every group)
      while (hasMore && page <= 25) { // Safety cap at 2500 entries
        final chapRes = await http.get(Uri.parse(
            'https://api.comick.app/comic/$hid/chapters?lang=en&limit=100&page=$page'));
        if (chapRes.statusCode != 200) break;

        final data = jsonDecode(chapRes.body);
        final chapters = data['chapters'] as List;
        if (chapters.isEmpty) break;

        for (var c in chapters) {
          final groupTitle = (c['md_groups'] as List?)?.isNotEmpty == true 
              ? c['md_groups'][0]['title']?.toString() : null;
          allChapters.add(MangaChapter(
            id: 'comick|${c['hid']}',
            title: c['title'] ?? 'Chapter ${c['chap']}',
            chapterNumber: c['chap']?.toString() ?? '0',
            volumeNumber: c['vol'],
            publishedAt: c['created_at'] != null ? DateTime.parse(c['created_at']) : null,
            group: groupTitle,
          ));
        }
        
        if (chapters.length < 100) hasMore = false;
        page++;
      }
      return allChapters;
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaChapter>> _getMangaDexChaptersPaged(String title) async {
    try {
      final searchRes = await http.get(Uri.parse(
          'https://api.mangadex.org/manga?title=${Uri.encodeComponent(title)}&limit=1&order[relevance]=desc'));
      if (searchRes.statusCode != 200) return [];
      final searchJson = jsonDecode(searchRes.body);
      if (searchJson['data'].isEmpty) return [];

      final mangaId = searchJson['data'][0]['id'];
      final List<MangaChapter> allChapters = [];
      int offset = 0;
      int total = 1;

      while (offset < total && offset < 2000) {
        final chapRes = await http.get(Uri.parse(
            'https://api.mangadex.org/manga/$mangaId/feed?translatedLanguage[]=en&limit=100&offset=$offset&order[chapter]=desc'));
        if (chapRes.statusCode != 200) break;

        final data = jsonDecode(chapRes.body);
        total = data['total'] ?? 0;
        final chapData = data['data'] as List;
        if (chapData.isEmpty) break;

        for (var c in chapData) {
          allChapters.add(MangaChapter(
            id: 'mangadex|${c['id']}',
            title: c['attributes']['title'] ?? 'Chapter ${c['attributes']['chapter']}',
            chapterNumber: c['attributes']['chapter']?.toString() ?? '0',
            volumeNumber: c['attributes']['volume'],
            publishedAt: c['attributes']['publishAt'] != null ? DateTime.parse(c['attributes']['publishAt']) : null,
            group: 'MangaDex',
          ));
        }
        offset += 100;
      }
      return allChapters;
    } catch (_) {
      return [];
    }
  }

  static Future<List<MangaChapter>> fetchAvailableChapters(Manga manga) async {
    final results = await Future.wait([
      _getComicKChaptersPaged(manga.title),
      _getMangaDexChaptersPaged(manga.title),
    ]);

    final comickChapters = results[0];
    final mangadexChapters = results[1];
    final Map<String, MangaChapter> mergedMap = {};

    // PRIORITY ORDER (highest → lowest):
    //   1. ComicK chapters — image CDN is highly reliable (meo.comick.pictures)
    //   2. MangaDex Official/TCB scans — only upgrade if higher scan group quality
    //   3. MangaDex other scans — fill gaps not covered by ComicK

    // Step 1: seed with ComicK (most reliable for image loading)
    for (final chap in comickChapters) {
      mergedMap[chap.chapterNumber] = chap;
    }

    // Step 2: MangaDex can override ONLY if it has a higher-quality scan group
    // (Official or TCB) AND ComicK doesn't already have an official version
    for (final chap in mangadexChapters) {
      final existing = mergedMap[chap.chapterNumber];
      if (existing == null) {
        // ComicK doesn't have this chapter at all — use MangaDex
        mergedMap[chap.chapterNumber] = chap;
      } else {
        // ComicK has it — only override if MangaDex has a clearly superior group
        final nGroup = chap.group?.toLowerCase() ?? '';
        final eGroup = existing.group?.toLowerCase() ?? '';
        final mdHasOfficial = nGroup.contains('official');
        final ckHasOfficial = eGroup.contains('official');
        final mdHasTcb = nGroup.contains('tcb');
        final ckHasTcb = eGroup.contains('tcb');

        if (mdHasOfficial && !ckHasOfficial) {
          mergedMap[chap.chapterNumber] = chap;
        } else if (mdHasTcb && !ckHasTcb && !ckHasOfficial) {
          mergedMap[chap.chapterNumber] = chap;
        }
        // Otherwise keep ComicK — it has more reliable image serving
      }
    }

    if (mergedMap.isEmpty) {
      final kakalot = await getConsumetChapters(manga.id, 'mangakakalot');
      for (final chap in kakalot) mergedMap.putIfAbsent(chap.chapterNumber, () => chap);
    }

    final chapters = mergedMap.values.toList();
    chapters.sort((a, b) {
      final aNum = double.tryParse(a.chapterNumber) ?? 0.0;
      final bNum = double.tryParse(b.chapterNumber) ?? 0.0;
      return bNum.compareTo(aNum);
    });

    return chapters;
  }

  static Future<List<MangaPage>> fetchChapterPages(String chapterId) async {
    if (chapterId.startsWith('comick|')) {
      final pages = await getComicKPages(chapterId);
      if (pages.isNotEmpty) return pages;
      return [];
    } else if (chapterId.startsWith('mangadex|')) {
      // Try MangaDex first
      final pages = await getMangaDexPages(chapterId);
      if (pages.isNotEmpty) return pages;

      // MangaDex at-home can be unreliable; the chapter may also exist on ComicK.
      // We don't have the chapter number here, so we return empty and let the
      // reader surface the retry — the user can try a different chapter source.
      return [];
    } else if (chapterId.startsWith('consumet|')) {
      return getConsumetPages(chapterId);
    }
    return [];
  }
}
