import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing Consumet API...');
    final res = await http.get(Uri.parse('https://api.consumet.org/meta/anilist-manga/44347')); // One Piece anilist ID
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final chaps = data['chapters'] as List? ?? [];
      print('Chapters: ${chaps.length}');
      if (chaps.isNotEmpty) {
        print('First: ${chaps.first}');
        print('Last: ${chaps.last}');
      }
    } else {
      print('Body: ${res.body.substring(0, 200)}');
    }
  } catch(e) {
    print(e);
  }
}
