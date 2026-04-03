import 'package:http/http.dart' as http;

void main() async {
  try {
    final res = await http.get(Uri.parse('https://mangasee123.com/manga/One-Piece'));
    print('Status: ${res.statusCode}');
    if (res.body.contains('vm.Chapters')) {
      print('Chapters found in HTML!');
      // print a snippet
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
