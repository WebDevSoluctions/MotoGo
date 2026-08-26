import '../config/api_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'auth_service.dart';

class DriverService {
  // ============================================================
  // API
  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================
  // TIMEOUT DA API
  // ============================================================

  static const Duration requestTimeout =
      Duration(seconds: 10);

  // ============================================================
  // CADASTRO DE MOTORISTA
  // ============================================================

  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String city,
    required String state,
    required String cpf,
    required String birthDate,
    required String driverType,
    required String cnh,
    required String cnhCategory,
    String? documentPhoto,
    String? cnhPhoto,
    String? selfiePhoto,
  }) async {
    try {
      final Uri url = Uri.parse(
        '$baseUrl/auth/register_driver.php',
      );

      final Map<String, dynamic> body = {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
        'state': state.trim().toUpperCase(),
        'password': password,
        'cpf': cpf.trim(),
        'birth_date': birthDate.trim(),
        'driver_type': driverType,
        'cnh': cnh.trim(),
        'cnh_category': cnhCategory.trim(),
      };

      if (documentPhoto != null &&
          documentPhoto.trim().isNotEmpty) {
        body['document_photo'] =
            documentPhoto.trim();
      }

      if (cnhPhoto != null &&
          cnhPhoto.trim().isNotEmpty) {
        body['cnh_photo'] =
            cnhPhoto.trim();
      }

      if (selfiePhoto != null &&
          selfiePhoto.trim().isNotEmpty) {
        body['selfie_photo'] =
            selfiePhoto.trim();
      }

      final http.Response response =
          await http
              .post(
                url,
                headers: {
                  'Content-Type':
                      'application/json',
                  'Accept':
                      'application/json',
                },
                body: jsonEncode(body),
              )
              .timeout(requestTimeout);

      return _decodeResponse(response);
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'A API demorou para responder.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // ATUALIZAR LOCALIZAÇÃO GPS
  // ============================================================

  static Future<Map<String, dynamic>> updateLocation({
    required int driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/drivers/location.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'driver_id': driverId,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(requestTimeout);

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Não foi possível atualizar a localização.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // ENVIAR DOCUMENTOS DO MOTORISTA
  // ============================================================

  static Future<Map<String, dynamic>> uploadDocuments({
    required int driverId,
    required Map<String, PlatformFile> documents,
  }) async {
    if (documents.isEmpty) {
      return {
        'success': true,
        'message': 'Nenhum documento para enviar.',
      };
    }

    // Envia um arquivo por requisição. Isso evita que vários documentos
    // ultrapassem o post_max_size do PHP/XAMPP e faz cada upload poder ser
    // confirmado individualmente no servidor.
    final uploaded = <Map<String, dynamic>>[];
    final failures = <String>[];

    for (final entry in documents.entries) {
      final file = entry.value;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        failures.add('${entry.key}: arquivo vazio');
        continue;
      }

      // Mantém uma margem abaixo do limite padrão de upload do PHP.
      if (bytes.length > 7 * 1024 * 1024) {
        failures.add('${entry.key}: arquivo maior que 7 MB');
        continue;
      }

      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/drivers/upload_documents.php'),
        );

        request.fields['driver_id'] = driverId.toString();
        request.files.add(
          http.MultipartFile.fromBytes(
            entry.key,
            bytes,
            filename: file.name,
          ),
        );

        final streamed = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final response = await http.Response.fromStream(streamed);
        final decoded = _decodeResponse(response);

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded['success'] == true) {
          final docs = decoded['documents'];
          if (docs is List) {
            uploaded.addAll(
              docs.map((e) => e is Map
                  ? Map<String, dynamic>.from(e)
                  : <String, dynamic>{}),
            );
          }
        } else {
          failures.add(
            '${entry.key}: ${decoded['message'] ?? 'falha no upload'}',
          );
        }
      } catch (e) {
        failures.add('${entry.key}: erro de conexão');
      }
    }

    if (failures.isNotEmpty) {
      return {
        'success': false,
        'message': 'Alguns documentos não foram enviados: ${failures.join(' | ')}',
        'uploaded': uploaded,
        'failures': failures,
      };
    }

    return {
      'success': uploaded.length >= documents.length,
      'message': 'Todos os documentos foram enviados com sucesso.',
      'documents': uploaded,
    };
  }

  // ============================================================
  // ALTERAR STATUS ONLINE / OFFLINE
  // ============================================================

  static Future<Map<String, dynamic>>
      setOnlineStatus({
    required bool online,
  }) async {
    try {
      // ==========================================================
      // USER ID
      // ==========================================================

      final String? userId =
          await AuthService.getUserId();

      if (userId == null ||
          userId.trim().isEmpty) {
        return {
          'success': false,
          'message':
              'Usuário não identificado. Faça login novamente.',
        };
      }

      final int? parsedUserId =
          int.tryParse(userId);

      if (parsedUserId == null ||
          parsedUserId <= 0) {
        return {
          'success': false,
          'message':
              'ID do usuário inválido.',
        };
      }

      // ==========================================================
      // URL
      // ==========================================================

      final Uri url = Uri.parse(
        '$baseUrl/drivers/toggle_status.php',
      );

      // ==========================================================
      // REQUEST
      // ==========================================================

      final http.Response response =
          await http
              .post(
                url,
                headers: {
                  'Content-Type':
                      'application/json',
                  'Accept':
                      'application/json',
                },
                body: jsonEncode({
                  'user_id':
                      parsedUserId,
                  'online':
                      online,
                }),
              )
              .timeout(requestTimeout);

      // ==========================================================
      // DECODIFICAR
      // ==========================================================

      final Map<String, dynamic> decoded =
          _decodeResponse(response);

      // ==========================================================
      // ERRO HTTP
      // ==========================================================

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return {
          'success': false,
          'message':
              decoded['message']?.toString() ??
                  'Erro ao alterar status.',
          'status_code':
              response.statusCode,
        };
      }

      // ==========================================================
      // RETORNO DA API
      // ==========================================================

      return decoded;
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'A API demorou mais de 10 segundos para responder.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // BUSCAR STATUS ATUAL DO MOTORISTA
  // ============================================================

  static Future<Map<String, dynamic>>
      getStatus() async {
    try {
      // ==========================================================
      // USER ID
      // ==========================================================

      final String? userId =
          await AuthService.getUserId();

      if (userId == null ||
          userId.trim().isEmpty) {
        return {
          'success': false,
          'message':
              'Usuário não identificado. Faça login novamente.',
        };
      }

      final int? parsedUserId =
          int.tryParse(userId);

      if (parsedUserId == null ||
          parsedUserId <= 0) {
        return {
          'success': false,
          'message':
              'ID do usuário inválido.',
        };
      }

      // ==========================================================
      // URL
      // ==========================================================

      final Uri url = Uri.parse(
        '$baseUrl/drivers/by_user.php'
        '?user_id=$parsedUserId',
      );

      // ==========================================================
      // REQUEST
      // ==========================================================

      final http.Response response =
          await http
              .get(
                url,
                headers: {
                  'Accept':
                      'application/json',
                },
              )
              .timeout(requestTimeout);

      final Map<String, dynamic> decoded =
          _decodeResponse(response);

      // ==========================================================
      // ERRO HTTP
      // ==========================================================

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return {
          'success': false,
          'message':
              decoded['message']?.toString() ??
                  'Erro ao buscar status do motorista.',
          'status_code':
              response.statusCode,
        };
      }

      return decoded;
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'A API demorou mais de 10 segundos para responder.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // DECODIFICAR RESPOSTA DA API
  // ============================================================

  static Map<String, dynamic>
      _decodeResponse(
    http.Response response,
  ) {
    dynamic decoded;

    try {
      decoded =
          jsonDecode(response.body);
    } catch (_) {
      return {
        'success': false,
        'message':
            'A API retornou uma resposta inválida.',
        'status_code':
            response.statusCode,
      };
    }

    if (decoded
        is! Map<String, dynamic>) {
      return {
        'success': false,
        'message':
            'A API retornou um formato inválido.',
        'status_code':
            response.statusCode,
      };
    }

    return decoded;
  }
}