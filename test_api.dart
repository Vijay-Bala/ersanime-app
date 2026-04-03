import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final query = 'Love Me Like You Do Ellie Goulding';
  final searchUri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {'q': query});
  final sRes = await http.get(searchUri);
  final sData = jsonDecode(sRes.body) as List;
  
  if (sData.isNotEmpty) {
      final best = sData.firstWhere((e) => e['syncedLyrics'] != null, orElse: () => sData.first);
      print('Track: ${best['trackName']}');
      print('Synced Lyrics available: ${best['syncedLyrics'] != null}');
      if (best['syncedLyrics'] != null) {
          print('First words: ${best['syncedLyrics'].toString().substring(0, 100)}');
      }
  } else {
     print('No results found for Love Me Like You Do');
  }
}
