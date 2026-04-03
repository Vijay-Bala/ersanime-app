import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing MangaPill Chapters...');
    final res = await http.get(
      Uri.parse('https://mangapill.com/manga/2/one-piece'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
      }
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      // Find chapter links like /chapters/2-10000000/one-piece-chapter-100
      final matches = RegExp(r'href="(/chapters/[^"]+)"').allMatches(res.body);
      print('Chapters found: ${matches.length}');
      if (matches.isNotEmpty) {
        final firstChapUrl = 'https://mangapill.com${matches.first.group(1)}';
        print('Fetching pages from: $firstChapUrl');
        
        final chapRes = await http.get(
          Uri.parse(firstChapUrl),
          headers: {'User-Agent': 'Mozilla/5.0'}
        );
        print('Chap status: ${chapRes.statusCode}');
        if (chapRes.statusCode == 200) {
          // Find images. Mangapill puts images in <picture> or <img> tags
          final imgMatches = RegExp(r'<img[^>]+src="([^"]+)"').allMatches(chapRes.body);
          print('Images found: ${imgMatches.length}');
          if (imgMatches.isNotEmpty) {
            print('First image: ${imgMatches.first.group(1)}');
          }
        }
      }
    }
  } catch(e) {
    print(e);
  }
}
