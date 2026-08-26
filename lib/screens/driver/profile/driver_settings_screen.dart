import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../auth/login_screen.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool notifications = true;
  bool autoFollowMap = true;
  bool sound = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = p.getBool('driver_notifications') ?? true;
      autoFollowMap = p.getBool('driver_auto_follow_map') ?? true;
      sound = p.getBool('driver_sound') ?? true;
    });
  }

  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> _deleteAccount() async {
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

    if (confirmed != true || !mounted) return;

    final result = await AuthService.deleteAccount();

    if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      backgroundColor: const Color(0xFFF5F7F6),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _section(
            'Corridas',
            [
              _sw(
                'Notificações de corrida',
                'Receber alertas de novas solicitações.',
                notifications,
                (v) {
                  setState(() => notifications = v);
                  _set('driver_notifications', v);
                },
              ),
              _sw(
                'Acompanhar mapa automaticamente',
                'Manter o mapa focado na posição durante a corrida.',
                autoFollowMap,
                (v) {
                  setState(() => autoFollowMap = v);
                  _set('driver_auto_follow_map', v);
                },
              ),
              _sw(
                'Som das solicitações',
                'Tocar alerta quando chegar uma nova corrida.',
                sound,
                (v) {
                  setState(() => sound = v);
                  _set('driver_sound', v);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            'Conta',
            [
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Segurança'),
                subtitle: Text(
                  'As credenciais continuam protegidas pelo login da MotoGo.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Versão'),
                subtitle: Text('MotoGo 1.0.1'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
                title: const Text(
                  'Excluir minha conta',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Solicitar exclusão da conta e dos dados associados.',
                ),
                onTap: _deleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _sw(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
