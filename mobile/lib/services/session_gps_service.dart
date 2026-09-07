import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/session_timeline.dart';

class SessionGpsService extends ChangeNotifier {
  StreamSubscription<Position>? _sub;
  final List<RoutePoint> _route = [];
  Position? _current;
  double _distanceMeters = 0;
  DateTime? _startedAt;
  bool _active = false;

  List<RoutePoint> get route => List.unmodifiable(_route);
  Position? get current => _current;
  double get distanceMeters => _distanceMeters;
  bool get isActive => _active;

  Future<bool> start() async {
    if (_active) return true;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }

    _active = true;
    _startedAt = DateTime.now();
    _route.clear();
    _distanceMeters = 0;

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 4,
      ),
    ).listen(_onPosition);

    notifyListeners();
    return true;
  }

  void _onPosition(Position pos) {
    final prev = _current;
    _current = pos;

    if (prev != null) {
      _distanceMeters += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        pos.latitude,
        pos.longitude,
      );
    }

    final offset = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    _route.add(RoutePoint(
      lat: pos.latitude,
      lng: pos.longitude,
      offsetSec: offset,
    ));

    notifyListeners();
  }

  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    _sub = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}
