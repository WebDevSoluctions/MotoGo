import 'package:flutter/material.dart';

import 'package:motogo/config/colors.dart';
import 'package:motogo/screens/client/history/ride_history_screen.dart';
import 'package:motogo/screens/client/ride/ride_request_screen.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
  });

  // ============================================================
  // ABRIR HISTÓRICO
  // ============================================================

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideHistoryScreen(),
      ),
    );
  }

  // ============================================================
  // ABRIR DESTINO / SOLICITAR CORRIDA
  // ============================================================

  void _openDestination(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideRequestScreen(
          rideType: 'mototaxi',
        ),
      ),
    );
  }

  // ============================================================
  // ABRIR AVALIAÇÕES
  // ============================================================
  //
  // O projeto já possui a avaliação de corrida pelo endpoint
  // /rides/rate.php. Como ainda não existe um endpoint GET
  // específico para listar todas as avaliações do passageiro,
  // direcionamos o usuário ao histórico, onde estão as corridas
  // concluídas que podem ser avaliadas.
  //

  void _openRatings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RideHistoryScreen(),
      ),
    ).then((_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No histórico você pode consultar suas corridas concluídas e avaliações.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // ============================================================
  // CENTRAL DE AJUDA
  // ============================================================

  void _openHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final topics = <Map<String, dynamic>>[
          {
            'icon': Icons.two_wheeler_outlined,
            'title': 'Solicitar uma corrida',
            'text':
                'Escolha o destino, confira o valor estimado e confirme a solicitação.',
          },
          {
            'icon': Icons.location_on_outlined,
            'title': 'Localização e GPS',
            'text':
                'Mantenha a localização do aparelho ativada para calcular origem, destino e rota.',
          },
          {
            'icon': Icons.history_outlined,
            'title': 'Histórico',
            'text':
                'Consulte suas corridas anteriores e acompanhe os detalhes de cada viagem.',
          },
          {
            'icon': Icons.star_outline,
            'title': 'Avaliações',
            'text':
                'Depois de uma corrida concluída, você pode avaliar o atendimento do motorista.',
          },
          {
            'icon': Icons.favorite_border,
            'title': 'Endereços favoritos',
            'text':
                'Salve Casa, Trabalho e outros locais para usar novamente sem precisar digitar tudo.',
          },
          {
            'icon': Icons.cancel_outlined,
            'title': 'Cancelamento',
            'text':
                'Quando disponível, use o botão de cancelamento na tela da corrida para interromper a solicitação.',
          },
        ];

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.only(top: 70),
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(
                        bottom: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Central de ajuda',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Encontre orientações rápidas para usar o MotoGo.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...topics.map(
                    (topic) => Container(
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            topic['icon'] as IconData,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic['title'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topic['text'].toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.support_agent_outlined,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ainda precisa de ajuda? Entre em contato com o suporte do MotoGo.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ======================================================
        // PRIMEIRA LINHA
        // ======================================================

        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history,
                title: 'Histórico',
                subtitle: 'Suas corridas',
                color: AppColors.primary,
                onTap: () {
                  _openHistory(context);
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.location_on_outlined,
                title: 'Destino',
                subtitle: 'Para onde vamos?',
                color: Colors.orange,
                onTap: () {
                  _openDestination(context);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ======================================================
        // SEGUNDA LINHA
        // ======================================================

        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.star_outline,
                title: 'Avaliações',
                subtitle: 'Suas avaliações',
                color: Colors.amber.shade700,
                onTap: () {
                  _openRatings(context);
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.help_outline,
                title: 'Ajuda',
                subtitle: 'Central de ajuda',
                color: Colors.blue,
                onTap: () {
                  _openHelp(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =================================================================
// CARD
// =================================================================

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
