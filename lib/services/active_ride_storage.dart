import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ActiveRideStorage {
  static const String _key = 'motogo_active_driver_ride';

  static Future<void> save({
    required int rideId,
    required String passengerName,
    required String rideType,
    required String origin,
    required String destination,
    required double distanceKm,
    required double ridePrice,
    List<Map<String, dynamic>> stops = const [],
    int passengerPoints = 0,
    String passengerLevel = 'Bronze',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'rideId': rideId,
        'passengerName': passengerName,
        'rideType': rideType,
        'origin': origin,
        'destination': destination,
        'distanceKm': distanceKm,
        'ridePrice': ridePrice,
        'stops': stops,
        'passengerPoints': passengerPoints,
        'passengerLevel': passengerLevel,
      }),
    );
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
