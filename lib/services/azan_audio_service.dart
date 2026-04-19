// lib/services/azan_audio_service.dart
import 'package:audioplayers/audioplayers.dart';

class AzanAudioService {
  AzanAudioService._();
  static final AzanAudioService instance = AzanAudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playAzan() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/allahu_akbar_short.mp3'));
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
    } catch (e) {
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  void dispose() {
    _player.dispose();
  }
}