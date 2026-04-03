import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/services/music_service.dart' as api;

void main() async {
  print('--- Testing Genre ---');
  final songs = await api.searchGenrePlaylistSongs('Pop');
  print('Genre Pop returned ${songs.length} songs.');
  if (songs.isNotEmpty) {
    print('First song: ${songs[0].title}');
  }

  print('\n--- Testing Search & Image URLs ---');
  final searchSongs = await api.searchSongs('anirudh');
  print('Returned ${searchSongs.length} songs.');
  for (int i = 0; i < (searchSongs.length > 3 ? 3 : searchSongs.length); i++) {
    print('Song: ${searchSongs[i].title}, Image: ${searchSongs[i].imageUrl}');
  }
  
  if (searchSongs.isNotEmpty) {
      final song = searchSongs[0];
      print('\n--- Testing Lyrics ---');
      print('Has lyrics_id? ${song.lyricsId != null}');
      final lyrics = await api.getLyrics(song);
      print('Lyrics length: ${lyrics.text.length}');
      if (lyrics.text.length > 0) {
        print('Sample: ${lyrics.text.substring(0, 50)}');
      }
      
      // Force test "Rowdy Baby"
      final rbs = await api.searchSongs('Rowdy Baby');
      if (rbs.isNotEmpty) {
          final rb = rbs[0];
          print('Rowdy Baby ID: ${rb.id}, LyricsId: ${rb.lyricsId}');
          final rbl = await api.getLyrics(rb);
          print('Rowdy Baby Lyrics length: ${rbl.text.length}');
      }
  }
}
