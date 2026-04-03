import 'package:http/http.dart' as http;

void main() async {
  try {
    final firstChapUrl = 'https://mangapill.com/chapters/2-11179000/one-piece-chapter-1117.9'; // Found this chapter earlier
    final chapRes = await http.get(
      Uri.parse(firstChapUrl),
      headers: {'User-Agent': 'Mozilla/5.0'}
    );
    if (chapRes.statusCode == 200) {
      final imgMatches = RegExp(r'<picture[^>]*>\s*<img[^>]+data-src="([^"]+)"').allMatches(chapRes.body);
      if (imgMatches.isEmpty) {
        // Fallback for src
        final imgMatches2 = RegExp(r'<img[^>]+data-src="([^"]+)"').allMatches(chapRes.body);
        print('Using fallback, found: ${imgMatches2.length}');
        if (imgMatches2.isNotEmpty) {
          final realUrl = imgMatches2.first.group(1)!;
          print('Real Image URL: $realUrl');
          
          final res = await http.get(
            Uri.parse(realUrl),
            headers: {
              'Referer': 'https://mangapill.com/',
              'User-Agent': 'Mozilla/5.0'
            }
          );
          print('Image Request Status: ${res.statusCode}');
        }
      }
    }
  } catch(e) {
    print(e);
  }
}
