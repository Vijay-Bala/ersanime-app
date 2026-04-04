import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import 'music_service.dart' as music_api;
import 'music_playlist_service.dart';

/// Global music playback controller.
/// Uses just_audio + just_audio_background for gapless, background-capable playback.
/// Singleton — wrap with ChangeNotifierProvider in main.dart.
class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService._();
  static final MusicPlayerService instance = MusicPlayerService._();
  factory MusicPlayerService() => instance;

  final AudioPlayer _player = AudioPlayer();

  // ─── State ─────────────────────────────────────────────────────────────────
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  bool _isShuffled = false;
  List<Song> _originalQueue = []; // for un-shuffling
  String? _error;

  // --- Public getters ---
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get isShuffled => _isShuffled;
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex < _queue.length - 1;
  String? get error => _error;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  // ─── Init ──────────────────────────────────────────────────────────────────
  MusicPlaylistService? _playlistService;

  Future<void> init(MusicPlaylistService playlistService) async {
    _playlistService = playlistService;

    // Configure audio session for music
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Player state stream
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // Auto-advance on song complete
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
      notifyListeners();
    });

    // Position / duration streams
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  void _onSongComplete() {
    switch (_repeatMode) {
      case PlayerRepeatMode.one:
        _player.seek(Duration.zero);
        _player.play();
        break;
      case PlayerRepeatMode.all:
        if (hasNext) {
          skipNext();
        } else {
          // Loop back to start
          _currentIndex = 0;
          _loadAndPlay();
        }
        break;
      case PlayerRepeatMode.none:
        if (hasNext) skipNext();
        break;
    }
  }

  // ─── Playback Controls ─────────────────────────────────────────────────────

  /// Play a single song (replaces queue with just this song).
  Future<void> playSong(Song song) async {
    await playPlaylist([song], startIndex: 0);
  }

  /// Play a list of songs from a given index.
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _originalQueue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _isShuffled = false;
    _error = null;
    await _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Resolve stream URL (refreshes if needed)
      String url = await music_api.resolveStreamUrl(song);
      if (url.isEmpty) throw Exception('No stream URL available');

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artUri: Uri.tryParse(song.imageUrl),
            duration: Duration(seconds: song.durationSeconds),
          ),
        ),
      );
      await _player.play();

      // Track in recently played
      await _playlistService?.addToRecent(song);
    } catch (e) {
      _error = 'Could not play "${song.title}". Tap to retry.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> stopAndClear() async {
    await _player.stop();
    _queue.clear();
    _originalQueue.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      if (currentSong == null) return;
      await play();
    }
  }

  Future<void> skipNext() async {
    if (!hasNext) return;
    _currentIndex++;
    await _loadAndPlay();
  }

  Future<void> skipPrevious() async {
    // If more than 3 seconds in, restart current song
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (!hasPrevious) return;
    _currentIndex--;
    await _loadAndPlay();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekToFraction(double fraction) async {
    if (_duration.inMilliseconds == 0) return;
    final target = Duration(
      milliseconds: (fraction * _duration.inMilliseconds).round(),
    );
    await seekTo(target);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    notifyListeners();
  }

  void setRepeatMode(PlayerRepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void toggleRepeat() {
    final next = PlayerRepeatMode.values[(_repeatMode.index + 1) % PlayerRepeatMode.values.length];
    setRepeatMode(next);
  }

  void toggleShuffle() {
    if (_isShuffled) {
      // Restore original order, keep current song
      final current = currentSong;
      _queue = List.from(_originalQueue);
      if (current != null) {
        _currentIndex = _queue.indexWhere((s) => s.id == current.id);
        if (_currentIndex == -1) _currentIndex = 0;
      }
      _isShuffled = false;
    } else {
      // Shuffle
      final current = currentSong;
      _originalQueue = List.from(_queue);
      _queue.shuffle();
      // Move current song to front
      if (current != null) {
        _queue.removeWhere((s) => s.id == current.id);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
      _isShuffled = true;
    }
    notifyListeners();
  }

  /// Jump to a specific song in the queue
  Future<void> playQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _loadAndPlay();
  }

  /// Add a song to end of the current queue
  void addToQueue(Song song) {
    if (_queue.any((s) => s.id == song.id)) return;
    _queue.add(song);
    _originalQueue.add(song);
    notifyListeners();
  }

  /// Remove a song from the queue (won't remove currently playing)
  void removeFromQueue(int index) {
    if (index == _currentIndex) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    notifyListeners();
  }

  /// Retry current song after an error
  Future<void> retry() async {
    _error = null;
    await _loadAndPlay();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
