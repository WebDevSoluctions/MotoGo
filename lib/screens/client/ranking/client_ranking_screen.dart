import 'dart:async';
import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class ClientRankingScreen extends StatefulWidget {
  const ClientRankingScreen({super.key});

  @override
  State<ClientRankingScreen> createState() => _ClientRankingScreenState();
}

class _ClientRankingScreenState extends State<ClientRankingScreen> {
  Map<String, dynamic> _dashboard = {};
  bool _loading = true;
  bool _global = true;
  Timer? _refreshTimer;

  static const _bg = Color(0xFF05090D);
  static const _panel = Color(0xFF0B1319);
  static const _panel2 = Color(0xFF101B22);
  static const _green = Color(0xFF00D084);
  static const _neon = Color(0xFF39FF9B);
  static const _purple = Color(0xFF9B5CFF);
  static const _gold = Color(0xFFFFC94A);
  static const _silver = Color(0xFFC8D0D8);
  static const _bronze = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final id = int.tryParse(await AuthService.getUserId() ?? '');
    if (id == null) return;
    final response = await ApiService.getRewardsDashboard(id);
    if (!mounted) return;
    setState(() {
      _dashboard = response['dashboard'] is Map
          ? Map<String, dynamic>.from(response['dashboard'])
          : {};
      _loading = false;
    });
  }

  int _number(dynamic value) => int.tryParse('$value') ?? 0;

  String _medal(String level) {
    switch (level) {
      case 'VIP':
        return '💎';
      case 'Ouro':
        return '🥇';
      case 'Prata':
        return '🥈';
      default:
        return '🥉';
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'VIP':
        return const Color(0xFF5EA7FF);
      case 'Ouro':
        return _gold;
      case 'Prata':
        return _silver;
      default:
        return _bronze;
    }
  }

  int _nextLevel(String level) {
    switch (level) {
      case 'Bronze':
        return 500;
      case 'Prata':
        return 1500;
      case 'Ouro':
        return 3000;
      default:
        return 3000;
    }
  }

  String _nextName(String level) {
    switch (level) {
      case 'Bronze':
        return 'Prata';
      case 'Prata':
        return 'Ouro';
      case 'Ouro':
        return 'VIP';
      default:
        return 'Nível máximo';
    }
  }

  double _progress(int points, String level) {
    final next = _nextLevel(level);
    if (level == 'VIP') return 1;
    final previous = level == 'Bronze' ? 0 : level == 'Prata' ? 500 : 1500;
    return ((points - previous) / (next - previous)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final points = _number(_dashboard['points']);
    final level = _dashboard['level']?.toString() ?? 'Bronze';
    final globalRank = _number(_dashboard['global_rank']);
    final weeklyRank = _number(_dashboard['weekly_rank']);
    final globalTop = _dashboard['global_top10'] is List
        ? List<dynamic>.from(_dashboard['global_top10'])
        : <dynamic>[];
    final weeklyTop = _dashboard['top10'] is List
        ? List<dynamic>.from(_dashboard['top10'])
        : <dynamic>[];
    final missions = _dashboard['missions'] is List
        ? List<dynamic>.from(_dashboard['missions'])
        : <dynamic>[];
    final list = _global ? globalTop : weeklyTop;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _gold),
            SizedBox(width: 9),
            Text('Ranking MotoGo', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              backgroundColor: _panel,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                children: [
                  _hero(points, level, globalRank, weeklyRank),
                  const SizedBox(height: 14),
                  _tabs(),
                  const SizedBox(height: 14),
                  if (list.length >= 3) _podium(list, global: _global),
                  const SizedBox(height: 12),
                  _leaderboard(list, global: _global, myRank: _global ? globalRank : weeklyRank),
                  if (!_global && missions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _missions(missions),
                  ],
                  const SizedBox(height: 14),
                  _noAdvantageCard(),
                ],
              ),
            ),
    );
  }

  Widget _hero(int points, String level, int globalRank, int weeklyRank) {
    final color = _levelColor(level);
    final next = _nextLevel(level);
    final remaining = level == 'VIP' ? 0 : (next - points).clamp(0, next);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10231C), Color(0xFF06271B), Color(0xFF10131A)],
        ),
        border: Border.all(color: color.withOpacity(.55)),
        boxShadow: [BoxShadow(color: _green.withOpacity(.12), blurRadius: 25, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(level, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SEU NÍVEL', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text(level.toUpperCase(), style: TextStyle(color: color, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: .7)),
                  Text('$points MotoGo Points', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.08))),
                child: Column(children: [
                  const Icon(Icons.star_rounded, color: _gold, size: 18),
                  Text('$points', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _stat('🌎', globalRank > 0 ? '#$globalRank' : '--', 'Global')),
            const SizedBox(width: 8),
            Expanded(child: _stat('📅', weeklyRank > 0 ? '#$weeklyRank' : '--', 'Semana')),
          ]),
          if (level != 'VIP') ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Próximo nível: ${_nextName(level)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('$remaining pts', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: _progress(points, level), minHeight: 8, backgroundColor: Colors.white.withOpacity(.08), color: color),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text('💎 Você alcançou o nível máximo.', style: TextStyle(color: _neon, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _stat(String icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.045), borderRadius: BorderRadius.circular(15)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.07))),
      child: Row(children: [
        Expanded(child: _tab('🌎 Global', true, _global)),
        Expanded(child: _tab('📅 Semanal', false, !_global)),
      ]),
    );
  }

  Widget _tab(String label, bool global, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _global = global),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [_green, Color(0xFF00A968)]) : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: _green.withOpacity(.18), blurRadius: 14)] : null,
        ),
        child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w800))),
      ),
    );
  }

  Widget _podium(List<dynamic> list, {required bool global}) {
    final ordered = [list[1], list[0], list[2]];
    final positions = [2, 1, 3];
    final colors = [_silver, _gold, _bronze];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.06))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(global ? Icons.public_rounded : Icons.calendar_month_rounded, color: _green, size: 19),
          const SizedBox(width: 7),
          Text(global ? 'TOP 3 GLOBAL' : 'TOP 3 DA SEMANA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(3, (i) {
          final item = ordered[i] is Map ? Map<String, dynamic>.from(ordered[i]) : <String, dynamic>{};
          final name = item['name']?.toString() ?? 'Usuário';
          final value = _number(global ? item['total_points'] : item['weekly_points']);
          final height = positions[i] == 1 ? 156.0 : positions[i] == 2 ? 132.0 : 120.0;
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              height: height,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors[i].withOpacity(.18), Colors.transparent]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors[i].withOpacity(.35)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                _podiumBadge(positions[i], colors[i]),
                const SizedBox(height: 7),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('$value pts', style: TextStyle(color: colors[i], fontWeight: FontWeight.w900)),
              ]),
            ),
          ));
        })),
      ]),
    );
  }

  Widget _podiumBadge(int position, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.12), border: Border.all(color: color, width: 2), boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 14)]),
      child: Center(child: Text('$position', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900))),
    );
  }

  Widget _leaderboard(List<dynamic> list, {required bool global, required int myRank}) {
    final rest = list.length > 3 ? list.sublist(3) : <dynamic>[];
    return Container(
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.06))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(global ? '🌎 Ranking Global' : '📅 Ranking Semanal', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text('TOP 10', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 11, fontWeight: FontWeight.w800)),
          ])),
          const SizedBox(height: 8),
          if (list.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('Ainda não há dados suficientes para o ranking.', style: TextStyle(color: Colors.white70))),
          ...rest.asMap().entries.map((entry) {
            final position = entry.key + 4;
            final item = entry.value is Map ? Map<String, dynamic>.from(entry.value) : <String, dynamic>{};
            final name = item['name']?.toString() ?? 'Usuário';
            final value = _number(global ? item['total_points'] : item['weekly_points']);
            return _row(position, name, value, position == myRank);
          }),
          if (myRank > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: _green.withOpacity(.09), borderRadius: BorderRadius.circular(15), border: Border.all(color: _green.withOpacity(.55))),
              child: Row(children: [
                Text('#$myRank', style: const TextStyle(color: _neon, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Você', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                const Icon(Icons.person_rounded, color: _green, size: 20),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _row(int position, String name, int points, bool me) {
    final color = position == 4 ? _purple : Colors.white.withOpacity(.75);
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(color: me ? _green.withOpacity(.08) : Colors.white.withOpacity(.025), borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        SizedBox(width: 32, child: Text('$position', style: TextStyle(color: color, fontWeight: FontWeight.w900))),
        Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: _green.withOpacity(.12), border: Border.all(color: _green.withOpacity(.35))), child: const Icon(Icons.person_rounded, color: _green, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        Text('$points pts', style: TextStyle(color: me ? _neon : Colors.white70, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _missions(List<dynamic> missions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: _purple.withOpacity(.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.track_changes_rounded, color: _purple), SizedBox(width: 8), Text('Missões da semana', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 5),
        Text('Pequenos desafios para evoluir seu nível.', style: TextStyle(color: Colors.white.withOpacity(.5))),
        const SizedBox(height: 12),
        ...missions.map((raw) {
          final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final progress = _number(m['progress']);
          final goal = _number(m['goal']);
          final reward = _number(m['points']);
          final value = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.025), borderRadius: BorderRadius.circular(15)),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(m['title']?.toString() ?? 'Missão', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                Text('+$reward pts', style: const TextStyle(color: _neon, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: Colors.white.withOpacity(.08), color: _purple)),
              const SizedBox(height: 5),
              Align(alignment: Alignment.centerRight, child: Text('$progress/$goal', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 11))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _badge(String level, {double size = 70}) {
    final color = _levelColor(level);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withOpacity(.28), Colors.transparent]), border: Border.all(color: color.withOpacity(.7), width: 2), boxShadow: [BoxShadow(color: color.withOpacity(.22), blurRadius: 22)]),
      child: Center(child: Icon(level == 'VIP' ? Icons.diamond_rounded : Icons.emoji_events_rounded, color: color, size: size * .48)),
    );
  }

  Widget _noAdvantageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(.35))),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.shield_outlined, color: _purple, size: 24),
        SizedBox(width: 12),
        Expanded(child: Text('Ranking não concede vantagens. É apenas uma forma de reconhecer sua jornada no MotoGo.', style: TextStyle(color: Colors.white70, height: 1.45))),
      ]),
    );
  }
}
