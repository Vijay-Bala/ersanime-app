import 'package:http/http.dart' as http;

void main() async {
  try {
    final res = await http.get(Uri.parse('https://mangasee123.com/search/'));
    print('Status: ${res.statusCode}');
    print(res.body.substring(0, 500));
  } catch(e) {
    print(e);
  }
}
