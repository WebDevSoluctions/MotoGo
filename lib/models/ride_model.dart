import '../services/commission_service.dart';

class RideModel {
  // ============================================================
  // IDENTIFICAÇÃO
  // ============================================================

  final String id;
  final String userId;

  // ============================================================
  // SERVIÇO
  // ============================================================

  final String rideType;

  // mototaxi
  // carro
  // delivery

  // ============================================================
  // MOTORISTA
  // ============================================================

  final String driverId;
  final String driverName;
  final String vehicle;
  final String plate;
  final double driverRating;

  // ============================================================
  // LOCALIZAÇÃO
  // ============================================================

  final String origin;
  final String destination;

  // ============================================================
  // CORRIDA
  // ============================================================

  final double distanceKm;
  final double durationMinutes;

  // ============================================================
  // FINANCEIRO
  // ============================================================

  final double fare;
  final String paymentMethod;

  // Comissão da MotoGo
  final double platformCommission;

  // Valor destinado ao motorista
  final double driverEarnings;

  // ============================================================
  // AVALIAÇÃO
  // ============================================================

  final double? userRating;
  final String? userComment;

  // ============================================================
  // STATUS
  // ============================================================

  final String status;

  // pending
  // searching
  // driver_found
  // driver_arriving
  // in_progress
  // completed
  // cancelled

  // ============================================================
  // DATAS
  // ============================================================

  final DateTime createdAt;
  final DateTime? completedAt;

  // ============================================================
  // CONSTRUTOR
  // ============================================================

