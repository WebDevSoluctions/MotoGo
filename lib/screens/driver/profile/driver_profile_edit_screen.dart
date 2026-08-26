import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class DriverProfileEditScreen extends StatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  State<DriverProfileEditScreen> createState() =>
      _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState
    extends State<DriverProfileEditScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  String email = '';
  String city = '';
  String state = '';
  String driverType = '';
  String verification = '';
  double rating = 0;
  int rides = 0;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userIdString = await AuthService.getUserId();
    final userId = int.tryParse(userIdString ?? '');

    if (userId == null || userId <= 0) {
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }

    try {
      final response = await ApiService.getDriverProfile(userId: userId);

      if (!mounted) return;

      if (response['success'] == true) {
        final rawProfile = response['profile'];
        final profile = rawProfile is Map
            ? Map<String, dynamic>.from(rawProfile)
            : <String, dynamic>{};

        nameController.text = profile['name']?.toString() ?? '';
        phoneController.text = profile['phone']?.toString() ?? '';
        email = profile['email']?.toString() ?? '';
        city = profile['city']?.toString() ?? '';
        state = profile['state']?.toString() ?? '';
        cityController.text = city;
        driverType = profile['driver_type']?.toString() ?? '';
        verification =
            profile['verification_status']?.toString() ?? '';

        rating =
            double.tryParse(profile['rating']?.toString() ?? '') ?? 0;

        rides =
            int.tryParse(profile['total_rides']?.toString() ?? '') ?? 0;
      }
    } catch (_) {
      // Mantém a tela utilizável mesmo se a API estiver temporariamente
      // indisponível.
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final userIdString = await AuthService.getUserId();
    final userId = int.tryParse(userIdString ?? '');

    if (userId == null || userId <= 0) return;

    setState(() => saving = true);

    try {
      final response = await ApiService.updateDriverProfile(
        userId: userId,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        city: cityController.text.trim(),
        state: state.trim().toUpperCase(),
        driverType: driverType,
      );

      if (!mounted) return;

      setState(() => saving = false);

      final success = response['success'] == true;
      final message =
          response['message']?.toString() ??
          (success
              ? 'Perfil atualizado com sucesso.'
              : 'Não foi possível atualizar o perfil.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              success ? AppColors.primary : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus dados'),
      ),
      backgroundColor: const Color(0xFFF5F7F6),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field(
                  'Nome',
                  nameController,
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _field(
                  'Telefone',
                  phoneController,
                  Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _info(
                  'E-mail',
                  email,
                  Icons.email_outlined,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    labelText: 'Cidade de operação',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: state.isEmpty ? null : state,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.map_outlined),
                    labelText: 'Estado',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
                    'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
                  ].map((uf) => DropdownMenuItem<String>(value: uf, child: Text(uf))).toList(),
                  onChanged: (value) { if (value != null) setState(() => state = value); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: driverType.isEmpty ? null : driverType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.two_wheeler_outlined),
                    labelText: 'Tipo de motorista',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'moto',
                      child: Text('Mototáxi'),
                    ),
                    DropdownMenuItem(
                      value: 'carro',
                      child: Text('Carro'),
                    ),
                    DropdownMenuItem(
                      value: 'delivery_moto',
                      child: Text('Entrega de moto'),
                    ),
                    DropdownMenuItem(
                      value: 'delivery_bicicleta',
                      child: Text('Entrega de bicicleta'),
                    ),
                    DropdownMenuItem(
                      value: 'delivery_pedestre',
                      child: Text('Entrega a pé'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => driverType = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                _info(
                  'Verificação',
                  verification,
                  Icons.verified_outlined,
                ),
                const SizedBox(height: 12),
                _info(
                  'Avaliação',
                  rating.toStringAsFixed(1),
                  Icons.star_outline,
                ),
                const SizedBox(height: 12),
                _info(
                  'Corridas concluídas',
                  rides.toString(),
                  Icons.route_outlined,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Salvar alterações'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _info(
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
