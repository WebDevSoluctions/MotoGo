import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../widgets/custom_appbar.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../auth/login_screen.dart';
import '../../driver/auth/driver_register_screen.dart';
import '../motogo_plus_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ============================================================
  // CONTROLADORES
  // ============================================================

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _cityController =
      TextEditingController();

  final TextEditingController _stateController =
      TextEditingController();

  // ============================================================
  // ESTADO
  // ============================================================

  bool _savingProfile = false;

  String _name = '';
  String _email = '';
  String _phone = '';
  String _city = '';
  String _state = '';
  int _points = 0;
  String _level = 'Bronze';
  int _globalRank = 0;
  int _weeklyRank = 0;
  double _rating = 5.0;
  int _rides = 0;
  int _deliveries = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
    _loadRanking();
  }

  Future<void> _loadProfile() async {
    final id = int.tryParse(await AuthService.getUserId() ?? '');
    if (id == null) return;
    final response = await ApiService.getUserProfile(userId: id);
    final user = response['user'];
    if (!mounted || user is! Map) return;
    final name = user['name']?.toString().trim() ?? '';
    final email = user['email']?.toString().trim() ?? '';
    final phone = user['phone']?.toString().trim() ?? '';
    final city = user['city']?.toString().trim() ?? '';
    final state = user['state']?.toString().trim().toUpperCase() ?? '';
    final rating = double.tryParse(user['rating']?.toString() ?? '') ?? 5.0;
    final rides = int.tryParse(user['total_rides']?.toString() ?? '') ?? 0;
    final deliveries = int.tryParse(user['total_deliveries']?.toString() ?? '') ?? 0;
    setState(() {
      if (name.isNotEmpty) _name = name;
      _email = email;
      _phone = phone;
      _city = city;
      _state = state;
      _rating = rating;
      _rides = rides;
      _deliveries = deliveries;
      _nameController.text = _name;
      _emailController.text = _email;
      _phoneController.text = _phone;
      _cityController.text = _city;
      _stateController.text = _state;
    });
  }

  Future<void> _loadRanking() async {
    final id = int.tryParse(await AuthService.getUserId() ?? '');
    if (id == null) return;
    final response = await ApiService.getRewardsDashboard(id);
    final dashboard = response['dashboard'];
    if (!mounted || dashboard is! Map) return;
    setState(() {
      _points = int.tryParse(dashboard['points']?.toString() ?? '0') ?? 0;
      _level = dashboard['level']?.toString() ?? 'Bronze';
      _globalRank = int.tryParse(dashboard['global_rank']?.toString() ?? '0') ?? 0;
      _weeklyRank = int.tryParse(dashboard['weekly_rank']?.toString() ?? '0') ?? 0;
    });
  }

  String _levelMedal() {
    switch (_level) {
      case 'VIP': return '💎';
      case 'Ouro': return '🥇';
      case 'Prata': return '🥈';
      default: return '🥉';
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: const CustomAppBar(
        title: "Meu Perfil",
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 10),

            // ======================================================
            // FOTO
            // ======================================================

            Container(
              width: 120,
              height: 120,

              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.15),
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.person,
                size: 65,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 20),

            // ======================================================
            // NOME
            // ======================================================

            Text(
              _name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            // ======================================================
            // EMAIL
            // ======================================================

            Text(
              _email,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 18),

            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MotoGoPlusScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(_levelMedal(), style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$_level • $_points pontos', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 4),
                          Text('🌎 ${_globalRank > 0 ? '#$_globalRank' : '--'}  •  📅 ${_weeklyRank > 0 ? '#$_weeklyRank' : '--'}', style: TextStyle(color: Colors.grey.shade700)),
                        ]),
                      ),
                      const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ======================================================
            // DADOS DO USUÁRIO
            // ======================================================

            _item(
              Icons.phone_android,
              "Telefone",
              _phone,
            ),

            _item(
              Icons.location_on_outlined,
              "Cidade",
              _city.isNotEmpty
                  ? '$_city${_state.isNotEmpty ? ' - $_state' : ''}'
                  : 'Não informado',
            ),

            _item(
              Icons.badge_outlined,
              "Tipo de Conta",
              "Cliente",
            ),

            _item(
              Icons.star_outline,
              "Avaliação",
              '${_rating.toStringAsFixed(1)} ⭐',
            ),

            _item(
              Icons.history,
              "Corridas",
              _rides.toString(),
            ),

            _item(
              Icons.two_wheeler_outlined,
              "Entregas",
              _deliveries.toString(),
            ),

            const SizedBox(height: 20),

            // ======================================================
            // SEJA MOTORISTA
            // ======================================================

            _buildDriverCard(context),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MotoGoPlusScreen()));
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('MotoGo+ • Recursos especiais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 15),

            // ======================================================
            // EDITAR PERFIL
            // ======================================================

            SizedBox(
              width: double.infinity,
              height: 56,

              child: ElevatedButton.icon(
                onPressed: _savingProfile
                    ? null
                    : () {
                        _showEditProfileDialog(context);
                      },

                icon: const Icon(
                  Icons.edit,
                ),

                label: const Text(
                  "Editar Perfil",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ======================================================
            // SAIR
            // ======================================================

            SizedBox(
              width: double.infinity,
              height: 56,

              child: OutlinedButton.icon(
                onPressed: () {
                  _showLogoutDialog(context);
                },

                icon: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),

                label: const Text(
                  "Sair",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton.icon(
                onPressed: () => _showDeleteAccountDialog(context),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Excluir minha conta',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EDITAR PERFIL
  // ============================================================

  void _showEditProfileDialog(
    BuildContext context,
  ) {
    _nameController.text = _name;
    _emailController.text = _email;
    _phoneController.text = _phone;
    _cityController.text = _city;
    _stateController.text = _state;

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                "Editar Perfil",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // ==================================================
                    // NOME
                    // ==================================================

                    TextField(
                      controller: _nameController,

                      textInputAction:
                          TextInputAction.next,

                      decoration:
                          InputDecoration(
                        labelText: "Nome",
                        prefixIcon:
                            const Icon(
                          Icons.person_outline,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    TextField(
                      controller: _emailController,

                      keyboardType:
                          TextInputType.emailAddress,

                      textInputAction:
                          TextInputAction.next,

                      decoration:
                          InputDecoration(
                        labelText: "E-mail",
                        prefixIcon:
                            const Icon(
                          Icons.email_outlined,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // TELEFONE
                    // ==================================================

                    TextField(
                      controller: _phoneController,

                      keyboardType:
                          TextInputType.phone,

                      decoration:
                          InputDecoration(
                        labelText: "Telefone",
                        prefixIcon:
                            const Icon(
                          Icons.phone_outlined,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Cidade',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: _stateController.text.isEmpty ? null : _stateController.text,
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: const Icon(Icons.map_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
                        'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
                      ].map((uf) => DropdownMenuItem<String>(value: uf, child: Text(uf))).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => _stateController.text = value);
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                // ======================================================
                // CANCELAR
                // ======================================================

                TextButton(
                  onPressed: _savingProfile
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },

                  child: const Text(
                    "Cancelar",
                  ),
                ),

                // ======================================================
                // SALVAR
                // ======================================================

                ElevatedButton(
                  onPressed: _savingProfile
                      ? null
                      : () async {
                          final name =
                              _nameController
                                  .text
                                  .trim();

                          final email =
                              _emailController
                                  .text
                                  .trim();

                          final phone =
                              _phoneController
                                  .text
                                  .trim();
                          final city = _cityController.text.trim();
                          final state = _stateController.text.trim().toUpperCase();

                          if (name.isEmpty ||
                              email.isEmpty ||
                              phone.isEmpty ||
                              city.length < 2 ||
                              state.length != 2) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Preencha todos os campos.",
                                ),
                                backgroundColor:
                                    Colors.red,
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            _savingProfile = true;
                          });

                          final result =
                              await AuthService
                                  .updateProfile(
                            name: name,
                            email: email,
                            phone: phone,
                            city: city,
                            state: state,
                          );

                          if (!mounted) {
                            return;
                          }

                          if (result['success'] ==
                              true) {
                            setState(() {
                              _name = name;
                              _email = email;
                              _phone = phone;
                              _city = city;
                              _state = state;
                              _nameController.text = name;
                              _emailController.text = email;
                              _phoneController.text = phone;
                              _cityController.text = city;
                              _stateController.text = state;
                            });

                            if (dialogContext
                                .mounted) {
                              Navigator.pop(
                                dialogContext,
                              );
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Perfil atualizado com sucesso.",
                                ),
                                backgroundColor:
                                    Colors.green,
                              ),
                            );
                          } else {
                            setDialogState(() {
                              _savingProfile =
                                  false;
                            });

                            final message =
                                result['message']
                                        ?.toString() ??
                                    "Não foi possível atualizar o perfil.";

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content:
                                    Text(
                                  message,
                                ),
                                backgroundColor:
                                    Colors.red,
                              ),
                            );
                          }
                        },

                  child: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Salvar",
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CARD MOTORISTA
  // ============================================================

  Widget _buildDriverCard(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(.82),
          ],

          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                AppColors.primary
                    .withOpacity(.20),

            blurRadius: 18,

            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,

                decoration: BoxDecoration(
                  color:
                      Colors.white
                          .withOpacity(.18),

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: const Icon(
                  Icons.two_wheeler,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Seja um motorista MotoGo",

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      "Ganhe dinheiro realizando corridas.",

                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            "Cadastre-se como motorista e envie seus dados "
            "para análise da equipe MotoGo.",

            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,

            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (_) =>
                        const DriverRegisterScreen(),
                  ),
                );
              },

              icon: const Icon(
                Icons.arrow_forward,
              ),

              label: const Text(
                "Quero ser motorista",

                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.white,

                foregroundColor:
                    AppColors.primary,

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ITEM DO PERFIL
  // ============================================================

  Widget _item(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(.05),

            blurRadius: 12,
          ),
        ],
      ),

      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              AppColors.primary
                  .withOpacity(.12),

          child: Icon(
            icon,
            color: AppColors.primary,
          ),
        ),

        title: Text(
          title,

          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(
          value,
        ),

        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: const Text(
            'Esta ação solicita a exclusão da sua conta e dos dados associados. '
            'Depois de confirmada, você será desconectado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir conta'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final result = await AuthService.deleteAccount();

    if (!context.mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              'Não foi possível excluir a conta.',
        ),
      ),
    );
  }

  // ============================================================
  // CONFIRMAR LOGOUT
  // ============================================================

  static void _showLogoutDialog(
    BuildContext context,
  ) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Sair da conta?",
          ),

          content: const Text(
            "Você será desconectado do MotoGo.",
          ),

          actions: [
            // ======================================================
            // CANCELAR
            // ======================================================

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child: const Text(
                "Cancelar",
              ),
            ),

            // ======================================================
            // SAIR
            // ======================================================

            TextButton(
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                await AuthService.logout();

                if (!context.mounted) {
                  return;
                }

                Navigator.of(
                  context,
                ).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginScreen(),
                  ),
                  (route) => false,
                );
              },

              child: const Text(
                "Sair",

                style: TextStyle(
                  color: Colors.red,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}