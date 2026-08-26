class CommissionResult {
  final double fare;
  final double commission;
  final double driverEarnings;
  final double commissionPercentage;

  const CommissionResult({
    required this.fare,
    required this.commission,
    required this.driverEarnings,
    required this.commissionPercentage,
  });

  String get formattedFare {
    return 'R\$ ${fare.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get formattedCommission {
    return 'R\$ ${commission.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get formattedDriverEarnings {
    return 'R\$ ${driverEarnings.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class CommissionService {
  // ============================================================
  // CONFIGURAÇÃO DA COMISSÃO
  // ============================================================

  // Percentual que fica com a MotoGo.
  //
  // Por enquanto: 15%
  //
  // Depois podemos alterar para o percentual
  // que você decidir para o aplicativo.

  static const double motoGoPercentage = 0.15;

  // ============================================================
  // CALCULAR COMISSÃO
  // ============================================================

  static CommissionResult calculate({
    required double fare,
  }) {
    if (fare <= 0) {
      return const CommissionResult(
        fare: 0,
        commission: 0,
        driverEarnings: 0,
        commissionPercentage: 0,
      );
    }

    final commission =
        fare * motoGoPercentage;

    final driverEarnings =
        fare - commission;

    return CommissionResult(
      fare: fare,
      commission: commission,
      driverEarnings: driverEarnings,
      commissionPercentage:
          motoGoPercentage * 100,
    );
  }

  // ============================================================
  // CALCULAR SOMENTE A COMISSÃO
  // ============================================================

  static double calculateCommission(
    double fare,
  ) {
    if (fare <= 0) {
      return 0;
    }

    return fare * motoGoPercentage;
  }

  // ============================================================
  // CALCULAR GANHO DO MOTORISTA
  // ============================================================

  static double calculateDriverEarnings(
    double fare,
  ) {
    if (fare <= 0) {
      return 0;
    }

    final commission =
        calculateCommission(fare);

    return fare - commission;
  }

  // ============================================================
  // FORMATAR VALOR
  // ============================================================

  static String formatPrice(
    double value,
  ) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // PERCENTUAL FORMATADO
  // ============================================================

  static String get formattedPercentage {
    return '${(motoGoPercentage * 100).toStringAsFixed(0)}%';
  }
}