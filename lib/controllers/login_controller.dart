import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginController {
  // ============================================================
  // CAMPOS
  // ============================================================

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> login() async {
    final String email =
        emailController.text.trim();

    final String password =
        passwordController.text;

    // ==========================================================
    // VALIDAR E-MAIL
    // ==========================================================

    if (email.isEmpty) {
      return {
        'success': false,
        'message': 'Digite seu e-mail.',
      };
    }

    // ==========================================================
    // VALIDAR SENHA
    // ==========================================================

    if (password.isEmpty) {
      return {
        'success': false,
        'message': 'Digite sua senha.',
      };
    }

    try {
      // ========================================================
      // CHAMAR API
      // ========================================================

      final Map<String, dynamic> result =
          await ApiService.login(
        email: email,
        password: password,
      );

      // ========================================================
      // LOGIN COM ERRO
      // ========================================================

      if (result['success'] != true) {
        return result;
      }

      // ========================================================
      // PEGAR USUÁRIO
      // ========================================================

      final dynamic userData =
          result['user'];

      if (userData is! Map<String, dynamic>) {
        return {
          'success': false,
          'message':
              'A API não retornou os dados do usuário.',
        };
      }

      // ========================================================
      // USER ID
      // ========================================================

      final dynamic rawUserId =
          userData['id'];

      if (rawUserId == null) {
        return {
          'success': false,
          'message':
              'A API não retornou o ID do usuário.',
        };
      }

      final String userId =
          rawUserId.toString();

      // ========================================================
      // ACCOUNT TYPE
      // ========================================================

      final dynamic accountType =
          result['account_type'];

      // ========================================================
      // STATUS MOTORISTA
      // ========================================================

      final dynamic verificationStatus =
          result['verification_status'];

      // ========================================================
      // TOKEN
      // ========================================================

      final dynamic token =
          result['token'];

      // ========================================================
      // SALVAR DADOS
      // ========================================================

      final prefs =
          await AuthService.getPrefs();

      await prefs.setString(
        'user_id',
        userId,
      );

      // ========================================================
      // SALVAR TIPO DA CONTA
      // ========================================================

      if (accountType != null) {
        await prefs.setString(
          'account_type',
          accountType.toString(),
        );
      }

      // ========================================================
      // SALVAR STATUS DO MOTORISTA
      // ========================================================

      if (verificationStatus != null) {
        await prefs.setString(
          'verification_status',
          verificationStatus.toString(),
        );
      }

      // ========================================================
      // SALVAR TOKEN SE EXISTIR
      // ========================================================

      if (token != null &&
          token.toString().isNotEmpty) {
        await prefs.setString(
          'token',
          token.toString(),
        );
      }

      // ========================================================
      // RETORNAR RESULTADO
      // ========================================================

      return result;

    } catch (e) {
      return {
        'success': false,
        'message':
            'Erro ao realizar login.',
        'error':
            e.toString(),
      };
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}