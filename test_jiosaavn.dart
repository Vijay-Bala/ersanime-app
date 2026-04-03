import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

void main() async {
  final url = Uri.parse('https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&n=1&p=1&_marker=0&ctx=wap6dot0&q=tum+hi+ho');
  final res = await http.get(url);
  final d = jsonDecode(res.body.replaceAll(RegExp(r'^[^{]*'), ''));
  final song = d['results'][0];
  
  final moreInfo = song['more_info'];
  String encUrl = '';
  if (song.containsKey('encrypted_media_url')) {
    encUrl = song['encrypted_media_url'].toString();
  } else if (moreInfo is Map && moreInfo.containsKey('encrypted_media_url')) {
    encUrl = moreInfo['encrypted_media_url'].toString();
  }
  
  print('encUrl: $encUrl');
  
  try {
     final key = '38346591'.codeUnits;
     final des = DES(key: key, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
     final decoded = base64Decode(encUrl.trim());
     final decrypted = des.decrypt(decoded);
     final decUrl = utf8.decode(decrypted);
     print('Decrypted: $decUrl');
  } catch (e, stack) {
     print('Error: $e\n$stack');
  }
}
