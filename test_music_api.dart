import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final id = 'aRZbUYD7';
  final res = await http.get(Uri.parse('https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$id&_format=json&ctx=wap6dot0'));
  print(res.body.replaceAll(RegExp(r'^[^{]*'), ''));
}
