import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../config/colors.dart';

import '../../services/api_service.dart';

import '../../services/auth_service.dart';

class MotoGoPlusScreen extends StatefulWidget {

  const MotoGoPlusScreen({super.key});

  @override State<MotoGoPlusScreen> createState() => _MotoGoPlusScreenState();

}

class _MotoGoPlusScreenState extends State<MotoGoPlusScreen> {

  int? _userId;

  int _points = 0;

  String _referralCode = '';

  List<dynamic> _favorites = [];

  Map<String, dynamic> _rewards = {};

  List<dynamic> _scheduled = [];

  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {

    final id = int.tryParse(await AuthService.getUserId() ?? '');

    if (id == null || id <= 0) { if (mounted) setState(() => _loading = false); return; }

    _userId = id;

    try {

      final results = await Future.wait([

        ApiService.getPoints(id), ApiService.getFavoriteDrivers(id),

        ApiService.getRewardsDashboard(id), ApiService.getScheduledRides(id),

      ]);

      if (!mounted) return;

      setState(() {

        final p = results[0];

        _points = int.tryParse('${p["points"] ?? 0}') ?? 0;

        _referralCode = '${p["referral_code"] ?? ''}';

        _favorites = results[1]['favorites'] is List ? results[1]['favorites'] : [];

        _rewards = results[2]['dashboard'] is Map ? Map<String, dynamic>.from(results[2]['dashboard']) : {};

        _scheduled = results[3]['rides'] is List ? results[3]['rides'] : [];

        _loading = false;

      });

    } catch (_) { if (mounted) setState(() => _loading = false); }

  }

