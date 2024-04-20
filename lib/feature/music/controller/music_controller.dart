import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';

class MusicController extends GetxController {
  final AudioPlayer audioPlayer = AudioPlayer();

  // Observables
  var isPlaying = false.obs;
  var currentPosition = '00:00'.obs;
  var completeDuration = '00:00'.obs;

  @override
  void onInit() {
    super.onInit();
    audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });

    audioPlayer.onPositionChanged.listen((position) {
      currentPosition.value = _formatDuration(position);
    });

    audioPlayer.onDurationChanged.listen((duration) {
      completeDuration.value = _formatDuration(duration);
    });

    playAudio();
    audioPlayer.setVolume(0.5);
  }

  void playAudio() async {
    const path = 'music/keygen.mp3';
    await audioPlayer.play(AssetSource(path));
  }

  void pauseAudio() async {
    await audioPlayer.pause();
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

  @override
  void onClose() {
    audioPlayer.dispose();
    super.onClose();
  }
}
