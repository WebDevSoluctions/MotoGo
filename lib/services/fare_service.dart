import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class FareResult {
  final double baseFare;
  final double distanceKm;
  final double pricePerKm;
  final double distanceFare;
  final double total;

  const FareResult({
    required this.baseFare,
    required this.distanceKm,
    required this.pricePerKm,
    required this.distanceFare,
    required this.total,
  });
}

class FareService {
  // ============================================================
  // MOTOTÁXI
  // ============================================================

  static double mototaxiBaseFare = 5.00;

  static double mototaxiPricePerKm = 2.00;

  // ============================================================
  // CARRO
  // ============================================================

  static double carBaseFare = 7.00;

  static double carPricePerKm = 3.00;

  // ============================================================
  // DELIVERY / MOTO EXPRESS
  // ============================================================

  static double deliveryBaseFare = 7.00;

  static double deliveryPricePerKm = 2.50;

  static double bicycleDeliveryBaseFare = 6.00;
  static double bicycleDeliveryPricePerKm = 1.80;
  static double pedestrianDeliveryBaseFare = 5.00;
  static double pedestrianDeliveryPricePerKm = 1.50;
  static double pedestrianDeliveryMaxKm = 2.00;

  // ============================================================
  // VIAGEM LONGA
  // ============================================================

  static double longDistanceLimitKm = 50.00;
  static double viagemBaseFare = 80.00;
  static double viagemPricePerKm = 2.20;

  // ============================================================
  // CARREGAR TARIFAS DO PAINEL ADMINISTRATIVO
  // ============================================================

