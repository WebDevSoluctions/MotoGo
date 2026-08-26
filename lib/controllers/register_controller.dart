import 'package:flutter/material.dart';

import '../services/api_service.dart';

class RegisterController {
  // ============================================================
  // CAMPOS
  // ============================================================

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController cityController =
      TextEditingController();

  final TextEditingController stateController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  // ============================================================
  // CADASTRO
  // ============================================================

  Future<Map<String, dynamic>> register() async {
    final String name =
        nameController.text.trim();

    final String email =
        emailController.text.trim();

    final String phone =
        phoneController.text.trim();

    final String city =
        cityController.text.trim();

    final String state =
        stateController.text.trim().toUpperCase();

    final String password =
        passwordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    // ==========================================================
    // VALIDAR NOME
    // ==========================================================

    if (name.isEmpty) {
      return {
        'success': false,
        'message': 'Digite seu nome.',
      };
    }

    if (name.length < 2) {
      return {
        'success': false,
        'message':
            'Digite seu nome completo.',
      };
    }

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
    // VALIDAR TELEFONE
    // ==========================================================

    if (phone.isEmpty) {
      return {
        'success': false,
        'message': 'Digite seu telefone.',
      };
    }

    // ==========================================================
    // VALIDAR CIDADE / ESTADO
    // ==========================================================

    if (city.length < 2) {
      return {
        'success': false,
        'message': 'Digite sua cidade.',
      };
    }

    if (state.length != 2) {
      return {
        'success': false,
        'message': 'Selecione seu estado.',
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

    if (password.length < 6) {
      return {
        'success': false,
        'message':
            'A senha deve possuir pelo menos 6 caracteres.',
      };
    }

    // ==========================================================
    // CONFIRMAR SENHA
    // ==========================================================

    if (confirmPassword.isEmpty) {
      return {
        'success': false,
        'message':
            'Confirme sua senha.',
      };
    }

    if (password != confirmPassword) {
      return {
        'success': false,
        'message':
            'As senhas não coincidem.',
      };
    }

    // ==========================================================
    // API
    // ==========================================================

    try {
      final result =
          await ApiService.register(
        name: name,
        email: email,
        phone: phone,
        city: city,
        state: state,
        password: password,
      );

      return result;
    } catch (e) {
      return {
        'success': false,
        'message':
            'Erro ao criar conta.',
      };
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }
}