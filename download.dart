l theseimport 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final r = await http.get(Uri.parse('https://raw.githubusercontent.com/Sangwan5688/BlackHole/main/lib/APIs/api.dart'));
  await File('api.dart').writeAsString(r.body);
  print('Downloaded');
}
