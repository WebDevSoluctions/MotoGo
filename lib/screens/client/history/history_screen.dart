import 'package:flutter/material.dart';

import 'ride_history_screen.dart';

/// Compatibilidade com rotas antigas.
/// O histórico oficial do aplicativo é carregado da API/MySQL.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RideHistoryScreen();
  }
}
