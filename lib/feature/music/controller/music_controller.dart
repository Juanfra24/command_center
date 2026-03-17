import 'dart:async';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicController extends GetxController {
  static const String _keyMusicAutoPlay = 'music_auto_play';
  static const String _keyMusicVolume = 'music_volume';

  final AudioPlayer audioPlayer = AudioPlayer();

  // Stream subscriptions
  late final StreamSubscription _stateSubscription;
  late final StreamSubscription _positionSubscription;
  late final StreamSubscription _durationSubscription;

  // Observables
  var isPlaying = false.obs;
  var currentPosition = '00:00'.obs;
  var completeDuration = '00:00'.obs;
  var volume = 0.1.obs; // Default to 10% volume

  @override
  void onInit() {
    super.onInit();
    _stateSubscription = audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });

    _positionSubscription = audioPlayer.onPositionChanged.listen((position) {
      currentPosition.value = _formatDuration(position);
    });

    _durationSubscription = audioPlayer.onDurationChanged.listen((duration) {
      completeDuration.value = _formatDuration(duration);
    });

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVolume = prefs.getDouble(_keyMusicVolume);
    if (savedVolume != null) {
      volume.value = savedVolume;
    }
    audioPlayer.setVolume(volume.value);

    final autoPlay = prefs.getBool(_keyMusicAutoPlay) ?? false;
    if (autoPlay) {
      playAudio();
    }
  }

  /// Set volume (0.0 to 1.0)
  void setVolume(double newVolume) {
    volume.value = newVolume.clamp(0.0, 1.0);
    audioPlayer.setVolume(volume.value);
    _saveVolumePreference();
  }

  void playAudio() async {
    const path = 'music/keygen.mp3';
    await audioPlayer.play(AssetSource(path));
    _savePlayPreference(true);
  }

  void pauseAudio() async {
    await audioPlayer.pause();
    _savePlayPreference(false);
  }

  void stopAudio() async {
    await audioPlayer.stop();
  }

  void seek(Duration position) {
    audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  Future<void> _savePlayPreference(bool playing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusicAutoPlay, playing);
  }

  Future<void> _saveVolumePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMusicVolume, volume.value);
  }

  @override
  void onClose() {
    _stateSubscription.cancel();
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    audioPlayer.dispose();
    super.onClose();
  }
}
