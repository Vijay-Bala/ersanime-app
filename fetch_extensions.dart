import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // Official mangayomi extensions index
    final res = await http.get(Uri.parse('https://raw.githubusercontent.com/mangayomi/mangayomi-extensions/main/index.json'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      for (final ext in data) {
        final name = ext['name'].toString().toLowerCase();
        if (name.contains('mangasee') || name.contains('manganato') || name.contains('mangakakalot')) {
          print('${ext['name']} (${ext['lang']}): ${ext['source']}');
        }
      }
    } else {
      print('Failed to load mangayomi index: ${res.statusCode}');
    }
  } catch(e) {
    print(e);
  }
}
