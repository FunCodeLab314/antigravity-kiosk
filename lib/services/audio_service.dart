
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';

class AudioService {
  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    try {
      await _audioPlayer.setSource(AssetSource(AppConstants.alarmSoundPath));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _logger.i("AudioService initialized with ${AppConstants.alarmSoundPath}");
    } catch (e) {
      _logger.e("Error initializing AudioService: $e");
    }
  }

  Future<void> play() async {
    if (_isPlaying) return;
    
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
      _isPlaying = true;
      _logger.i("Audio playback started");
    } catch (e) {
      _logger.e("Error playing audio: $e");
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
    _isPlaying = false;
    _logger.i("AudioService disposed");
  }
}