  Future<void> _applyReferral() async {

    if (_userId == null) return;

    final controller = TextEditingController();

    final code = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(

      title: const Text('Código de indicação'), content: TextField(controller: controller, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Ex.: MGAB12CD34')),

      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Aplicar'))],

    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (code == null || code.isEmpty) return;

    final result = await ApiService.applyReferral(userId: _userId!, code: code);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível aplicar.')));

    if (result['success'] == true) _load();

  }

  @override Widget build(BuildContext context) => Scaffold(

    backgroundColor: AppColors.background,

    appBar: AppBar(title: const Text('MotoGo+'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),

    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(

      onRefresh: _load,

      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [

        _hero(), const SizedBox(height: 18),

        _section('Segurança e tranquilidade', [

          _feature(Icons.shield_outlined, 'Central de segurança', 'Compartilhe, peça ajuda e veja orientações de segurança.', _showSafety, highlight: true),

          _feature(Icons.calendar_month_rounded, 'Corridas agendadas', _scheduled.isEmpty ? 'Planeje sua próxima viagem' : '${_scheduled.length} corrida(s) agendada(s)', _showScheduled),

          _feature(Icons.location_on_outlined, 'Ponto Exato', 'Confirme o ponto diretamente no mapa.', () => _info('O Ponto Exato está disponível durante a solicitação da corrida.')),

        ]),

        _section('Seus recursos', [

          _feature(Icons.favorite_rounded, 'Motoristas favoritos', _favorites.isEmpty ? 'Nenhum motorista salvo' : '${_favorites.length} motorista(s) salvo(s)', _showFavorites),

          _feature(Icons.person_add_alt_1_rounded, 'Corrida para outra pessoa', 'Nome e telefone do passageiro', () => _info('Esse recurso aparece nas opções da próxima solicitação de corrida.')),

          _feature(Icons.alt_route_rounded, 'Paradas múltiplas', 'Adicione até 4 paradas na sua rota', () => _info('Use o botão “Paradas” na tela de solicitação da corrida.')),

          _feature(Icons.share_rounded, 'Compartilhar viagem', 'Compartilhe o acompanhamento quando a corrida estiver em andamento.', _showShareInfo),

        ]),

        _section('Benefícios', [

          _feature(Icons.stars_rounded, 'MotoGo Points', '${_rewards['level'] ?? 'Bronze'} • $_points pontos', _showPoints),

          _feature(Icons.group_add_rounded, 'Indique e ganhe', _referralCode.isEmpty ? 'Tenha seu código de indicação' : 'Código: $_referralCode', _applyReferral),

        ]),

      ]),

    ),

  );

  Widget _hero() => Container(

    padding: const EdgeInsets.all(22),

    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primary.withOpacity(.78)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.20), blurRadius: 18, offset: const Offset(0, 8))]),

    child: Row(children: [

      Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30)),

      const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MotoGo+', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('Tudo para deixar suas viagens mais práticas e seguras.', style: TextStyle(color: Colors.white, height: 1.3))]))

    ]),

  );

  Widget _section(String title, List<Widget> children) => Padding(padding: const EdgeInsets.only(top: 2, bottom: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 3, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),), ...children]));

  Widget _feature(IconData icon, String title, String subtitle, VoidCallback onTap, {bool highlight = false}) => Container(

    margin: const EdgeInsets.only(bottom: 10),

    decoration: BoxDecoration(color: highlight ? AppColors.primary.withOpacity(.07) : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: highlight ? AppColors.primary.withOpacity(.18) : Colors.black.withOpacity(.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 8, offset: const Offset(0, 3))]),

    child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [

      Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: AppColors.primary, size: 25)),

      const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.25))])),

      const Icon(Icons.chevron_right_rounded, color: Colors.grey),

    ])))));

  void _info(String text) => showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('MotoGo+'), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))]));

  void _showSafety() => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))), builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),

    const SizedBox(height: 18), const Text('Central de segurança', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 6), const Text('Use estes recursos para acompanhar sua viagem com mais tranquilidade.'), const SizedBox(height: 16),

    _sheetAction(sheetContext, Icons.share_location_rounded, 'Compartilhar viagem', 'Copiar uma mensagem para enviar a alguém de confiança.', _copySafetyMessage),

    _sheetAction(sheetContext, Icons.help_outline_rounded, 'Ajuda', 'Orientações para problemas durante a corrida.', () { Navigator.pop(sheetContext); _info('Se houver um problema durante a corrida, use os canais de suporte disponíveis no aplicativo e mantenha os dados da viagem em mãos.'); }),

    _sheetAction(sheetContext, Icons.shield_rounded, 'Dicas de segurança', 'Confira motorista, veículo e destino antes de iniciar.', () { Navigator.pop(sheetContext); _info('Confira o nome do motorista e os dados do veículo. Compartilhe sua viagem com alguém de confiança e, se algo parecer errado, não prossiga e procure ajuda.'); }),

  ]))));

  Widget _sheetAction(BuildContext c, IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(.10), child: Icon(icon, color: AppColors.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), onTap: onTap);

  Future<void> _copySafetyMessage() async { await Clipboard.setData(const ClipboardData(text: 'Estou em uma viagem pelo MotoGo. Se eu precisar de ajuda, entre em contato comigo.')); if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem de segurança copiada.'))); }

  void _showShareInfo() => _info('O compartilhamento do acompanhamento fica disponível durante a corrida, na tela de viagem em andamento.');

  void _showPoints() {

    final level = _rewards['level']?.toString() ?? 'Bronze'; final weekly = int.tryParse('${_rewards['weekly_points'] ?? 0}') ?? 0; final rank = int.tryParse('${_rewards['weekly_rank'] ?? 0}') ?? 0; final missions = _rewards['missions'] is List ? List<dynamic>.from(_rewards['missions']) : <dynamic>[]; final top10 = _rewards['top10'] is List ? List<dynamic>.from(_rewards['top10']) : <dynamic>[];

    showDialog(context: context, builder: (_) => AlertDialog(title: Text('💚 $level • $_points pontos'), content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [Text('🏆 Ranking semanal: ${rank > 0 ? '#$rank' : 'sem posição'} • $weekly pts'), const SizedBox(height: 12), const Text('🎯 Missões da semana', style: TextStyle(fontWeight: FontWeight.bold)), ...missions.map((m) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.flag_outlined), title: Text(m['title']?.toString() ?? ''), subtitle: Text('${m['progress'] ?? 0}/${m['goal'] ?? 0} • +${m['points'] ?? 0} pontos'))), const SizedBox(height: 8), const Text('🏆 Top 10 da semana', style: TextStyle(fontWeight: FontWeight.bold)), ...top10.asMap().entries.map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 15, child: Text('${e.key + 1}')), title: Text(e.value['name']?.toString() ?? 'Cliente'), trailing: Text('${e.value['weekly_points'] ?? 0} pts')))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))]));

  }

  void _showFavorites() => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Motoristas favoritos'), content: SizedBox(width: double.maxFinite, child: _favorites.isEmpty ? const Text('Você ainda não favoritou nenhum motorista.') : ListView(shrinkWrap: true, children: _favorites.map((f) { final name = f['name']?.toString() ?? 'Motorista'; final vehicle = f['vehicle_model']?.toString() ?? ''; final plate = f['plate']?.toString() ?? ''; return ListTile(title: Text(name), subtitle: Text('$vehicle $plate'.trim()), leading: const Icon(Icons.star)); }).toList())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))]));

  void _showScheduled() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Corridas agendadas',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Planeje sua próxima viagem com antecedência.'),
            const SizedBox(height: 12),
            if (_scheduled.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Center(
                  child: Text(
                    'Nenhuma corrida agendada.\nVocê pode agendar na próxima solicitação.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._scheduled.map(
                (r) => Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.06),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r["ride_type"] ?? 'Corrida'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('${r["scheduled_at"] ?? ''}'),
                            Text(
                              '${r["origin_address"] ?? ''} → ${r["destination_address"] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
