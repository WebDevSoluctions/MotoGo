import '../driver/auth/driver_register_screen.dart';

import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../controllers/login_controller.dart';
import '../client/main_navigation.dart';
import '../driver/home/driver_home_screen.dart';
import '../admin/admin_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // LOGIN CONTROLLER
  // ============================================================

  final LoginController controller =
      LoginController();

  // ============================================================
  // ESTADO
  // ============================================================

  bool obscurePassword = true;

  bool isLoading = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  // ============================================================
// LOGIN
// ============================================================

Future<void> _login() async {
  if (isLoading) {
    return;
  }

  FocusScope.of(context).unfocus();

  setState(() {
    isLoading = true;
  });

  final result = await controller.login();

  if (!mounted) {
    return;
  }

  setState(() {
    isLoading = false;
  });

  // ==========================================================
  // VERIFICAR SUCESSO
  // ==========================================================

  if (result['success'] == true) {
    final String accountType =
        result['account_type']?.toString() ??
            'client';

    // ========================================================
    // ADMIN
    // ========================================================

    if (accountType == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const AdminHomeScreen(),
        ),
      );

      return;
    }

    // ========================================================
    // MOTORISTA
    // ========================================================

    if (accountType == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DriverHomeScreen(),
        ),
      );

      return;
    }

    // ========================================================
    // CLIENTE
    // ========================================================

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MainNavigation(),
      ),
    );

    return;
  }

  // ==========================================================
  // LOGIN COM ERRO
  // ==========================================================

  final String message =
      result['message']?.toString() ??
          'Não foi possível realizar o login.';

  _showMessage(
    message,
    error: true,
  );
}
  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),

        behavior:
            SnackBarBehavior.floating,

        backgroundColor:
            error
                ? Colors.red.shade700
                : Colors.green.shade700,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            children: [
              const SizedBox(
                height: 70,
              ),

              // ==================================================
              // LOGO
              // ==================================================

              Container(
                width: 110,
                height: 110,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary,

                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .two_wheeler_rounded,

                  color:
                      Colors.white,

                  size: 60,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // TÍTULO
              // ==================================================

              const Text(
                'Bem-vindo',

                style:
                    TextStyle(
                  fontSize: 32,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Entre na sua conta',

                style:
                    TextStyle(
                  color:
                      Colors.grey,

                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 45,
              ),

              // ==================================================
              // E-MAIL
              // ==================================================

              TextField(
                controller:
                    controller
                        .emailController,

                keyboardType:
                    TextInputType
                        .emailAddress,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    const InputDecoration(
                  hintText:
                      'E-mail',

                  prefixIcon:
                      Icon(
                    Icons
                        .email_outlined,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // SENHA
              // ==================================================

              TextField(
                controller:
                    controller
                        .passwordController,

                obscureText:
                    obscurePassword,

                textInputAction:
                    TextInputAction.done,

                onSubmitted: (_) {
                  _login();
                },

                decoration:
                    InputDecoration(
                  hintText:
                      'Senha',

                  prefixIcon:
                      const Icon(
                    Icons
                        .lock_outline,
                  ),

                  suffixIcon:
                      IconButton(
                    icon:
                        Icon(
                      obscurePassword
                          ? Icons
                              .visibility_off
                          : Icons
                              .visibility,
                    ),

                    onPressed: () {
                      setState(() {
                        obscurePassword =
                            !obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(
                height: 35,
              ),

              // ==================================================
              // ENTRAR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height:
                    58,

                child:
                    ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : _login,

                  child:
                      isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,

                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Entrar',

                              style:
                                  TextStyle(
                                fontSize:
                                    18,

                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // CRIAR CONTA
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height:
                    58,

                child:
                    OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (_) =>
                            const RegisterScreen(),
                      ),
                    );
                  },

                  child:
                      const Text(
                    'Criar Conta',
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // CADASTRO MOTORISTA
              // ==================================================

              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverRegisterScreen(),
                    ),
                  );
                },

                icon:
                    const Icon(
                  Icons
                      .two_wheeler_outlined,
                ),

                label:
                    const Text(
                  'Quero ser motorista',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}