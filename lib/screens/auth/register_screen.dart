import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../controllers/register_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final RegisterController controller =
      RegisterController();

  // ============================================================
  // ESTADO
  // ============================================================

  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

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
  // CADASTRO
  // ============================================================

  Future<void> _register() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result =
        await controller.register();

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    // ==========================================================
    // SUCESSO
    // ==========================================================

    if (result['success'] == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ??
                'Conta criada com sucesso!',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(),
        ),
      );

      return;
    }

    // ==========================================================
    // ERRO
    // ==========================================================

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              'Não foi possível criar a conta.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
                height: 35,
              ),

              // ==================================================
              // VOLTAR
              // ==================================================

              Align(
                alignment:
                    Alignment.centerLeft,

                child: IconButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },

                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              // ==================================================
              // LOGO
              // ==================================================

              Container(
                width: 90,
                height: 90,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary,

                  borderRadius:
                      BorderRadius.circular(
                    26,
                  ),
                ),

                child: const Icon(
                  Icons.person_add_alt_1_rounded,

                  color: Colors.white,

                  size: 48,
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // TÍTULO
              // ==================================================

              const Text(
                'Criar conta',

                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Cadastre-se para usar o MotoGo',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 35,
              ),

              // ==================================================
              // NOME
              // ==================================================

              TextField(
                controller:
                    controller.nameController,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    const InputDecoration(
                  hintText:
                      'Nome completo',

                  prefixIcon:
                      Icon(
                    Icons.person_outline,
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // E-MAIL
              // ==================================================

              TextField(
                controller:
                    controller.emailController,

                keyboardType:
                    TextInputType.emailAddress,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    const InputDecoration(
                  hintText:
                      'E-mail',

                  prefixIcon:
                      Icon(
                    Icons.email_outlined,
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // TELEFONE
              // ==================================================

              TextField(
                controller:
                    controller.phoneController,

                keyboardType:
                    TextInputType.phone,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    const InputDecoration(
                  hintText:
                      'Telefone',

                  prefixIcon:
                      Icon(
                    Icons.phone_outlined,
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              TextField(
                controller: controller.cityController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Cidade',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                value: controller.stateController.text.isEmpty
                    ? null
                    : controller.stateController.text,
                decoration: const InputDecoration(
                  hintText: 'Estado',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: const [
                  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
                  'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
                ].map((uf) => DropdownMenuItem<String>(
                  value: uf,
                  child: Text(uf),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      controller.stateController.text = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 18),

              // ==================================================
              // SENHA
              // ==================================================

              TextField(
                controller:
                    controller.passwordController,

                obscureText:
                    obscurePassword,

                textInputAction:
                    TextInputAction.next,

                decoration:
                    InputDecoration(
                  hintText:
                      'Senha',

                  prefixIcon:
                      const Icon(
                    Icons.lock_outline,
                  ),

                  suffixIcon:
                      IconButton(
                    icon: Icon(
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
                height: 18,
              ),

              // ==================================================
              // CONFIRMAR SENHA
              // ==================================================

              TextField(
                controller:
                    controller
                        .confirmPasswordController,

                obscureText:
                    obscureConfirmPassword,

                textInputAction:
                    TextInputAction.done,

                onSubmitted: (_) {
                  _register();
                },

                decoration:
                    InputDecoration(
                  hintText:
                      'Confirmar senha',

                  prefixIcon:
                      const Icon(
                    Icons.lock_reset_outlined,
                  ),

                  suffixIcon:
                      IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons
                              .visibility_off
                          : Icons
                              .visibility,
                    ),

                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword =
                            !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // BOTÃO CADASTRAR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height: 58,

                child:
                    ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : _register,

                  child: isLoading
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
                          'Criar Conta',

                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // VOLTAR PARA LOGIN
              // ==================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [

                  const Text(
                    'Já possui uma conta? ',
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(),
                        ),
                      );
                    },

                    child:
                        const Text(
                      'Entrar',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}