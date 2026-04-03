import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing MangaPill...');
    final res = await http.get(
      Uri.parse('https://mangapill.com/search?q=one+piece'),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      if (res.body.contains('/manga/')) {
        print('Found manga links!');
        final match = RegExp(r'href="(/manga/[^"]+)"').firstMatch(res.body);
        if (match != null) {
          print('First link: ${match.group(1)}');
        }
      }
    } else {
      print(res.body.substring(0, 300));
    }
  } catch(e) {
    print(e);
  }
}
