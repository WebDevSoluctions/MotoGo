import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class FaithMessageCard extends StatelessWidget {
  const FaithMessageCard({super.key});

  static const _messages = [
    ('Salmo 23:1', 'O Senhor é o meu pastor; nada me faltará.'),
    ('Salmo 37:5', 'Entrega o teu caminho ao Senhor e confia nele.'),
    ('Isaías 41:10', 'Não temas, porque eu sou contigo.'),
    ('Salmo 118:24', 'Este é o dia que o Senhor fez; alegremo-nos nele.'),
    ('1 Tessalonicenses 5:18', 'Em tudo, dai graças.'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = DateTime.now().difference(DateTime(2026, 1, 1)).inDays.abs() % _messages.length;
    final message = _messages[index];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(.13), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Uma palavra para sua jornada', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 5),
                Text('“${message.$2}”', style: const TextStyle(fontSize: 14, height: 1.35)),
                const SizedBox(height: 5),
                Text(message.$1, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 5),
                const Text('Que Deus abençoe sua saída, seu caminho e seu retorno. 🙏', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
