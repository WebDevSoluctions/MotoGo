import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../config/colors.dart';
import '../home/driver_home_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({
    super.key,
  });

  @override
  State<DriverLoginScreen> createState() =>
      _DriverLoginScreenState();
}

class _DriverLoginScreenState
    extends State<DriverLoginScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  // ============================================================
  // ESTADO
  // ============================================================

  bool obscurePassword = true;

  bool isLoading = false;

  final formKey =
      GlobalKey<FormState>();

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

Future<void> _login() async {
  if (isLoading) return;

  FocusScope.of(context).unfocus();

  if (!formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    isLoading = true;
  });

  final result = await AuthService.login(
    email: emailController.text.trim(),
    password: passwordController.text,
  );

  if (!mounted) return;

  setState(() {
    isLoading = false;
  });

  // ==========================================================
  // ERRO
  // ==========================================================

  if (result['success'] != true) {
    _showMessage(
      result['message']?.toString() ??
          'Não foi possível realizar o login.',
    );

    return;
  }

  // ==========================================================
  // USUÁRIO
  // ==========================================================

  final dynamic user = result['user'];

  if (user is! Map) {
    _showMessage(
      'Dados do motorista não foram encontrados.',
    );

    return;
  }

  final String userId =
      user['id']?.toString() ?? '';

  if (userId.isEmpty) {
    _showMessage(
      'ID do motorista não encontrado.',
    );

    return;
  }

  // ==========================================================
  // SALVAR LOGIN
  // ==========================================================

  await AuthService.saveLogin(
    token: 'motogo_$userId',
    userId: userId,
  );

  if (!mounted) return;

  // ==========================================================
  // ABRIR PAINEL
  // ==========================================================

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const DriverHomeScreen(),
    ),
  );
}

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),

        behavior:
            SnackBarBehavior.floating,
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
        child: Form(
          key: formKey,

          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              24,
              50,
              24,
              30,
            ),

            child: Column(
              children: [
                // ==================================================
                // LOGO
                // ==================================================

                Container(
                  width: 100,
                  height: 100,

                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.primary,

                    borderRadius:
                        BorderRadius.circular(
                      28,
                    ),
                  ),

                  child: const Icon(
                    Icons
                        .two_wheeler_rounded,

                    color:
                        Colors.white,

                    size: 52,
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                // ==================================================
                // TÍTULO
                // ==================================================

                const Text(
                  'Área do motorista',

                  style: TextStyle(
                    fontSize: 30,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 9,
                ),

                Text(
                  'Entre para começar a receber corridas.',

                  textAlign:
                      TextAlign.center,

                  style: TextStyle(
                    color:
                        Colors.grey.shade600,

                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 42,
                ),

                // ==================================================
                // E-MAIL
                // ==================================================

                TextFormField(
                  controller:
                      emailController,

                  keyboardType:
                      TextInputType.emailAddress,

                  textInputAction:
                      TextInputAction.next,

                  validator:
                      (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Digite seu e-mail.';
                    }

                    if (!value.contains(
                      '@',
                    )) {
                      return 'Digite um e-mail válido.';
                    }

                    return null;
                  },

                  decoration:
                      _inputDecoration(
                    hint:
                        'E-mail',

                    icon:
                        Icons.email_outlined,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // SENHA
                // ==================================================

                TextFormField(
                  controller:
                      passwordController,

                  obscureText:
                      obscurePassword,

                  textInputAction:
                      TextInputAction.done,

                  onFieldSubmitted:
                      (_) {
                    _login();
                  },

                  validator:
                      (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Digite sua senha.';
                    }

                    return null;
                  },

                  decoration:
                      _inputDecoration(
                    hint:
                        'Senha',

                    icon:
                        Icons.lock_outline,

                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },

                      icon: Icon(
                        obscurePassword
                            ? Icons
                                .visibility_off_outlined
                            : Icons
                                .visibility_outlined,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // ESQUECI SENHA
                // ==================================================

                Align(
                  alignment:
                      Alignment.centerRight,

                  child:
                      TextButton(
                    onPressed: () {
                      _showMessage(
                        'Recuperação de senha será conectada ao servidor.',
                      );
                    },

                    child:
                        const Text(
                      'Esqueci minha senha',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // ENTRAR
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
                            : _login,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primary,

                      foregroundColor:
                          Colors.white,

                      elevation: 0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),

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
                            'Entrar',

                            style:
                                TextStyle(
                              fontSize: 17,

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
                // CADASTRO
                // ==================================================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [
                    Text(
                      'Ainda não é motorista?',

                      style: TextStyle(
                        color:
                            Colors.grey.shade600,

                        fontSize: 13,
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      child:
                          const Text(
                        'Cadastre-se',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 25,
                ),

                // ==================================================
                // SEGURANÇA
                // ==================================================

                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    14,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.blue.withOpacity(
                      .06,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .shield_outlined,

                        color:
                            Colors.blue,

                        size: 21,
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      Expanded(
                        child: Text(
                          'Seus dados são protegidos pelo sistema MotoGo.',

                          style:
                              TextStyle(
                            color:
                                Colors.blue.shade800,

                            fontSize:
                                11.5,

                            height:
                                1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,

    required IconData icon,

    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText:
          hint,

      prefixIcon:
          Icon(icon),

      suffixIcon:
          suffixIcon,

      filled:
          true,

      fillColor:
          Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide(
          color:
              Colors.grey.shade200,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide(
          color:
              AppColors.primary,

          width:
              1.5,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            const BorderSide(
          color:
              Colors.red,
        ),
      ),
    );
  }
}