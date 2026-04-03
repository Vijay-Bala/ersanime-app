import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // Search github for dart files containing 'vm.Chapters' (mangasee scraping)
    final res = await http.get(
      Uri.parse('https://api.github.com/search/code?q=vm.Chapters+extension:dart'),
      headers: {
        'User-Agent': 'Flutter-App',
        'Accept': 'application/vnd.github.v3+json',
      }
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['items'] as List? ?? [];
      for (final item in items) {
        print('${item['repository']['full_name']} -> ${item['html_url']}');
      }
    } else {
      print('Status: ${res.statusCode}');
      print(res.body);
    }
  } catch(e) {
    print(e);
  }
}
