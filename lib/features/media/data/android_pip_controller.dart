import 'dart:async';
import 'package:flutter/services.dart';

abstract interface class PipController {
  Stream<bool> get changes;
  Future<bool> enter();
  Future<void> configure({
    required bool playing,
    required bool visible,
    required bool autoEnter,
  });
  void dispose();
}

class AndroidPipController implements PipController {
  AndroidPipController() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipState' && call.arguments is bool) {
        _changes.add(call.arguments as bool);
      }
    });
  }
  static const _channel = MethodChannel('vn.thanhtaxixanh/player_pip');
  final _changes = StreamController<bool>.broadcast();
  @override
  Stream<bool> get changes => _changes.stream;
  @override
  Future<bool> enter() async {
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> configure({
    required bool playing,
    required bool visible,
    required bool autoEnter,
  }) async {
    try {
      await _channel.invokeMethod<void>('setPlayback', {
        'playing': playing,
        'visible': visible,
        'autoEnter': autoEnter,
      });
    } on MissingPluginException {
      // A headless car-started engine has no Activity until the phone opens it.
    } on PlatformException {
      // A device without PiP still supports the audio media session.
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
