import '../config/api_config.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {

  // ============================================================

  // BASE URL

  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================

  // DECODIFICAR RESPOSTA

  // ============================================================

  static Future<Map<String, dynamic>> _decode(

    http.Response response,

  ) async {

    try {

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {

        if (response.statusCode >= 200 &&

            response.statusCode < 300) {

          return decoded;

        }

        return {

          'success': false,

          'message': decoded['message'] ?? 'Erro na API.',

          ...decoded,

        };

      }

      return {

        'success': false,

        'message': 'Resposta inválida da API.',

      };

    } catch (_) {

      return {

        'success': false,

        'message': 'Resposta inválida da API.',

      };

    }

  }

  // ============================================================

  // LOGIN

  // ============================================================

  static Future<Map<String, dynamic>> login({

    required String email,

    required String password,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/auth/login.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'email': email.trim(),

          'password': password,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível conectar à API.',

      };

    }

  }

  // ============================================================

  // REGISTER

  // ============================================================

  static Future<Map<String, dynamic>> register({

    required String name,

    required String email,

    required String phone,

    required String password,

    required String city,

    required String state,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/auth/register.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'name': name.trim(),

          'email': email.trim(),

          'phone': phone.trim(),

          'city': city.trim(),

          'state': state.trim().toUpperCase(),

          'password': password,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível conectar à API.',

      };

    }

  }

  // ============================================================

  // CRIAR CORRIDA

  // ============================================================

  static Future<Map<String, dynamic>> createRide({

    required int userId,

    required String rideType,

    required String originAddress,

    required double originLatitude,

    required double originLongitude,

    required String destinationAddress,

    required double destinationLatitude,

    required double destinationLongitude,

    required double distanceKm,

    required double durationMinutes,

    required double baseFare,

    required double distanceFare,

    required double additionalFee,

    required double discount,

    required double totalFare,

    String? scheduledAt,

    String? passengerName,

    String? passengerPhone,

    int? favoriteDriverId,

    List<Map<String, dynamic>>? stops,

    String? deliveryMode,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/rides/create.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'user_id': userId,

          'ride_type': rideType,

          if (deliveryMode != null) 'delivery_mode': deliveryMode,

          'origin_address': originAddress,

          'origin_latitude': originLatitude,

          'origin_longitude': originLongitude,

          'destination_address': destinationAddress,

          'destination_latitude': destinationLatitude,

          'destination_longitude': destinationLongitude,

          'distance_km': distanceKm,

          'duration_minutes': durationMinutes,

          'base_fare': baseFare,

          'distance_fare': distanceFare,

          'additional_fee': additionalFee,

          'discount': discount,

          'total_fare': totalFare,

          if (scheduledAt != null) 'scheduled_at': scheduledAt,

          if (passengerName != null) 'passenger_name': passengerName,

          if (passengerPhone != null) 'passenger_phone': passengerPhone,

          if (favoriteDriverId != null) 'favorite_driver_id': favoriteDriverId,

          if (stops != null && stops.isNotEmpty) 'stops': stops,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível conectar à API.',

      };

    }

  }





  // ============================================================

  // PASSAGEIRO - CANCELAR CORRIDA

  // ============================================================

  static Future<Map<String, dynamic>> cancelRide({

    required int rideId,

    required int userId,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/rides/cancel.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'ride_id': rideId,

          'user_id': userId,

        }),

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível cancelar a corrida.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // STATUS DA CORRIDA

  // ============================================================

  static Future<Map<String, dynamic>> getRideStatus({

    required int rideId,

    required int userId,

  }) async {

    try {

      final response = await http.get(

        Uri.parse(

          '$baseUrl/rides/get_status.php'

          '?ride_id=$rideId'

          '&user_id=$userId',

        ),

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível consultar o status da corrida.',

      };

    }

  }

  // ============================================================



  // ============================================================

  // STATUS DA CORRIDA - MOTORISTA

  // ============================================================

  // Consulta diretamente o status da corrida para o motorista.

  // Não depende do endpoint usado pelo passageiro.

  static Future<Map<String, dynamic>> getRideStatusForDriver({

    required int rideId,

    required int driverId,

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/rides/status_for_driver.php',

      ).replace(

        queryParameters: {

          'ride_id': rideId.toString(),

          'driver_id': driverId.toString(),

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível consultar o status da corrida para o motorista.',

        'error': e.toString(),

      };

    }

  }

  // HISTÓRICO REAL DO PASSAGEIRO

  // ============================================================

  static Future<Map<String, dynamic>> getRideHistory({

    required int userId,

    int page = 1,

    int limit = 20,

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/rides/history.php',

      ).replace(

        queryParameters: {

          'user_id': userId.toString(),

          'page': page.toString(),

          'limit': limit.toString(),

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível carregar o histórico.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // ADMIN - DASHBOARD

  // ============================================================

  static Future<Map<String, dynamic>> getAdminDashboard() async {

    try {

      final response = await http.get(

        Uri.parse('$baseUrl/admin/dashboard.php'),

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar o dashboard.',

      };

    }

  }

  // ============================================================

  // ADMIN - AÇÃO NO VEÍCULO

  // ============================================================

  static Future<Map<String, dynamic>> adminVehicleAction({

    required int vehicleId,

    required String action,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/admin/vehicle_action.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'vehicle_id': vehicleId,

          'action': action,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível conectar à API.',

      };

    }

  }

  // ============================================================

  // ADMIN - AÇÃO NO MOTORISTA

  // ============================================================

  static Future<Map<String, dynamic>> adminDriverAction({
    required int driverId,
    required String action,
    String reason = '',
  }) async {
    try {
      final body = <String, dynamic>{
        'driver_id': driverId,
        'action': action,
      };

      if (reason.trim().isNotEmpty) {
        body['reason'] = reason.trim();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/driver_action.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      return _decode(response);
    } catch (_) {
      return {
        'success': false,
        'message': 'Não foi possível conectar à API.',
      };
    }
  }

  // ============================================================

  // ADMIN - MOTORISTAS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminDrivers({

    String status = 'all',

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/admin/drivers/list.php',

      ).replace(

        queryParameters: {

          'status': status,

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar os motoristas.',

      };

    }

  }

  // ============================================================

  // ADMIN - VEÍCULOS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminVehicles({

    String status = 'all',

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/admin/vehicles.php',

      ).replace(

        queryParameters: {

          'status': status,

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar os veículos.',

      };

    }

  }

  // ============================================================

  // ADMIN - ATUALIZAR STATUS DO VEÍCULO

  // ============================================================

  static Future<Map<String, dynamic>> updateVehicleStatus({

    required int vehicleId,

    required String status,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/admin/vehicle_status.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'vehicle_id': vehicleId,

          'status': status,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível atualizar o veículo.',

      };

    }

  }

  // ============================================================

  // ADMIN - CORRIDAS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminRides({

    String status = 'all',

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/admin/rides.php',

      ).replace(

        queryParameters: {

          'status': status,

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar as corridas.',

      };

    }

  }

  // ============================================================

  // ADMIN - USUÁRIOS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminUsers() async {

    try {

      final response = await http.get(

        Uri.parse('$baseUrl/admin/users.php'),

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar os usuários.',

      };

    }

  }

  // ============================================================

  // ADMIN - PAGAMENTOS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminPayments({

    String status = 'pending',

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/admin/invoice_payments.php',

      ).replace(

        queryParameters: {

          'status': status,

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível carregar os pagamentos.',

      };

    }

  }

  // ============================================================

  // ADMIN - APROVAR PAGAMENTO

  // ============================================================

  static Future<Map<String, dynamic>> approvePayment({

    required int paymentId,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/admin/approve_payment.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'payment_id': paymentId,

        }),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível aprovar o pagamento.',

      };

    }

  }

  // ============================================================

  // ADMIN - RECUSAR PAGAMENTO

  // ============================================================

  static Future<Map<String, dynamic>> rejectPayment({

    required int paymentId,

    required String reason,

    int? adminId,

  }) async {

    try {

      final body = <String, dynamic>{

        'payment_id': paymentId,

        'reason': reason.trim(),

      };

      if (adminId != null) {

        body['admin_id'] = adminId;

      }

      final response = await http.post(

        Uri.parse('$baseUrl/admin/reject_payment.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode(body),

      );

      return _decode(response);

    } catch (_) {

      return {

        'success': false,

        'message': 'Não foi possível recusar o pagamento.',

      };

    }

  }









  // ============================================================

  // CLIENTE - PERFIL

  // ============================================================

  static Future<Map<String, dynamic>> getUserProfile({required int userId}) async {

    try {

      final response = await http.get(

        Uri.parse('$baseUrl/auth/profile.php?user_id=$userId'),

        headers: {'Accept': 'application/json'},

      );

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível carregar o perfil.', 'error': e.toString()};

    }

  }

  // ============================================================

  // MOTORISTA - PERFIL

  // ============================================================

  static Future<Map<String, dynamic>> getDriverProfile({required int userId}) async {

    try {

      final response = await http.get(Uri.parse('$baseUrl/drivers/profile.php?user_id=$userId'), headers: {'Accept': 'application/json'});

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível carregar os dados do motorista.', 'error': e.toString()};

    }

  }

  static Future<Map<String, dynamic>> updateDriverProfile({required int userId, required String name, required String phone, String? city, String? state, String? driverType}) async {

    try {

      final response = await http.post(Uri.parse('$baseUrl/drivers/profile.php'), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode({'user_id': userId, 'name': name.trim(), 'phone': phone.trim(), if (city != null) 'city': city.trim(), if (state != null) 'state': state.trim().toUpperCase(), if (driverType != null) 'driver_type': driverType.trim()}));

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível salvar os dados do motorista.', 'error': e.toString()};

    }

  }

  // ============================================================

  // CIDADES ATENDIDAS - PÚBLICO

  // ============================================================

  static Future<Map<String, dynamic>> getServiceCities() async {

    try {

      final response = await http.get(

        Uri.parse('$baseUrl/service_cities.php'),

        headers: {'Accept': 'application/json'},

      ).timeout(const Duration(seconds: 10));

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível carregar as cidades atendidas.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // ADMIN - CONFIGURAÇÕES E CIDADES

  // ============================================================

  static Future<Map<String, dynamic>> getAdminSettings() async {

    try {

      final response = await http.get(Uri.parse('$baseUrl/admin/settings.php'), headers: {'Accept': 'application/json'});

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível carregar as configurações.', 'error': e.toString()};

    }

  }

  static Future<Map<String, dynamic>> saveAdminSettings(Map<String, dynamic> settings) async {

    try {

      final response = await http.post(Uri.parse('$baseUrl/admin/settings.php'), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode({'action': 'save_settings', 'settings': settings}));

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível salvar as configurações.', 'error': e.toString()};

    }

  }

  static Future<Map<String, dynamic>> addAdminCity({required String city, required String state}) async {

    try {

      final response = await http.post(Uri.parse('$baseUrl/admin/settings.php'), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode({'action': 'add_city', 'city': city.trim(), 'state': state.trim().toUpperCase()}));

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível adicionar a cidade.', 'error': e.toString()};

    }

  }

  static Future<Map<String, dynamic>> deleteAdminCity({required int id}) async {

    try {

      final response = await http.post(Uri.parse('$baseUrl/admin/settings.php'), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode({'action': 'delete_city', 'id': id}));

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível remover a cidade.', 'error': e.toString()};

    }

  }

  // ============================================================

  // ACOMPANHAMENTO PÚBLICO DA CORRIDA

  // ============================================================

  static Future<Map<String, dynamic>> getPublicRideTracking({

    required int rideId,

  }) async {

    try {

      final uri = Uri.parse('$baseUrl/rides/public_track.php').replace(

        queryParameters: {'ride_id': rideId.toString()},

      );

      final response = await http.get(uri, headers: {'Accept': 'application/json'});

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível carregar o acompanhamento.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // PASSAGEIRO - AVALIAR CORRIDA

  // ============================================================

  static Future<Map<String, dynamic>> rateRide({

    required int rideId,

    required int userId,

    required int rating,

    String comment = '',

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/rides/rate.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'ride_id': rideId,

          'user_id': userId,

          'rating': rating,

          'comment': comment.trim(),

        }),

      );

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível enviar a avaliação.', 'error': e.toString()};

    }

  }

  // ============================================================

  // MOTORISTA - AVALIAR CLIENTE

  // ============================================================

  static Future<Map<String, dynamic>> rateClient({

    required int rideId,

    required int userId,

    required int rating,

    String comment = '',

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/rides/rate_client.php'),

        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},

        body: jsonEncode({

          'ride_id': rideId,

          'user_id': userId,

          'rating': rating,

          'comment': comment.trim(),

        }),

      );

      return _decode(response);

    } catch (e) {

      return {'success': false, 'message': 'Não foi possível enviar a avaliação do cliente.', 'error': e.toString()};

    }

  }

  // ============================================================

  // MOTORISTA - ENVIAR COMPROVANTE

  // ============================================================

  static Future<Map<String, dynamic>> submitPayment({

    required int driverId,

    required int invoiceId,

    required List<int> proofBytes,

    required String fileName,

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/drivers/submit_payment.php',

      );

      final request = http.MultipartRequest(

        'POST',

        uri,

      );

      request.headers['Accept'] =

          'application/json';

      request.fields['driver_id'] =

          driverId.toString();

      request.fields['invoice_id'] =

          invoiceId.toString();

      final multipartFile =

          http.MultipartFile.fromBytes(

        'proof',

        proofBytes,

        filename: fileName,

      );

      request.files.add(multipartFile);

      final streamedResponse =

          await request.send();

      final response =

          await http.Response.fromStream(

        streamedResponse,

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message':

            'Não foi possível enviar o comprovante.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // URL DO COMPROVANTE

  // ============================================================

  static String paymentProofUrl(

    String? proofPath, {

    int? paymentId,

  }) {

    // Se temos o ID do pagamento,

    // usamos o endpoint seguro do PHP.

    if (paymentId != null && paymentId > 0) {

      return '$baseUrl/admin/payment_proof.php'

          '?payment_id=$paymentId';

    }

    // Compatibilidade com registros antigos.

    if (proofPath == null ||

        proofPath.trim().isEmpty) {

      return '';

    }

    final path = proofPath.trim();

    // Caso a API já tenha retornado uma URL completa.

    if (path.startsWith('http://') ||

        path.startsWith('https://')) {

      return path;

    }

    // Compatibilidade com comprovantes antigos.

    final apiRoot = baseUrl.replaceFirst(

      RegExp(r'/api$'),

      '',

    );

    return '$apiRoot/$path';

  }

  // ============================================================

  // MOTORISTA - ATUALIZAR LOCALIZAÇÃO GPS

  // ============================================================

  static Future<Map<String, dynamic>> updateDriverLocation({

    required int driverId,

    required double latitude,

    required double longitude,

  }) async {

    try {

      final response = await http.post(

        Uri.parse(

          '$baseUrl/drivers/location.php',

        ),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'driver_id': driverId,

          'latitude': latitude,

          'longitude': longitude,

        }),

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message':

            'Não foi possível atualizar a localização do motorista.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // PASSAGEIRO - BUSCAR LOCALIZAÇÃO DO MOTORISTA

  // ============================================================

  static Future<Map<String, dynamic>> getDriverLocation({

    required int rideId,

  }) async {

    try {

      final uri = Uri.parse(

        '$baseUrl/admin/drivers/driver_location.php',

      ).replace(

        queryParameters: {

          'ride_id': rideId.toString(),

        },

      );

      final response = await http.get(

        uri,

        headers: {

          'Accept': 'application/json',

        },

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message':

            'Não foi possível carregar a localização do motorista.',

        'error': e.toString(),

      };

    }

  }

  // ============================================================

  // CONTAS ADMINISTRATIVAS

  // ============================================================

  static Future<Map<String, dynamic>> getAdminAccounts({

    required int currentAdminId,

  }) async {

    try {

      final uri = Uri.parse('$baseUrl/admin/admins.php').replace(

        queryParameters: {

          'current_admin_id': currentAdminId.toString(),

        },

      );

      final response = await http.get(

        uri,

        headers: {'Accept': 'application/json'},

      );

      return await _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível carregar os administradores.',

      };

    }

  }

  static Future<Map<String, dynamic>> createAdminAccount({

    required int currentAdminId,

    required String name,

    required String email,

    required String phone,

    required String password,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/admin/admins.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'action': 'create',

          'current_admin_id': currentAdminId,

          'name': name,

          'email': email,

          'phone': phone,

          'password': password,

        }),

      );

      return await _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível criar a conta administrativa.',

      };

    }

  }

  static Future<Map<String, dynamic>> setAdminAccountStatus({

    required int currentAdminId,

    required int adminId,

    required String status,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/admin/admins.php'),

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'action': 'set_status',

          'current_admin_id': currentAdminId,

          'admin_id': adminId,

          'status': status,

        }),

      );

      return await _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível alterar o administrador.',

      };

    }

  }





  // ============================================================

  // MOTOGO+ — RECURSOS EXTRAS

  // ============================================================

  static Future<Map<String, dynamic>> _featureRequest({

    required String action,

    Map<String, dynamic>? body,

    int? userId,

  }) async {

    try {

      final uri = Uri.parse('$baseUrl/features.php').replace(

        queryParameters: {

          'action': action,

          if (userId != null) 'user_id': userId.toString(),

        },

      );

      final response = await http.post(

        uri,

        headers: {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          if (userId != null) 'user_id': userId,

          ...?body,

        }),

      );

      return _decode(response);

    } catch (e) {

      return {

        'success': false,

        'message': 'Não foi possível conectar à API.',

        'error': e.toString(),

      };

    }

  }

  static Future<Map<String, dynamic>> getFavoriteDrivers(int userId) =>

      _featureRequest(action: 'favorites_list', userId: userId);

  static Future<Map<String, dynamic>> addFavoriteDriver({required int userId, required int driverId}) =>

      _featureRequest(action: 'favorite_add', userId: userId, body: {'driver_id': driverId});

  static Future<Map<String, dynamic>> removeFavoriteDriver({required int userId, required int driverId}) =>

      _featureRequest(action: 'favorite_remove', userId: userId, body: {'driver_id': driverId});

  static Future<Map<String, dynamic>> getPoints(int userId) =>

      _featureRequest(action: 'points', userId: userId);

  static Future<Map<String, dynamic>> applyReferral({required int userId, required String code}) =>

      _featureRequest(action: 'referral_apply', userId: userId, body: {'code': code});

  static Future<Map<String, dynamic>> getRewardsDashboard(int userId) =>

      _featureRequest(action: 'rewards_dashboard', userId: userId);

  static Future<Map<String, dynamic>> getDriverRewards(int userId) =>

      _featureRequest(action: 'driver_rewards', userId: userId);

  static Future<Map<String, dynamic>> getScheduledRides(int userId) =>

      _featureRequest(action: 'scheduled', userId: userId);

  static Future<Map<String, dynamic>> createRideShare({required int userId, required int rideId}) =>

      _featureRequest(action: 'create_share', userId: userId, body: {'ride_id': rideId});

  static Future<Map<String, dynamic>> getRideChat({required int userId, required int rideId}) =>

      _featureRequest(action: 'chat_list', userId: userId, body: {'ride_id': rideId});

  static Future<Map<String, dynamic>> sendRideChat({required int userId, required int rideId, required String message}) =>

      _featureRequest(action: 'chat_send', userId: userId, body: {'ride_id': rideId, 'message': message});

}