import '../models/ride_model.dart';
import 'commission_service.dart';

class RideService {
  // ============================================================
  // ARMAZENAMENTO TEMPORÁRIO
  // ============================================================
  //
  // Por enquanto as corridas ficam em memória.
  //
  // Depois vamos trocar esta lista pelo Firebase/Firestore.
  //
  // A interface do serviço continuará praticamente igual.
  // ============================================================

  static final List<RideModel> _rides = [];

  // ============================================================
  // CRIAR CORRIDA
  // ============================================================

  static RideModel createRide({
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
    String status = 'pending',
  }) {
    final commission =
        CommissionService.calculate(
      fare: fare,
    );

    final ride = RideModel(
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
      status: status,
      createdAt: DateTime.now(),
    );

    _rides.insert(
      0,
      ride,
    );

    return ride;
  }

  // ============================================================
  // BUSCAR CORRIDA PELO ID
  // ============================================================

  static RideModel? getRideById(
    String rideId,
  ) {
    for (final ride in _rides) {
      if (ride.id == rideId) {
        return ride;
      }
    }

    return null;
  }

  // ============================================================
  // ATUALIZAR STATUS
  // ============================================================

  static RideModel? updateStatus({
    required String rideId,
    required String status,
  }) {
    final index = _rides.indexWhere(
      (ride) => ride.id == rideId,
    );

    if (index == -1) {
      return null;
    }

    final currentRide =
        _rides[index];

    final completed =
        status == 'completed';

    final updatedRide =
        currentRide.copyWith(
      status: status,

      completedAt: completed
          ? DateTime.now()
          : currentRide.completedAt,
    );

    _rides[index] =
        updatedRide;

    return updatedRide;
  }

  // ============================================================
  // MOTORISTA ENCONTRADO
  // ============================================================

  static RideModel? driverFound(
    String rideId,
  ) {
    return updateStatus(
      rideId: rideId,
      status: 'driver_found',
    );
  }

  // ============================================================
  // MOTORISTA A CAMINHO
  // ============================================================

  static RideModel? driverArriving(
    String rideId,
  ) {
    return updateStatus(
      rideId: rideId,
      status: 'driver_arriving',
    );
  }

  // ============================================================
  // INICIAR CORRIDA
  // ============================================================

  static RideModel? startRide(
    String rideId,
  ) {
    return updateStatus(
      rideId: rideId,
      status: 'in_progress',
    );
  }

  // ============================================================
  // FINALIZAR CORRIDA
  // ============================================================

  static RideModel? completeRide(
    String rideId,
  ) {
    return updateStatus(
      rideId: rideId,
      status: 'completed',
    );
  }

  // ============================================================
  // CANCELAR CORRIDA
  // ============================================================

  static RideModel? cancelRide(
    String rideId,
  ) {
    return updateStatus(
      rideId: rideId,
      status: 'cancelled',
    );
  }

  // ============================================================
  // ADICIONAR AVALIAÇÃO
  // ============================================================

  static RideModel? rateRide({
    required String rideId,
    required double rating,
    String? comment,
  }) {
    final index = _rides.indexWhere(
      (ride) => ride.id == rideId,
    );

    if (index == -1) {
      return null;
    }

    final safeRating =
        rating.clamp(1.0, 5.0);

    final updatedRide =
        _rides[index].copyWith(
      userRating:
          safeRating.toDouble(),

      userComment:
          comment,
    );

    _rides[index] =
        updatedRide;

    return updatedRide;
  }

  // ============================================================
  // HISTÓRICO DO USUÁRIO
  // ============================================================

  static List<RideModel> getUserRides(
    String userId,
  ) {
    return _rides
        .where(
          (ride) =>
              ride.userId == userId,
        )
        .toList();
  }

  // ============================================================
  // TODAS AS CORRIDAS
  // ============================================================

  static List<RideModel> getAllRides() {
    return List.unmodifiable(
      _rides,
    );
  }

  // ============================================================
  // CORRIDAS CONCLUÍDAS
  // ============================================================

  static List<RideModel>
      getCompletedRides(
    String userId,
  ) {
    return _rides
        .where(
          (ride) =>
              ride.userId == userId &&
              ride.status == 'completed',
        )
        .toList();
  }

  // ============================================================
  // CORRIDAS DO MOTORISTA
  // ============================================================

  static List<RideModel>
      getDriverRides(
    String driverId,
  ) {
    return _rides
        .where(
          (ride) =>
              ride.driverId ==
              driverId,
        )
        .toList();
  }

  // ============================================================
  // CORRIDAS CONCLUÍDAS DO MOTORISTA
  // ============================================================

  static List<RideModel>
      getCompletedDriverRides(
    String driverId,
  ) {
    return _rides
        .where(
          (ride) =>
              ride.driverId ==
                  driverId &&
              ride.status ==
                  'completed',
        )
        .toList();
  }

  // ============================================================
  // TOTAL FATURADO
  // ============================================================

  static double getTotalFare(
    String userId,
  ) {
    return getCompletedRides(
      userId,
    ).fold(
      0.0,
      (
        total,
        ride,
      ) =>
          total + ride.fare,
    );
  }

  // ============================================================
  // TOTAL DE COMISSÃO DA MOTOGO
  // ============================================================

  static double getTotalCommission({
    String? userId,
  }) {
    final rides =
        userId == null
            ? _rides
            : getCompletedRides(
                userId,
              );

    return rides.fold(
      0.0,
      (
        total,
        ride,
      ) =>
          total +
          ride.platformCommission,
    );
  }

  // ============================================================
  // TOTAL GANHO PELO MOTORISTA
  // ============================================================

  static double getDriverTotalEarnings(
    String driverId,
  ) {
    return getCompletedDriverRides(
      driverId,
    ).fold(
      0.0,
      (
        total,
        ride,
      ) =>
          total +
          ride.driverEarnings,
    );
  }

  // ============================================================
  // QUANTIDADE DE CORRIDAS
  // ============================================================

  static int getCompletedRideCount(
    String userId,
  ) {
    return getCompletedRides(
      userId,
    ).length;
  }

  // ============================================================
  // LIMPAR DADOS TEMPORÁRIOS
  // ============================================================
  //
  // Útil durante os testes.
  // Não será usado na versão final.
  // ============================================================

  static void clearTemporaryData() {
    _rides.clear();
  }
}