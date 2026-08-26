import '../config/api_config.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminService {
  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================
  // DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> getDashboard() async {
    final uri = Uri.parse(
      '$baseUrl/admin/dashboard.php',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao carregar dashboard: '
        '${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Resposta inválida da API.',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['message'] ??
            'Não foi possível carregar o dashboard.',
      );
    }

    return data;
  }

  // ============================================================
  // ATALHO PARA STATS
  // ============================================================

  static Future<Map<String, dynamic>> getStats() async {
    final data = await getDashboard();

    return Map<String, dynamic>.from(
      data['stats'] ?? {},
    );
  }

  // ============================================================
  // ÚLTIMAS CORRIDAS
  // ============================================================

  static Future<List<dynamic>> getRecentRides() async {
    final data = await getDashboard();

    return List<dynamic>.from(
      data['recent_rides'] ?? [],
    );
  }

  // ============================================================
  // MOTORISTAS PENDENTES
  // ============================================================

  static Future<List<dynamic>> getPendingDrivers() async {
    final data = await getDashboard();

    return List<dynamic>.from(
      data['pending_drivers_list'] ?? [],
    );
  }

  // ============================================================
  // VEÍCULOS PENDENTES
  // ============================================================

  static Future<List<dynamic>> getPendingVehicles() async {
    final data = await getDashboard();

    return List<dynamic>.from(
      data['pending_vehicles_list'] ?? [],
    );
  }

  // ============================================================
  // STATUS DAS CORRIDAS
  // ============================================================

  static Future<Map<String, dynamic>> getRideStatus() async {
    final data = await getDashboard();

    return Map<String, dynamic>.from(
      data['ride_status'] ?? {},
    );
  }
}