import 'dart:async';
import 'package:flutter/services.dart';

typedef void SoundCallBack();
class SoundManager {
  static final SoundManager _soundManager = new SoundManager._internal();
  SoundManager._internal();
  factory SoundManager() {
    return _soundManager;
  }
  MusicPlayer audioPlayer = new MusicPlayer();
  double get maxDb => audioPlayer.maxDB;
  Future<void> playLocal(String localFileName, void onDone()) async {
    audioPlayer.play(localFileName);
    audioPlayer.onStop = onDone;
    audioPlayer.onDone = onDone;
  }
  Future<void> stop() async {
    audioPlayer.stop();
  }
  Future<void> recoderStart() async {
    audioPlayer.recordStart();
  }
  Future<void> recoderStop() async {
    audioPlayer.recordStop();
  }
}

enum SoundPlayerStatus {
  STOPPED,
  PLAYING,
  PAUSED,
  COMPLETED,
}

const MethodChannel _channel =
const MethodChannel('top.sp0cket.flutter/audio');
class MusicPlayer {
  final StreamController<SoundPlayerStatus> _playerStateController =
  new StreamController.broadcast();

  final StreamController<Duration> _positionController =
  new StreamController.broadcast();
  SoundCallBack onStop;
  SoundCallBack onDone;
  Duration _duration;
  Duration get duration => _duration;
  double _maxDB;
  double get maxDB => _maxDB;
  SoundPlayerStatus _state = SoundPlayerStatus.STOPPED;
  SoundPlayerStatus get state => _state;
  Stream<SoundPlayerStatus> get onPlayerStateChanged => _playerStateController.stream;
  MusicPlayer() {
    _channel.setMethodCallHandler(_audioPlayerStateChange);
  }
  Future<void> play(String url) async =>
      await _channel.invokeMethod('play', {'url': url});
  Future<void> stop() async =>
      await _channel.invokeMethod('stop');
  Future<void> start() async =>
      await _channel.invokeMethod('start');
  Future<void> recordStart() async =>
      await _channel.invokeMethod('recoderStart');
  Future<void> recordStop() async =>
      await _channel.invokeMethod('recoderStop');
  Future<String> channel() async {
    String channel = await _channel.invokeMethod('channel');
    return channel;
  }
  Future<void> _audioPlayerStateChange(MethodCall call) async {
    switch (call.method) {
      case 'SPMusic.onStart':
        _state = SoundPlayerStatus.PLAYING;
        _duration = Duration(seconds: call.arguments);
        _positionController.add(_duration);
        break;
      case 'SPMusic.playing':
        _state = SoundPlayerStatus.PLAYING;
        _duration = Duration(seconds: call.arguments);
        print(call.arguments);
        _playerStateController.add(SoundPlayerStatus.PLAYING);
        break;
      case 'SPMusic.onComplete':
        _state = SoundPlayerStatus.COMPLETED;
        onDone();
        break;
      case 'SPMusic.onStop':
        _state = SoundPlayerStatus.STOPPED;
        onStop();
        break;
      case 'SPMusic.onPause':
        _state = SoundPlayerStatus.PAUSED;
        _playerStateController.add(SoundPlayerStatus.PAUSED);
        break;
      case 'SPMusic.maxDB':
        _maxDB = call.arguments;
        break;
      default:
        throw new ArgumentError('Unknown method ${call.method} ');
    }
  }
}