import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_model.dart';

class FirebaseRideService {
  // ============================================================
  // FIRESTORE
  // ============================================================

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // COLEÇÃO PRINCIPAL
  // ============================================================

  static CollectionReference<Map<String, dynamic>>
      get _ridesCollection {
    return _firestore.collection('rides');
  }

  // ============================================================
  // SALVAR CORRIDA
  // ============================================================

  static Future<void> saveRide(
    RideModel ride,
  ) async {
    await _ridesCollection
        .doc(ride.id)
        .set(
      {
        ...ride.toMap(),

        // Data própria do Firestore
        'createdAt':
            Timestamp.fromDate(
          ride.createdAt,
        ),

        'completedAt':
            ride.completedAt == null
                ? null
                : Timestamp.fromDate(
                    ride.completedAt!,
                  ),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // BUSCAR UMA CORRIDA
  // ============================================================

  static Future<RideModel?> getRideById(
    String rideId,
  ) async {
    final document =
        await _ridesCollection
            .doc(rideId)
            .get();

    if (!document.exists) {
      return null;
    }

    final data =
        document.data();

    if (data == null) {
      return null;
    }

    return RideModel.fromMap(
      _normalizeFirestoreData(
        data,
      ),
    );
  }

  // ============================================================
  // HISTÓRICO DO USUÁRIO
  // ============================================================

  static Future<List<RideModel>>
      getUserRides(
    String userId,
  ) async {
    final snapshot =
        await _ridesCollection
            .where(
              'userId',
              isEqualTo: userId,
            )
            .get();

    final rides =
        snapshot.docs.map(
      (document) {
        final data =
            document.data();

        return RideModel.fromMap(
          _normalizeFirestoreData(
            data,
          ),
        );
      },
    ).toList();

    rides.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return rides;
  }

  // ============================================================
  // HISTÓRICO EM TEMPO REAL
  // ============================================================

  static Stream<List<RideModel>>
      watchUserRides(
    String userId,
  ) {
    return _ridesCollection
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots()
        .map(
      (snapshot) {
        final rides =
            snapshot.docs.map(
          (document) {
            final data =
                document.data();

            return RideModel.fromMap(
              _normalizeFirestoreData(
                data,
              ),
            );
          },
        ).toList();

        rides.sort(
          (a, b) =>
              b.createdAt.compareTo(
            a.createdAt,
          ),
        );

        return rides;
      },
    );
  }

  // ============================================================
  // ATUALIZAR CORRIDA
  // ============================================================

  static Future<void> updateRide(
    RideModel ride,
  ) async {
    await _ridesCollection
        .doc(ride.id)
        .set(
      {
        ...ride.toMap(),

        'createdAt':
            Timestamp.fromDate(
          ride.createdAt,
        ),

        'completedAt':
            ride.completedAt == null
                ? null
                : Timestamp.fromDate(
                    ride.completedAt!,
                  ),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // ATUALIZAR STATUS
  // ============================================================

  static Future<void> updateStatus({
    required String rideId,
    required String status,
  }) async {
    final data =
        <String, dynamic>{
      'status': status,
    };

    if (status == 'completed') {
      data['completedAt'] =
          Timestamp.now();
    }

    await _ridesCollection
        .doc(rideId)
        .update(data);
  }

  // ============================================================
  // MOTORISTA ENCONTRADO
  // ============================================================

  static Future<void> driverFound(
    String rideId,
  ) async {
    await updateStatus(
      rideId: rideId,
      status: 'driver_found',
    );
  }

  // ============================================================
  // MOTORISTA A CAMINHO
  // ============================================================

  static Future<void> driverArriving(
    String rideId,
  ) async {
    await updateStatus(
      rideId: rideId,
      status: 'driver_arriving',
    );
  }

  // ============================================================
  // INICIAR CORRIDA
  // ============================================================

  static Future<void> startRide(
    String rideId,
  ) async {
    await updateStatus(
      rideId: rideId,
      status: 'in_progress',
    );
  }

  // ============================================================
  // FINALIZAR CORRIDA
  // ============================================================

  static Future<void> completeRide(
    String rideId,
  ) async {
    await updateStatus(
      rideId: rideId,
      status: 'completed',
    );
  }

  // ============================================================
  // CANCELAR CORRIDA
  // ============================================================

  static Future<void> cancelRide(
    String rideId,
  ) async {
    await updateStatus(
      rideId: rideId,
      status: 'cancelled',
    );
  }

  // ============================================================
  // AVALIAR CORRIDA
  // ============================================================

  static Future<void> rateRide({
    required String rideId,
    required double rating,
    String? comment,
  }) async {
    final safeRating =
        rating.clamp(1.0, 5.0);

    await _ridesCollection
        .doc(rideId)
        .update(
      {
        'userRating':
            safeRating.toDouble(),

        'userComment':
            comment,
      },
    );
  }

  // ============================================================
  // CORRIDAS DO MOTORISTA
  // ============================================================

  static Future<List<RideModel>>
      getDriverRides(
    String driverId,
  ) async {
    final snapshot =
        await _ridesCollection
            .where(
              'driverId',
              isEqualTo: driverId,
            )
            .get();

    final rides =
        snapshot.docs.map(
      (document) {
        return RideModel.fromMap(
          _normalizeFirestoreData(
            document.data(),
          ),
        );
      },
    ).toList();

    rides.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return rides;
  }

  // ============================================================
  // CORRIDAS CONCLUÍDAS DO MOTORISTA
  // ============================================================

  static Future<List<RideModel>>
      getCompletedDriverRides(
    String driverId,
  ) async {
    final snapshot =
        await _ridesCollection
            .where(
              'driverId',
              isEqualTo: driverId,
            )
            .where(
              'status',
              isEqualTo: 'completed',
            )
            .get();

    final rides =
        snapshot.docs.map(
      (document) {
        return RideModel.fromMap(
          _normalizeFirestoreData(
            document.data(),
          ),
        );
      },
    ).toList();

    rides.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return rides;
  }

  // ============================================================
  // TOTAL DE COMISSÃO
  // ============================================================

  static Future<double>
      getTotalCommission({
    String? userId,
  }) async {
    Query<Map<String, dynamic>>
        query = _ridesCollection.where(
      'status',
      isEqualTo: 'completed',
    );

    if (userId != null) {
      query = query.where(
        'userId',
        isEqualTo: userId,
      );
    }

    final snapshot =
        await query.get();

    double total = 0;

    for (final document
        in snapshot.docs) {
      final data =
          document.data();

      final value =
          data['platformCommission'];

      if (value is num) {
        total += value.toDouble();
      }
    }

    return total;
  }

  // ============================================================
  // TOTAL GANHO DO MOTORISTA
  // ============================================================

  static Future<double>
      getDriverTotalEarnings(
    String driverId,
  ) async {
    final snapshot =
        await _ridesCollection
            .where(
              'driverId',
              isEqualTo: driverId,
            )
            .where(
              'status',
              isEqualTo: 'completed',
            )
            .get();

    double total = 0;

    for (final document
        in snapshot.docs) {
      final data =
          document.data();

      final value =
          data['driverEarnings'];

      if (value is num) {
        total += value.toDouble();
      }
    }

    return total;
  }

  // ============================================================
  // CONVERTER TIMESTAMP
  // ============================================================

  static Map<String, dynamic>
      _normalizeFirestoreData(
    Map<String, dynamic> data,
  ) {
    final normalized =
        Map<String, dynamic>.from(
      data,
    );

    final createdAt =
        normalized['createdAt'];

    if (createdAt
        is Timestamp) {
      normalized['createdAt'] =
          createdAt.toDate()
              .toIso8601String();
    }

    final completedAt =
        normalized['completedAt'];

    if (completedAt
        is Timestamp) {
      normalized['completedAt'] =
          completedAt.toDate()
              .toIso8601String();
    }

    return normalized;
  }
}