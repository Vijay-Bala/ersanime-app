import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing MangaSee with User-Agent...');
    final res = await http.get(
      Uri.parse('https://mangasee123.com/manga/One-Piece'),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    );
    print('Status: ${res.statusCode}');
    if (res.body.contains('vm.Chapters')) {
      print('Chapters found in HTML!');
      final match = RegExp(r'vm\.Chapters\s*=\s*(\[.*?\]);').firstMatch(res.body);
      if (match != null) {
        print(match.group(1)?.substring(0, 200));
      }
    } else {
      print('No vm.Chapters found.');
    }
  } catch(e) {
    print(e);
  }
}
