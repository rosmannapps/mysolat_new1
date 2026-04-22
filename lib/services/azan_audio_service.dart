// lib/services/azan_audio_service.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'prefs_service.dart';

enum AzanSoundMode { none, azanOnly, beepOnly, beepAndAzan }

class AzanAudioService {
  AzanAudioService._();
  static final AzanAudioService instance = AzanAudioService._();

  static const String _prefKeyMode = 'azan_sound_mode';

  AudioPlayer? _player;
  bool _isPlaying = false;

  Future<AzanSoundMode> getSoundMode() async {
    final index = PrefsService.instance.getInt(_prefKeyMode) ?? 1;
    return AzanSoundMode.values[index.clamp(0, AzanSoundMode.values.length - 1)];
  }

  Future<void> setSoundMode(AzanSoundMode mode) async {
    await PrefsService.instance.setInt(_prefKeyMode, mode.index);
    if (mode == AzanSoundMode.none) await stop();
  }

  Future<void> playBeep() async {
    try {
      _player?.dispose();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('audio/beep.wav'));
      await _player!.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Beep error: \$e');
    }
  }

  Future<void> playAzan() async {
    if (_isPlaying) return;
    try {
      _player?.dispose();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('audio/gendang.aac'));
      _isPlaying = true;
      _player!.onPlayerComplete.listen((_) => _isPlaying = false);
    } catch (e) {
      debugPrint('AzanAudioService ERROR: $e');
      _isPlaying = false;
    }
  }


  Future<void> stop() async {
    await _player?.stop();
    _isPlaying = false;
  }

  void dispose() {
    _player?.dispose();
    _isPlaying = false;
  }
}
