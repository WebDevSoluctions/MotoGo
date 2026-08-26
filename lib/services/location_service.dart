import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Verifica se o serviço de localização está ativo
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Verifica e solicita as permissões necessárias
  Future<LocationPermission> checkPermission() async {
    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Retorna a localização atual do usuário
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('O serviço de localização está desativado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permissão de localização negada.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permissão de localização bloqueada. Ative a localização nas configurações do dispositivo.',
      );
    }

    // Uma posição conhecida é suficiente como fallback para completar
    // buscas de endereço e evitar que uma leitura GPS momentaneamente
    // indisponível derrube o fluxo da entrega.
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && lastKnown.accuracy.isFinite) {
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).timeout(const Duration(seconds: 8));
        return current;
      } catch (_) {
        return lastKnown;
      }
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).timeout(const Duration(seconds: 10));
  }

  /// Stream para acompanhar a localização em tempo real
  Stream<Position> positionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }

  /// Abre as configurações de localização
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Abre as configurações do aplicativo
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}