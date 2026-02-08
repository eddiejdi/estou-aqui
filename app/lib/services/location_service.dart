import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  Position? get lastPosition => _lastPosition;

  /// Verifica e solicita permissão de localização
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Obtém a posição atual
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      return _lastPosition;
    } catch (e) {
      return null;
    }
  }

  /// Inicia monitoramento contínuo de localização
  Stream<Position> startTracking({int distanceFilter = 50}) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map((position) {
      _lastPosition = position;
      return position;
    });
  }

  /// Para o monitoramento
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calcula distância entre dois pontos (em km)
  double distanceBetween(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }

  /// Verifica se o usuário está dentro do raio do evento
  bool isWithinRadius(double eventLat, double eventLng, {double radiusKm = 1.0}) {
    if (_lastPosition == null) return false;
    final distance = distanceBetween(
      _lastPosition!.latitude, _lastPosition!.longitude,
      eventLat, eventLng,
    );
    return distance <= radiusKm;
  }
}
