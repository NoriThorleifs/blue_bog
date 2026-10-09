import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Sound effects, from `assets/sounds/`. Made by `tool/generate_sounds.py`.
enum Sfx {
  laser('laser'),
  lance('lance'),
  missileLaunch('missile_launch'),
  explosionSmall('explosion_small'),
  teleport('teleport'),
  hellfire('hellfire'),
  ion('ion'),
  flak('flak'),
  rail('rail'),
  railGlance('rail_glance'),
  teeth('teeth'),
  brandyMist('brandy_mist'),
  hellClock('hell_clock'),
  shieldBlock('shield_block'),
  shieldCharge('shield_charge'),
  droneBuilt('drone_built'),
  repair('repair'),
  jammed('jammed'),
  outOfAmmo('out_of_ammo'),
  shipExplode('ship_explode'),
  boarded('boarded'),
  victory('victory'),
  defeat('defeat');

  const Sfx(this.file);
  final String file;

  String get asset => 'assets/sounds/${file}_ai_generated.wav';
}

/// Plays sound effects. Loads them all once, and keeps quiet rather than
/// failing if the device has no audio.
class SoundBoard {
  SoundBoard._();
  static final instance = SoundBoard._();

  final _sources = <Sfx, AudioSource>{};
  final _lastPlayed = <Sfx, int>{};
  final _clock = Stopwatch()..start();
  Future<void>? _loading;

  /// Off for the rest of the session once the player mutes it.
  final muted = ValueNotifier(false);

  /// The same sound won't start again within this many milliseconds, so a
  /// fast-forwarded volley doesn't turn into a wall of noise.
  static const _gapMs = 45;

  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await SoLoud.instance.init();
      for (final sfx in Sfx.values) {
        _sources[sfx] = await SoLoud.instance.loadAsset(sfx.asset);
      }
    } catch (e) {
      debugPrint('Sound is off: $e');
    }
  }

  /// Plays [sfx], panned from -1 (left) to 1 (right).
  void play(Sfx sfx, {double volume = 1, double pan = 0}) {
    final source = _sources[sfx];
    if (muted.value || source == null) return;
    final now = _clock.elapsedMilliseconds;
    if (now - (_lastPlayed[sfx] ?? -_gapMs) < _gapMs) return;
    _lastPlayed[sfx] = now;
    try {
      SoLoud.instance.play(source, volume: volume, pan: pan);
    } catch (e) {
      debugPrint('Could not play ${sfx.file}: $e');
    }
  }
}
