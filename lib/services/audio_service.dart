import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';

class AudioService {
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    // Pre-configure the player
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  Future<void> play() async {
    if (_isPlaying) return;
    
    try {
      _isPlaying = true;
      // FIX: Call play directly with the source. 
      // Ensure 'alarm_sound.mp3' is defined in pubspec.yaml assets!
      await _audioPlayer.play(AssetSource('alarm_sound.mp3'));
      _logger.i("Audio playback started");
    } catch (e) {
      _logger.e("Error playing audio: $e");
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _logger.i("Audio playback stopped");
    } catch (e) {
      _logger.e("Error stopping audio: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}