  const RideModel({
    required this.id,
    required this.userId,
    required this.rideType,
    required this.driverId,
    required this.driverName,
    required this.vehicle,
    required this.plate,
    required this.driverRating,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    required this.fare,
    required this.paymentMethod,
    required this.platformCommission,
    required this.driverEarnings,
    this.userRating,
    this.userComment,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  // ============================================================
  // CRIAR CORRIDA COM COMISSÃO AUTOMÁTICA
  // ============================================================

  factory RideModel.create({
    required String id,
    required String userId,
    required String rideType,
    required String driverId,
    required String driverName,
    required String vehicle,
    required String plate,
    required double driverRating,
    required String origin,
    required String destination,
    required double distanceKm,
    required double durationMinutes,
    required double fare,
    required String paymentMethod,
    double? userRating,
    String? userComment,
    String status = 'pending',
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    final commission =
        CommissionService.calculate(
      fare: fare,
    );

    return RideModel(
      id: id,
      userId: userId,
      rideType: rideType,
      driverId: driverId,
      driverName: driverName,
      vehicle: vehicle,
      plate: plate,
      driverRating: driverRating,
      origin: origin,
      destination: destination,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      fare: fare,
      paymentMethod: paymentMethod,
      platformCommission:
          commission.commission,
      driverEarnings:
          commission.driverEarnings,
      userRating: userRating,
      userComment: userComment,
      status: status,
      createdAt:
          createdAt ?? DateTime.now(),
      completedAt: completedAt,
    );
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  RideModel copyWith({
    String? id,
    String? userId,
    String? rideType,
    String? driverId,
    String? driverName,
    String? vehicle,
    String? plate,
    double? driverRating,
    String? origin,
    String? destination,
    double? distanceKm,
    double? durationMinutes,
    double? fare,
    String? paymentMethod,
    double? platformCommission,
    double? driverEarnings,
    double? userRating,
    String? userComment,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rideType: rideType ?? this.rideType,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      vehicle: vehicle ?? this.vehicle,
      plate: plate ?? this.plate,
      driverRating:
          driverRating ?? this.driverRating,
      origin: origin ?? this.origin,
      destination:
          destination ?? this.destination,
      distanceKm:
          distanceKm ?? this.distanceKm,
      durationMinutes:
          durationMinutes ?? this.durationMinutes,
      fare: fare ?? this.fare,
      paymentMethod:
          paymentMethod ?? this.paymentMethod,
      platformCommission:
          platformCommission ??
              this.platformCommission,
      driverEarnings:
          driverEarnings ??
              this.driverEarnings,
      userRating:
          userRating ?? this.userRating,
      userComment:
          userComment ?? this.userComment,
      status: status ?? this.status,
      createdAt:
          createdAt ?? this.createdAt,
      completedAt:
          completedAt ?? this.completedAt,
    );
  }

  // ============================================================
  // FIREBASE / MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'rideType': rideType,
      'driverId': driverId,
      'driverName': driverName,
      'vehicle': vehicle,
      'plate': plate,
      'driverRating': driverRating,
      'origin': origin,
      'destination': destination,
      'distanceKm': distanceKm,
      'durationMinutes':
          durationMinutes,
      'fare': fare,
      'paymentMethod':
          paymentMethod,
      'platformCommission':
          platformCommission,
      'driverEarnings':
          driverEarnings,
      'userRating': userRating,
      'userComment': userComment,
      'status': status,
      'createdAt':
          createdAt.toIso8601String(),
      'completedAt':
          completedAt?.toIso8601String(),
    };
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory RideModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return RideModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      rideType:
          map['rideType'] ?? 'mototaxi',
      driverId: map['driverId'] ?? '',
      driverName:
          map['driverName'] ?? 'Motorista',
      vehicle: map['vehicle'] ?? '',
      plate: map['plate'] ?? '',
      driverRating:
          _toDouble(map['driverRating']),
      origin: map['origin'] ?? '',
      destination:
          map['destination'] ?? '',
      distanceKm:
          _toDouble(map['distanceKm']),
      durationMinutes:
          _toDouble(map['durationMinutes']),
      fare: _toDouble(map['fare']),
      paymentMethod:
          map['paymentMethod'] ?? 'pix',
      platformCommission:
          _toDouble(
        map['platformCommission'],
      ),
      driverEarnings:
          _toDouble(
        map['driverEarnings'],
      ),
      userRating:
          map['userRating'] == null
              ? null
              : _toDouble(
                  map['userRating'],
                ),
      userComment:
          map['userComment'],
      status:
          map['status'] ?? 'pending',
      createdAt:
          _toDateTime(map['createdAt']),
      completedAt:
          map['completedAt'] == null
              ? null
              : _toDateTime(
                  map['completedAt'],
                ),
    );
  }

  // ============================================================
  // CONVERSÃO PARA DOUBLE
  // ============================================================

  static double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  // ============================================================
  // CONVERSÃO PARA DATA
  // ============================================================

  static DateTime _toDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
            value,
          ) ??
          DateTime.now();
    }

    return DateTime.now();
  }

  // ============================================================
  // NOME DO SERVIÇO
  // ============================================================

  String get serviceName {
    switch (rideType) {
      case 'carro':
        return 'Carro';

      case 'delivery':
        return 'Delivery';

      default:
        return 'Mototáxi';
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String get statusName {
    switch (status) {
      case 'pending':
        return 'Aguardando';

      case 'searching':
        return 'Procurando motorista';

      case 'driver_found':
        return 'Motorista encontrado';

      case 'driver_arriving':
        return 'Motorista a caminho';

      case 'in_progress':
        return 'Em andamento';

      case 'completed':
        return 'Concluída';

      case 'cancelled':
        return 'Cancelada';

      default:
        return status;
    }
  }

  // ============================================================
  // PAGAMENTO
  // ============================================================

  String get paymentName {
    switch (paymentMethod) {
      case 'pix':
        return 'PIX';

      case 'cash':
        return 'Dinheiro';

      case 'card':
        return 'Cartão';

      default:
        return paymentMethod;
    }
  }

  // ============================================================
  // PREÇO FORMATADO
  // ============================================================

  String get formattedFare {
    return 'R\$ ${fare.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // COMISSÃO FORMATADA
  // ============================================================

  String get formattedCommission {
    return 'R\$ ${platformCommission.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // GANHO DO MOTORISTA
  // ============================================================

  String get formattedDriverEarnings {
    return 'R\$ ${driverEarnings.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // PERCENTUAL DA COMISSÃO
  // ============================================================

  double get commissionPercentage {
    if (fare <= 0) {
      return 0;
    }

    return (platformCommission / fare) * 100;
  }

  // ============================================================
  // CORRIDA CONCLUÍDA
  // ============================================================

  bool get isCompleted {
    return status == 'completed';
  }

  // ============================================================
  // CORRIDA CANCELADA
  // ============================================================

  bool get isCancelled {
    return status == 'cancelled';
  }

  // ============================================================
  // TEM AVALIAÇÃO
  // ============================================================

  bool get hasRating {
    return userRating != null;
  }

  // ============================================================
  // RESUMO
  // ============================================================

  String get summary {
    return '$serviceName • $formattedFare';
  }

  // ============================================================
  // TEXTO
  // ============================================================

  @override
  String toString() {
    return 'RideModel('
        'id: $id, '
        'rideType: $rideType, '
        'driverName: $driverName, '
        'fare: $fare, '
        'commission: $platformCommission, '
        'driverEarnings: $driverEarnings, '
        'status: $status'
        ')';
  }
}