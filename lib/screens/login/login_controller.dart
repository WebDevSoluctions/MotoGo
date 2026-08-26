import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class LoginController {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  // ============================================================
  // ESTADO
  // ============================================================

  bool isLoading = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> login() async {
    final String email =
        emailController.text.trim();

    final String password =
        passwordController.text;

    // ------------------------------------------------------------
    // VALIDAR E-MAIL
    // ------------------------------------------------------------

    if (email.isEmpty) {
      return {
        'success': false,
        'message': 'Digite seu e-mail.',
      };
    }

    // ------------------------------------------------------------
    // VALIDAR SENHA
    // ------------------------------------------------------------

    if (password.isEmpty) {
      return {
        'success': false,
        'message': 'Digite sua senha.',
      };
    }

    // ------------------------------------------------------------
    // INICIAR LOGIN
    // ------------------------------------------------------------

    isLoading = true;

    try {
      final Map<String, dynamic> result =
          await ApiService.login(
        email: email,
        password: password,
      );

      return result;
    } catch (e) {
      return {
        'success': false,
        'message':
            'Erro ao realizar login.',
      };
    } finally {
      isLoading = false;
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