  static Future<void> loadFromApi() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/settings.php'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return;
      final raw = data['settings'];
      if (raw is! Map) return;
      double value(String key, double fallback) => double.tryParse(raw[key]?.toString() ?? '') ?? fallback;
      mototaxiBaseFare = value('mototaxi_base', mototaxiBaseFare);
      mototaxiPricePerKm = value('mototaxi_per_km', mototaxiPricePerKm);
      carBaseFare = value('car_base', carBaseFare);
      carPricePerKm = value('car_per_km', carPricePerKm);
      deliveryBaseFare = value('delivery_base', deliveryBaseFare);
      deliveryPricePerKm = value('delivery_per_km', deliveryPricePerKm);
      bicycleDeliveryBaseFare = value('bicycle_base', bicycleDeliveryBaseFare);
      bicycleDeliveryPricePerKm = value('bicycle_per_km', bicycleDeliveryPricePerKm);
      pedestrianDeliveryBaseFare = value('pedestrian_base', pedestrianDeliveryBaseFare);
      pedestrianDeliveryPricePerKm = value('pedestrian_per_km', pedestrianDeliveryPricePerKm);
      pedestrianDeliveryMaxKm = value('pedestrian_max_km', pedestrianDeliveryMaxKm);
      longDistanceLimitKm = value('long_distance_limit_km', longDistanceLimitKm);
      viagemBaseFare = value('viagem_base', viagemBaseFare);
      viagemPricePerKm = value('viagem_per_km', viagemPricePerKm);
    } on TimeoutException {
      // Mantém os valores locais se a API estiver indisponível.
    } catch (_) {
      // Mantém os valores locais como fallback.
    }
  }

  // ============================================================
  // MOTOTÁXI
  // ============================================================

  static FareResult calculateMototaxi(
    double distanceKm,
  ) {
    final double safeDistance =
        distanceKm < 0.0 ? 0.0 : distanceKm;

    final double distanceFare =
        safeDistance * mototaxiPricePerKm;

    final double total =
        mototaxiBaseFare + distanceFare;

    return FareResult(
      baseFare: mototaxiBaseFare,
      distanceKm: safeDistance,
      pricePerKm: mototaxiPricePerKm,
      distanceFare: distanceFare,
      total: _round(total),
    );
  }

  // ============================================================
  // CARRO
  // ============================================================

  static FareResult calculateCar(
    double distanceKm,
  ) {
    final double safeDistance =
        distanceKm < 0.0 ? 0.0 : distanceKm;

    final double distanceFare =
        safeDistance * carPricePerKm;

    final double total =
        carBaseFare + distanceFare;

    return FareResult(
      baseFare: carBaseFare,
      distanceKm: safeDistance,
      pricePerKm: carPricePerKm,
      distanceFare: distanceFare,
      total: _round(total),
    );
  }

  // ============================================================
  // DELIVERY
  // ============================================================

  static FareResult calculateBicycleDelivery(
    double distanceKm,
  ) {
    final safeDistance = distanceKm < 0.0 ? 0.0 : distanceKm;
    final distanceFare = safeDistance * bicycleDeliveryPricePerKm;
    final total = bicycleDeliveryBaseFare + distanceFare;

    return FareResult(
      baseFare: bicycleDeliveryBaseFare,
      distanceKm: safeDistance,
      pricePerKm: bicycleDeliveryPricePerKm,
      distanceFare: distanceFare,
      total: _round(total),
    );
  }

  static FareResult calculatePedestrianDelivery(double distanceKm) {
    final safeDistance = distanceKm < 0.0 ? 0.0 : distanceKm;
    final distanceFare = safeDistance * pedestrianDeliveryPricePerKm;
    return FareResult(baseFare: pedestrianDeliveryBaseFare, distanceKm: safeDistance, pricePerKm: pedestrianDeliveryPricePerKm, distanceFare: distanceFare, total: _round(pedestrianDeliveryBaseFare + distanceFare));
  }

  static FareResult calculateDelivery(
    double distanceKm,
  ) {
    final double safeDistance =
        distanceKm < 0.0 ? 0.0 : distanceKm;

    final double distanceFare =
        safeDistance * deliveryPricePerKm;

    final double total =
        deliveryBaseFare + distanceFare;

    return FareResult(
      baseFare: deliveryBaseFare,
      distanceKm: safeDistance,
      pricePerKm: deliveryPricePerKm,
      distanceFare: distanceFare,
      total: _round(total),
    );
  }

  // ============================================================
  // VIAGEM LONGA
  // ============================================================

  static FareResult calculateViagem(
    double distanceKm,
  ) {
    final double safeDistance =
        distanceKm < 0.0 ? 0.0 : distanceKm;

    final double distanceFare =
        safeDistance * viagemPricePerKm;

    final double total =
        viagemBaseFare + distanceFare;

    return FareResult(
      baseFare: viagemBaseFare,
      distanceKm: safeDistance,
      pricePerKm: viagemPricePerKm,
      distanceFare: distanceFare,
      total: _round(total),
    );
  }

  // ============================================================
  // CALCULAR PELO TIPO
  // ============================================================

  static FareResult calculate({
    required double distanceKm,
    required String rideType,
  }) {
    switch (rideType) {
      case 'carro':
        return calculateCar(distanceKm);

      case 'delivery_moto':
        return calculateDelivery(distanceKm);

      case 'delivery_bicicleta':
      case 'bicicleta':
        return calculateBicycleDelivery(distanceKm);

      case 'delivery_pedestre':
      case 'pedestre':
      case 'a_pe':
        return calculatePedestrianDelivery(distanceKm);

      case 'viagem':
        return calculateViagem(distanceKm);

      case 'mototaxi':
      default:
        return calculateMototaxi(distanceKm);
    }
  }

  // ============================================================
  // ARREDONDAMENTO
  // ============================================================

  static double _round(double value) {
    return (value * 100.0).round() / 100.0;
  }

  // ============================================================
  // FORMATAÇÃO DE PREÇO
  // ============================================================

  static String formatPrice(
    double value,
  ) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // NOME DO SERVIÇO
  // ============================================================

  static String serviceName(
    String rideType,
  ) {
    switch (rideType) {
      case 'carro':
        return 'Carro';
      case 'delivery_moto':
        return 'Moto Express';
      case 'delivery_bicicleta':
      case 'bicicleta':
        return 'Bike Express';
      case 'delivery_pedestre':
      case 'pedestre':
      case 'a_pe':
        return 'Entrega a pé';
      case 'viagem':
        return 'Viagem';
      case 'mototaxi':
      default:
        return 'Mototáxi';
    }
  }

  // ============================================================
  // ÍCONE
  // ============================================================

  static String serviceDescription(
    String rideType,
  ) {
    switch (rideType) {
      case 'carro':
        return 'Conforto e segurança';
      case 'delivery_moto':
        return 'Entrega rápida';
      case 'delivery_bicicleta':
      case 'bicicleta':
        return 'Entrega econômica';
      case 'delivery_pedestre':
      case 'pedestre':
      case 'a_pe':
        return 'Entrega para curtas distâncias';
      case 'viagem':
        return 'Viagem acima de 50 km';
      case 'mototaxi':
      default:
        return 'Chegada rápida';
    }
  }
}
