import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing MangaPill Image Hotlinking...');
    // We already got an image url from previous test
    // Usually it looks like: https://cdn.mangapill.com/...
    final firstImg = 'https://cdn.mangapill.com/images/a19d4f17-be09-7794-aa56-bf0efdfffcdd/1.png'; // Got from previous trace
    final res = await http.get(
      Uri.parse(firstImg),
      headers: {
        'Referer': 'https://mangapill.com/',
        'User-Agent': 'Mozilla/5.0'
      }
    );
    print('Image Request Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      print('Image downloaded successfully! Size: ${res.bodyBytes.length} bytes');
    }
  } catch(e) {
    print(e);
  }
}
