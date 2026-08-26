import '../config/api_config.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class AuthService {
  // ============================================================
  // PREFERENCES
  // ============================================================

  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // ============================================================
  // API
  // ============================================================

  static const String baseUrl =
      ApiConfig.baseUrl;

  // ============================================================
  // CHAVES
  // ============================================================

  static const String tokenKey =
      'token';

  static const String userIdKey =
      'user_id';

  static const String accountTypeKey =
      'account_type';

  static const String verificationStatusKey =
      'verification_status';

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/auth/login.php',
    );

    try {
      final http.Response response =
          await http.post(
        url,

        headers: {
          'Content-Type':
              'application/json',

          'Accept':
              'application/json',
        },

        body: jsonEncode({
          'email':
              email.trim(),

          'password':
              password,
        }),
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      if (decoded
          is! Map<String, dynamic>) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      // ========================================================
      // LOGIN BEM-SUCEDIDO
      // ========================================================

      if (decoded['success'] == true) {
        final user =
            decoded['user'];

        final accountType =
            decoded['account_type'];

        final verificationStatus =
            decoded['verification_status'];

        // ======================================================
        // SALVAR DADOS DO USUÁRIO
        // ======================================================

        if (user
            is Map<String, dynamic>) {
          final userId =
              user['id'];

          if (userId != null) {
            final prefs =
                await SharedPreferences
                    .getInstance();

            await prefs.setString(
              userIdKey,
              userId.toString(),
            );
          }
        }

        // ======================================================
        // SALVAR TIPO DA CONTA
        // ======================================================

        if (accountType != null) {
          final prefs =
              await SharedPreferences
                  .getInstance();

          await prefs.setString(
            accountTypeKey,
            accountType.toString(),
          );

          // Agenda as mensagens motivacionais das 08:00 assim que
          // o usuário entra na conta, sem precisar fechar/reabrir o app.
          final normalizedAccountType =
              accountType.toString().toLowerCase();

          if (normalizedAccountType == 'driver' ||
              normalizedAccountType == 'client') {
            await NotificationService.scheduleDailyMotivation(
              accountType: normalizedAccountType,
            );
          }
        }

        // ========================================================
        // SALVAR STATUS DO MOTORISTA
        // ======================================================

        if (verificationStatus !=
            null) {
          final prefs =
              await SharedPreferences
                  .getInstance();

          await prefs.setString(
            verificationStatusKey,
            verificationStatus.toString(),
          );
        }
      }

      return decoded;
    } catch (e) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
      };
    }
  }

  // ============================================================
  // CADASTRO CLIENTE
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/auth/register.php',
    );

    try {
      final http.Response response =
          await http.post(
        url,

        headers: {
          'Content-Type':
              'application/json',

          'Accept':
              'application/json',
        },

        body: jsonEncode({
          'name':
              name.trim(),

          'phone':
              phone.trim(),

          'email':
              email.trim(),

          'password':
              password,
        }),
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      if (decoded
          is! Map<String, dynamic>) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      return decoded;
    } catch (e) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
      };
    }
  }

  // ============================================================
  // SALVAR LOGIN
  // ============================================================

  static Future<void> saveLogin({
    required String token,
    required String userId,
  }) async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      tokenKey,
      token,
    );

    await prefs.setString(
      userIdKey,
      userId,
    );
  }

  // ============================================================
  // VERIFICAR LOGIN
  // ============================================================

  static Future<bool> isLogged() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    return prefs.containsKey(
      userIdKey,
    );
  }

  // ============================================================
  // SABER SE É MOTORISTA
  // ============================================================

  static Future<bool> isDriver() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    final accountType =
        prefs.getString(
      accountTypeKey,
    );

    return accountType ==
        'driver';
  }

  // ============================================================
  // SABER SE É CLIENTE
  // ============================================================

  static Future<bool> isClient() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    final accountType =
        prefs.getString(
      accountTypeKey,
    );

    return accountType ==
        'client';
  }

  // ============================================================
  // STATUS DO MOTORISTA
  // ============================================================

  static Future<String?>
      getVerificationStatus() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    return prefs.getString(
      verificationStatusKey,
    );
  }

  // ============================================================
  // TIPO DA CONTA
  // ============================================================

  static Future<String?>
      getAccountType() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    return prefs.getString(
      accountTypeKey,
    );
  }

  // ============================================================
  // USER ID
  // ============================================================

  static Future<String?>
      getUserId() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    return prefs.getString(
      userIdKey,
    );
  }

  // ============================================================
  // TOKEN
  // ============================================================

  static Future<String?>
      getToken() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    return prefs.getString(
      tokenKey,
    );
  }

  // ============================================================
  // ATUALIZAR PERFIL
  // ============================================================

  static Future<Map<String, dynamic>>
      updateProfile({
    required String name,
    required String email,
    required String phone,
    String city = '',
    String state = '',
  }) async {
    final userId =
        await getUserId();

    // ==========================================================
    // VERIFICAR SESSÃO
    // ==========================================================

    if (userId == null ||
        userId.isEmpty) {
      return {
        'success': false,
        'message':
            'Sessão do usuário não encontrada.',
      };
    }

    final Uri url = Uri.parse(
      '$baseUrl/auth/update_profile.php',
    );

    try {
      // ========================================================
      // REQUISIÇÃO
      // ========================================================

      final http.Response response =
          await http.post(
        url,

        headers: {
          'Content-Type':
              'application/json',

          'Accept':
              'application/json',
        },

        body: jsonEncode({
          'user_id':
              int.tryParse(userId) ??
                  userId,

          'name':
              name.trim(),

          'email':
              email.trim(),

          'phone':
              phone.trim(),

          'city':
              city.trim(),

          'state':
              state.trim().toUpperCase(),
        }),
      );

      // ========================================================
      // DECODIFICAR
      // ========================================================

      dynamic decoded;

      try {
        decoded =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      // ========================================================
      // VALIDAR RESPOSTA
      // ========================================================

      if (decoded
          is! Map<String, dynamic>) {
        return {
          'success': false,
          'message':
              'Resposta inválida da API.',
        };
      }

      return decoded;
    } catch (_) {
      return {
        'success': false,
        'message':
            'Não foi possível conectar à API.',
      };
    }
  }

  // ============================================================
  // EXCLUIR CONTA
  // ============================================================

  static Future<Map<String, dynamic>> deleteAccount() async {
    final userId = await getUserId();
    final accountType = await getAccountType();

    if (userId == null || userId.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Sessão do usuário não encontrada.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/delete_account.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': int.tryParse(userId) ?? userId,
          'account_type': accountType ?? '',
        }),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Resposta inválida da API.',
        };
      }

      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Resposta inválida da API.',
        };
      }

      if (decoded['success'] == true) {
        await logout();
      }

      return decoded;
    } catch (_) {
      return {
        'success': false,
        'message': 'Não foi possível excluir a conta agora.',
      };
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    // Remove as mensagens agendadas para que a conta anterior
    // não continue recebendo mensagens depois do logout.
    await NotificationService.cancelDailyMotivation();

    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove(
      tokenKey,
    );

    await prefs.remove(
      userIdKey,
    );

    await prefs.remove(
      accountTypeKey,
    );

    await prefs.remove(
      verificationStatusKey,
    );
  }
}