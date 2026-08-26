import 'package:flutter/material.dart';

import '../../../../config/colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';
import '../../ranking/client_ranking_screen.dart';

class ClientRankingCard extends StatefulWidget {
  const ClientRankingCard({super.key});

  @override
  State<ClientRankingCard> createState() => _ClientRankingCardState();
}

class _ClientRankingCardState extends State<ClientRankingCard> {
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(await AuthService.getUserId() ?? '');
    if (id == null) return;
    final response = await ApiService.getRewardsDashboard(id);
    if (!mounted) return;
    final dashboard = response['dashboard'];
    if (dashboard is Map) {
      setState(() => _data = Map<String, dynamic>.from(dashboard));
    }
  }

  String _medal(String level) {
    switch (level) {
      case 'VIP': return '💎';
      case 'Ouro': return '🥇';
      case 'Prata': return '🥈';
      default: return '🥉';
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = _data['level']?.toString() ?? 'Bronze';
    final points = int.tryParse('${_data['points'] ?? 0}') ?? 0;
    final global = int.tryParse('${_data['global_rank'] ?? 0}') ?? 0;
    final weekly = int.tryParse('${_data['weekly_rank'] ?? 0}') ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientRankingScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_medal(level), style: const TextStyle(fontSize: 27)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏆 Ranking MotoGo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text('$level • $points pontos', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 3),
                    Text('🌎 ${global > 0 ? '#$global' : '--'}  •  📅 ${weekly > 0 ? '#$weekly' : '--'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
