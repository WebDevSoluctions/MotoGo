import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final Map<String, TextEditingController> c = {};
  final fields = <String, String>{
    'mototaxi_base': 'Mototáxi • taxa base',
    'mototaxi_per_km': 'Mototáxi • R\$ por km',
    'car_base': 'Carro • taxa base',
    'car_per_km': 'Carro • R\$ por km',
    'delivery_base': 'Delivery moto • taxa base',
    'delivery_per_km': 'Delivery moto • R\$ por km',
    'bicycle_base': 'Delivery bike • taxa base',
    'bicycle_per_km': 'Delivery bike • R\$ por km',
    'commission_percent': 'Comissão MotoGo (%)',
    'long_distance_limit_km': 'Limite para viagem longa (km)',
    'viagem_base': 'Viagem longa • taxa base',
    'viagem_per_km': 'Viagem longa • R\$ por km',
  };
  List<Map<String, dynamic>> cities = [];
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> adminAccounts = [];
  bool loadingAdmins = false;

  @override
  void initState() {
    super.initState();
    for (final k in fields.keys) c[k] = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final controller in c.values) controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ApiService.getAdminSettings();
    if (!mounted) return;
    if (r['success'] == true) {
      final settings = Map<String, dynamic>.from(r['settings'] ?? {});
      for (final k in fields.keys) c[k]!.text = (settings[k] ?? 0).toString();
      final raw = r['cities'];
      cities = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      error = null;
    } else {
      error = r['message']?.toString() ?? 'Erro';
    }

    await _loadAdmins();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<int> _currentAdminId() async {
    final prefs = await AuthService.getPrefs();
    return int.tryParse(prefs.getString('user_id') ?? '') ?? 0;
  }

  Future<void> _loadAdmins() async {
    if (mounted) setState(() => loadingAdmins = true);
    final currentId = await _currentAdminId();
    final r = currentId > 0
        ? await ApiService.getAdminAccounts(currentAdminId: currentId)
        : {'success': false, 'message': 'Sessão administrativa não encontrada.'};
    if (!mounted) return;
    final raw = r['admins'];
    adminAccounts = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
    if (r['success'] != true && error == null) {
      error = r['message']?.toString();
    }
    setState(() => loadingAdmins = false);
  }

  Future<void> _createAdmin() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Criar conta administrativa'),
            content: SizedBox(
              width: 430,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('A nova conta poderá entrar no painel como administrador.', style: TextStyle(color: Colors.black54)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().length < 2 ? 'Informe o nome.' : null),
                      const SizedBox(height: 10),
                      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v == null || !v.contains('@') ? 'Informe um e-mail válido.' : null),
                      const SizedBox(height: 10),
                      TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', prefixIcon: Icon(Icons.phone_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o telefone.' : null),
                      const SizedBox(height: 10),
                      TextFormField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setDialogState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 6 ? 'Mínimo de 6 caracteres.' : null),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final currentId = await _currentAdminId();
                if (currentId <= 0) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                  if (mounted) _showMessage('Sessão administrativa não encontrada. Faça login novamente.');
                  return;
                }
                final r = await ApiService.createAdminAccount(
                  currentAdminId: currentId,
                  name: name.text.trim(),
                  email: email.text.trim(),
                  phone: phone.text.trim(),
                  password: password.text,
                );
                if (!mounted) return;
                _showMessage(r['message']?.toString() ?? 'Operação concluída.');
                if (r['success'] == true && dialogContext.mounted) Navigator.pop(dialogContext, true);
              }, child: const Text('Criar administrador')),
            ],
          ),
        );
      },
    );

    name.dispose(); email.dispose(); phone.dispose(); password.dispose();
    if (result == true) await _loadAdmins();
  }

  Future<void> _toggleAdmin(Map<String, dynamic> admin) async {
    final adminId = int.tryParse(admin['admin_id']?.toString() ?? '') ?? 0;
    final currentId = await _currentAdminId();
    if (adminId <= 0 || currentId <= 0) return;
    final active = admin['admin_status']?.toString() == 'active';
    final r = await ApiService.setAdminAccountStatus(
      currentAdminId: currentId,
      adminId: adminId,
      status: active ? 'inactive' : 'active',
    );
    if (!mounted) return;
    _showMessage(r['message']?.toString() ?? 'Operação concluída.');
    if (r['success'] == true) await _loadAdmins();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final settings = <String, dynamic>{};
    for (final k in fields.keys) {
      settings[k] = double.tryParse(c[k]!.text.replaceAll(',', '.')) ?? 0;
    }
    final r = await ApiService.saveAdminSettings(settings);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r['message']?.toString() ?? 'Configurações salvas'),
      backgroundColor: r['success'] == true ? const Color(0xFF00C985) : Colors.red,
    ));
    if (r['success'] == true) await _load();
  }

  Future<void> _addCity() async {
    final city = TextEditingController();
    final state = TextEditingController(text: 'MG');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Adicionar cidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: city, decoration: const InputDecoration(labelText: 'Cidade')),
            TextField(controller: state, decoration: const InputDecoration(labelText: 'Estado')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok == true) {
      final r = await ApiService.addAdminCity(city: city.text, state: state.text);
      if (r['success'] == true) await _load();
    }
    city.dispose(); state.dispose();
  }

  Future<void> _deleteCity(int id) async {
    final r = await ApiService.deleteAdminCity(id: id);
    if (r['success'] == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações MotoGo'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      backgroundColor: const Color(0xFFF5F7F6),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Tarifas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Altere aqui sem editar o código. Os novos valores passam a ser usados pela API.'),
                const SizedBox(height: 14),
                ...fields.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: c[e.key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: e.value,
                          prefixText: e.key == 'commission_percent' || e.key == 'long_distance_limit_km' ? '' : 'R\$ ',
                          suffixText: e.key == 'commission_percent' ? '%' : e.key == 'long_distance_limit_km' ? 'km' : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(height: 52, child: ElevatedButton(onPressed: saving ? null : _save, child: saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar tarifas'))),
                const SizedBox(height: 30),
                Row(children: [const Expanded(child: Text('Cidades atendidas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), IconButton(onPressed: _addCity, icon: const Icon(Icons.add_circle))]),
                const Text('Cadastre as cidades que a MotoGo atende.'),
                const SizedBox(height: 10),
                ...cities.map((x) => Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text('${x["city"]} - ${x["state"]}'),
                        subtitle: Text(x['enabled'] == true ? 'Ativa' : 'Desativada'),
                        leading: Icon(x['enabled'] == true ? Icons.location_on : Icons.location_off, color: const Color(0xFF00C985)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteCity(int.tryParse(x['id'].toString()) ?? 0)),
                      ),
                    )),
                if (cities.isEmpty) const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma cidade cadastrada.'))),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Expanded(child: Text('Contas administrativas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: loadingAdmins ? null : _loadAdmins, icon: const Icon(Icons.refresh)),
                    FilledButton.icon(onPressed: _createAdmin, icon: const Icon(Icons.person_add_alt_1), label: const Text('Novo administrador')),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Crie contas para pessoas da sua equipe entrarem no painel sem compartilhar sua senha.'),
                const SizedBox(height: 12),
                if (loadingAdmins)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (adminAccounts.isEmpty)
                  Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: const [Icon(Icons.admin_panel_settings_outlined), SizedBox(width: 12), Expanded(child: Text('Nenhuma conta administrativa cadastrada.'))])))
                else
                  ...adminAccounts.map((a) {
                    final active = a['admin_status']?.toString() == 'active';
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(((a['name'] ?? '?').toString().isEmpty ? '?' : (a['name'] ?? '?').toString()[0]).toUpperCase())),
                        title: Text((a['name'] ?? 'Administrador').toString()),
                        subtitle: Text('${a["email"] ?? '—'}\n${a["phone"] ?? '—'}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(label: Text(active ? 'Ativo' : 'Inativo'), avatar: Icon(active ? Icons.check_circle : Icons.pause_circle, size: 18), backgroundColor: active ? const Color(0xFFE5F8F0) : const Color(0xFFFFE9E6)),
                            const SizedBox(width: 6),
                            IconButton(tooltip: active ? 'Desativar' : 'Ativar', onPressed: () => _toggleAdmin(a), icon: Icon(active ? Icons.block : Icons.check, color: active ? Colors.red : const Color(0xFF00C985))),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
    );
  }
}
