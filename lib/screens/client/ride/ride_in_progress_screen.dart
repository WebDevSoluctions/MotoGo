import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../screens/ride/ride_rating_screen.dart';
import 'ride_chat_screen.dart';

class RideInProgressScreen extends StatefulWidget {
  final int rideId;
  final String rideType;
  final double ridePrice;

  final String driverName;
  final String vehicleModel;
  final String vehiclePlate;
  final String driverLevel;
  final int driverScore;

  const RideInProgressScreen({
    super.key,
    required this.rideId,
    required this.rideType,
    required this.ridePrice,
    required this.driverName,
    required this.vehicleModel,
    required this.vehiclePlate,
    this.driverLevel = 'Bronze',
    this.driverScore = 0,
  });

  @override
  State<RideInProgressScreen> createState() =>
      _RideInProgressScreenState();
}

class _RideInProgressScreenState
    extends State<RideInProgressScreen> {
  // ============================================================
  // CONTROLES
  // ============================================================

  final MapController _mapController = MapController();

  Timer? _statusTimer;
  Timer? _chatTimer;
  int _lastDriverMessageId = 0;
  Timer? _locationTimer;

  bool _checkingStatus = false;
  bool _loadingLocation = false;
  bool _loadingRoute = false;
  DateTime? _lastRouteAt;

  int? _userId;
  int? _driverId;
  String? _driverPhone;
  bool _isFavorite = false;
  bool _favoriteLoaded = false;
  List<Map<String, dynamic>> _rideStops = [];

  // ============================================================
  // LOCALIZAÇÕES
  // ============================================================

  LatLng? _driverPosition;
  LatLng? _originPosition;
  LatLng? _destinationPosition;

  List<LatLng> _routePoints = [];

  DateTime? _lastDriverUpdate;

  // Direção atual do motorista no mapa (graus).
  double _driverBearing = 0;

  String _rideStatus = 'driver_found';
  String _liveDriverLevel = 'Bronze';
  int _liveDriverScore = 0;
  String? _lastNotifiedStatus;

  // ============================================================
  // SERVIÇO
  // ============================================================

  String get serviceName {
    switch (widget.rideType) {
      case 'carro':
        return 'Carro';

      case 'delivery':
      case 'delivery_moto':
        return 'Moto Express';

      case 'delivery_bicicleta':
        return 'Bike Express';
      case 'delivery_pedestre':
        return 'Entrega a Pé';

      case 'viagem':
        return 'Viagem';

      default:
        return 'Mototáxi';
    }
  }

  // ============================================================
  // ÍCONE
  // ============================================================

  IconData get serviceIcon {
    switch (widget.rideType) {
      case 'carro':
        return Icons.directions_car;

      case 'delivery':
      case 'delivery_moto':
        return Icons.two_wheeler;

      case 'delivery_bicicleta':
        return Icons.pedal_bike;
      case 'delivery_pedestre':
        return Icons.directions_walk;

      case 'viagem':
        return Icons.directions_car_filled;

      default:
        return Icons.two_wheeler;
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String get statusText {
    switch (_rideStatus) {
      case 'driver_found':
        return 'Corrida aceita';

      case 'driver_arriving':
        return 'Motorista a caminho';

      case 'driver_arrived':
        return 'Motorista chegou';

      case 'in_progress':
        return 'Corrida em andamento';

      case 'completed':
        return 'Corrida concluída';

      case 'cancelled':
        return 'Corrida cancelada';

      default:
        return 'Aguardando motorista';
    }
  }

  Color get statusColor {
    switch (_rideStatus) {
      case 'driver_found':
        return Colors.blue;

      case 'driver_arriving':
        return Colors.orange;

      case 'driver_arrived':
        return Colors.purple;

      case 'in_progress':
        return Colors.green;

      case 'completed':
        return Colors.grey;

      case 'cancelled':
        return Colors.red;

      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _liveDriverLevel = widget.driverLevel;
    _liveDriverScore = widget.driverScore;

    NotificationService.initialize();
    _startRideTracking();
    _chatTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkDriverChat());
  }

  // ============================================================
  // INICIAR RASTREAMENTO
  // ============================================================

  Future<void> _startRideTracking() async {
    final userIdString =
        await AuthService.getUserId();

    if (!mounted) return;

    final userId = int.tryParse(
      userIdString ?? '',
    );

    if (userId == null || userId <= 0) {
      debugPrint(
        'Usuário não identificado.',
      );
      return;
    }

    _userId = userId;

    await _checkRideStatus();

    if (!mounted) return;

    _statusTimer?.cancel();
    _locationTimer?.cancel();

    // ==========================================================
    // STATUS
    // ==========================================================

    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _checkRideStatus();
      },
    );

    // ==========================================================
    // GPS MOTORISTA
    // ==========================================================

    _locationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        _loadDriverLocation();
      },
    );
  }

  // ============================================================
  // STATUS DA CORRIDA
  // ============================================================

  Future<void> _checkRideStatus() async {
    if (!mounted ||
        _checkingStatus ||
        _userId == null) {
      return;
    }

    _checkingStatus = true;

    try {
      final result =
          await ApiService.getRideStatus(
        rideId: widget.rideId,
        userId: _userId!,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        return;
      }

      final ride = result['ride'];

      if (ride is! Map) {
        return;
      }

      final status =
          ride['status']?.toString() ??
              '';

      final statusChanged =
          _lastNotifiedStatus != null &&
          _lastNotifiedStatus != status;

      _rideStatus = status;

      final dynamic driverIdValue = ride['driver_id'];
      final parsedDriverId = int.tryParse(driverIdValue?.toString() ?? '');
      if (parsedDriverId != _driverId) {
        _driverId = parsedDriverId;
        _favoriteLoaded = false;
      }

      final rawStops = ride['stops'];
      if (rawStops is List) {
        _rideStops = rawStops
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _rideStops = [];
      }

      if (_driverId != null && !_favoriteLoaded && _userId != null) {
        _favoriteLoaded = true;
        try {
          final favoriteResult = await ApiService.getFavoriteDrivers(_userId!);
          final favorites = favoriteResult['favorites'];
          if (favorites is List) {
            _isFavorite = favorites.any((f) =>
                f is Map && int.tryParse(f['driver_id']?.toString() ?? '') == _driverId);
          }
        } catch (_) {}
      }

      final driverData = ride['driver'];
      if (driverData is Map) {
        _driverPhone = driverData['phone']?.toString();
        _liveDriverLevel = driverData['driver_level']?.toString() ?? _liveDriverLevel;
        _liveDriverScore = int.tryParse(driverData['driver_score']?.toString() ?? '') ?? _liveDriverScore;
      }

      if (statusChanged) {
        final message = switch (status) {
          'driver_found' => 'O motorista aceitou sua corrida.',
          'driver_arriving' => 'O motorista está a caminho.',
          'driver_arrived' => 'O motorista chegou ao ponto de embarque.',
          'in_progress' => 'Sua corrida começou.',
          'completed' => 'Sua corrida foi concluída.',
          'cancelled' => 'Sua corrida foi cancelada.',
          _ => 'O status da sua corrida foi atualizado.',
        };

        await NotificationService.showRideStatus(
          rideId: widget.rideId,
          status: statusText,
          message: message,
        );
      }

      _lastNotifiedStatus = status;

      // ========================================================
      // PEGAR ORIGEM
      // ========================================================

      final originLat =
          _toDoubleNullable(
        ride['origin_latitude'],
      );

      final originLng =
          _toDoubleNullable(
        ride['origin_longitude'],
      );

      if (originLat != null &&
          originLng != null) {
        _originPosition = LatLng(
          originLat,
          originLng,
        );
      }

      // ========================================================
      // PEGAR DESTINO
      // ========================================================

      final destinationLat =
          _toDoubleNullable(
        ride['destination_latitude'],
      );

      final destinationLng =
          _toDoubleNullable(
        ride['destination_longitude'],
      );

      if (destinationLat != null &&
          destinationLng != null) {
        _destinationPosition = LatLng(
          destinationLat,
          destinationLng,
        );
      }

      // ========================================================
      // CARREGAR MOTORISTA
      // ========================================================

      if (status != 'completed' &&
          status != 'cancelled') {
        await _loadDriverLocation();
      }

      // ========================================================
      // ROTA
      // ========================================================

      final routeTarget = _rideStatus == 'driver_found' ||
              _rideStatus == 'driver_arriving' ||
              _rideStatus == 'driver_arrived'
          ? _originPosition
          : _destinationPosition;

      if (_driverPosition != null && routeTarget != null) {
        await _loadRoute(_driverPosition!, routeTarget);
      }

      if (!mounted) return;

      setState(() {});

      // ========================================================
      // FINALIZADA
      // ========================================================

      if (status == 'completed') {
        _statusTimer?.cancel();
        _locationTimer?.cancel();

        await _showCompletedDialog();

        return;
      }

      // ========================================================
      // CANCELADA
      // ========================================================

      if (status == 'cancelled') {
        _statusTimer?.cancel();
        _locationTimer?.cancel();

        await _showCancelledDialog();

        return;
      }
    } catch (e) {
      debugPrint(
        'Erro ao consultar status: $e',
      );
    } finally {
      _checkingStatus = false;
    }
  }

  // ============================================================
  // LOCALIZAÇÃO DO MOTORISTA
  // ============================================================

  Future<void> _loadDriverLocation() async {
    if (!mounted || _loadingLocation) {
      return;
    }

    _loadingLocation = true;

    try {
      final result =
          await ApiService.getDriverLocation(
        rideId: widget.rideId,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        return;
      }

      final driver =
          result['driver'];

      if (driver is! Map) {
        return;
      }

      final available =
          driver['location_available'] == true;

      if (!available) {
        return;
      }

      final latitude =
          _toDoubleNullable(
        driver['latitude'],
      );

      final longitude =
          _toDoubleNullable(
        driver['longitude'],
      );

      if (latitude == null ||
          longitude == null) {
        return;
      }

      final newPosition = LatLng(
        latitude,
        longitude,
      );

      final oldPosition =
          _driverPosition;

      // Calcula o sentido do deslocamento do motorista.
      if (oldPosition != null) {
        final moved =
            oldPosition.latitude != newPosition.latitude ||
            oldPosition.longitude != newPosition.longitude;

        if (moved) {
          final bearing = _calculateBearing(
            oldPosition,
            newPosition,
          );

          if (bearing.isFinite) {
            _driverBearing = bearing;
          }
        }
      }

      _driverPosition = newPosition;

      _lastDriverUpdate = DateTime.now();

      // Mantém o motorista visível no mapa durante o acompanhamento.
      if (oldPosition != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _mapController.move(newPosition, 15.5);
          } catch (_) {}
        });
      }

      if (mounted) {
        setState(() {});
      }

      // ========================================================
      // CENTRALIZAR PRIMEIRA POSIÇÃO
      // ========================================================

      if (oldPosition == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) {
          if (!mounted) return;

          _mapController.move(
            newPosition,
            15.5,
          );
        });
      }

      // ========================================================
      // ROTA
      // ========================================================

      final routeTarget = _rideStatus == 'driver_found' ||
              _rideStatus == 'driver_arriving' ||
              _rideStatus == 'driver_arrived'
          ? _originPosition
          : _destinationPosition;

      if (routeTarget != null) {
        await _loadRoute(newPosition, routeTarget);
      }
    } catch (e) {
      debugPrint(
        'Erro ao carregar GPS do motorista: $e',
      );
    } finally {
      _loadingLocation = false;
    }
  }

  // ============================================================
  // ROTA REAL
  // ============================================================

  Future<void> _loadRoute(
    LatLng from,
    LatLng to,
  ) async {
    if (_loadingRoute) return;

    final now = DateTime.now();
    if (_lastRouteAt != null &&
        now.difference(_lastRouteAt!).inSeconds < 8) {
      return;
    }
    _lastRouteAt = now;

    _loadingRoute = true;

    try {
      final routePoints = <LatLng>[from];
      if (_rideStatus == 'in_progress' && _rideStops.isNotEmpty) {
        for (final stop in _rideStops) {
          final lat = _toDoubleNullable(stop['latitude']);
          final lng = _toDoubleNullable(stop['longitude']);
          if (lat != null && lng != null) routePoints.add(LatLng(lat, lng));
        }
      }
      routePoints.add(to);

      final routeCoordinates = routePoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$routeCoordinates'
        '?overview=full&geometries=geojson',
      );

      final response =
          await http.get(url);

      if (response.statusCode != 200) {
        _setFallbackRoute(from, to);
        return;
      }

      final data =
          jsonDecode(response.body);

      if (data is! Map) {
        _setFallbackRoute(from, to);
        return;
      }

      final routes =
          data['routes'];

      if (routes is! List ||
          routes.isEmpty) {
        _setFallbackRoute(from, to);
        return;
      }

      final route =
          routes.first;

      final geometry =
          route['geometry'];

      if (geometry is! Map) {
        _setFallbackRoute(from, to);
        return;
      }

      final geometryCoordinates =
          geometry['coordinates'];

      if (geometryCoordinates is! List ||
          geometryCoordinates.isEmpty) {
        _setFallbackRoute(from, to);
        return;
      }

      final points = <LatLng>[];

      for (final coordinate
          in geometryCoordinates) {
        if (coordinate is List &&
            coordinate.length >= 2) {
          final longitude =
              _toDoubleNullable(
            coordinate[0],
          );

          final latitude =
              _toDoubleNullable(
            coordinate[1],
          );

          if (latitude != null &&
              longitude != null) {
            points.add(
              LatLng(
                latitude,
                longitude,
              ),
            );
          }
        }
      }

      if (points.length >= 2) {
        if (mounted) {
          setState(() {
            _routePoints = points;
          });
        }
      } else {
        _setFallbackRoute(
          from,
          to,
        );
      }
    } catch (e) {
      debugPrint(
        'Erro ao calcular rota: $e',
      );

      _setFallbackRoute(
        from,
        to,
      );
    } finally {
      _loadingRoute = false;
    }
  }

  // ============================================================
  // ROTA DE FALLBACK
  // ============================================================

  void _setFallbackRoute(
    LatLng from,
    LatLng to,
  ) {
    if (!mounted) return;

    setState(() {
      _routePoints = [
        from,
        to,
      ];
    });
  }

  // ============================================================
  // DIREÇÃO DO MOTORISTA
  // ============================================================

  double _calculateBearing(
    LatLng from,
    LatLng to,
  ) {
    final lat1 =
        from.latitude * math.pi / 180;
    final lat2 =
        to.latitude * math.pi / 180;

    final deltaLongitude =
        (to.longitude - from.longitude) *
            math.pi /
            180;

    final y =
        math.sin(deltaLongitude) *
        math.cos(lat2);

    final x =
        math.cos(lat1) *
            math.sin(lat2) -
        math.sin(lat1) *
            math.cos(lat2) *
            math.cos(deltaLongitude);

    final bearing =
        math.atan2(y, x) *
        180 /
        math.pi;

    return (bearing + 360) % 360;
  }

  // ============================================================
  // CONVERTER DOUBLE
  // ============================================================

  double? _toDoubleNullable(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // MAPA
  // ============================================================

  Widget _buildRealMap() {
    final markers = <Marker>[];

    final center =
        _driverPosition ??
        _originPosition ??
        _destinationPosition ??
        const LatLng(-21.1107, -44.1752);

    if (_driverPosition != null) {
      markers.add(
        Marker(
          point: _driverPosition!,
          width: 92,
          height: 104,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle:
                _driverBearing *
                math.pi /
                180,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Seta mostrando o sentido do motorista.
                Positioned(
                  top: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),

                // Marcador principal.
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.primary.withOpacity(.30),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      serviceIcon,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // ORIGEM
    // ==========================================================

    if (_originPosition != null) {
      markers.add(
        Marker(
          point: _originPosition!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // PARADAS
    // ==========================================================

    for (var i = 0; i < _rideStops.length; i++) {
      final stop = _rideStops[i];
      final lat = _toDoubleNullable(stop['latitude']);
      final lng = _toDoubleNullable(stop['longitude']);
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 52,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // DESTINO
    // ==========================================================

    if (_destinationPosition != null) {
      markers.add(
        Marker(
          point: _destinationPosition!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.fromLTRB(
        15,
        5,
        15,
        10,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController:
                _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.5,
              minZoom: 5,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.motogo.app',
              ),

              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: AppColors.primary,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: markers,
              ),
            ],
          ),

          // ======================================================
          // STATUS DO GPS
          // ======================================================

          Positioned(
            top: 18,
            left: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(
                      .10,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _driverPosition !=
                                  null
                              ? Colors.green
                              : Colors.orange,
                    ),
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Text(
                    _driverPosition !=
                            null
                        ? 'Motorista localizado'
                        : 'Localizando motorista...',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // CENTRALIZAR MOTORISTA
          // ======================================================

          Positioned(
            right: 18,
            bottom: 18,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shape:
                  const CircleBorder(),
              child: InkWell(
                customBorder:
                    const CircleBorder(),
                onTap: () {
                  if (_driverPosition ==
                      null) {
                    return;
                  }

                  _mapController.move(
                    _driverPosition!,
                    16,
                  );
                },
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: Icon(
                    Icons.my_location,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAINEL INFERIOR
  // ============================================================

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ========================================================
          // STATUS
          // ========================================================

          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_lastDriverUpdate != null)
                Text(
                  'GPS atualizado',
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ========================================================
          // MOTORISTA
          // ========================================================

          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppColors.primary
                          .withOpacity(.10),
                ),
                child: Icon(
                  Icons.person,
                  color:
                      AppColors.primary,
                  size: 34,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color:
                              Colors.amber,
                          size: 17,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        const Text(
                          '4.9',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        Text(
                          'Motorista parceiro',
                          style: TextStyle(
                            color:
                                Colors.grey
                                    .shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _roundActionButton(
                icon: Icons.chat,
                color: Colors.green,
                onTap: _openDriverWhatsApp,
              ),

              const SizedBox(width: 8),

              _roundActionButton(
                icon: Icons.chat_outlined,
                color: AppColors.primary,
                onTap: _openRideChat,
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ========================================================
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_liveDriverLevel == 'Elite' ? '💎' : _liveDriverLevel == 'Ouro' ? '🥇' : _liveDriverLevel == 'Prata' ? '🥈' : '🥉'} $_liveDriverLevel • $_liveDriverScore pts',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // VEÍCULO
          // ========================================================

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  Colors.grey.shade50,
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  serviceIcon,
                  color:
                      Colors.grey.shade700,
                  size: 25,
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vehicleModel,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Veículo parceiro',
                        style: TextStyle(
                          color:
                              Colors.grey
                                  .shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    widget.vehiclePlate,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // ========================================================
          // VALOR
          // ========================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor da corrida',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              Text(
                'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}',
                style:
                    const TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ========================================================
          // COMPARTILHAR
          // ========================================================

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _shareRideOnWhatsApp,
              icon: const Icon(Icons.share),
              label: const Text('🛡️ Compartilhar viagem com alguém'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),

          if (_driverId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _favoriteCurrentDriver,
                icon: Icon(_isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
                label: Text(_isFavorite ? '⭐ Motorista salvo nos favoritos' : '⭐ Favoritar este motorista'),
              ),
            ),
          ],

          if (_rideStops.isNotEmpty) ...[
            const SizedBox(height: 12),
            _rideStopsCard(),
          ],

          const SizedBox(height: 10),

          // ========================================================
          // CANCELAR
          // ========================================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                OutlinedButton(
              onPressed:
                  _cancelRide,
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red,
                side:
                    const BorderSide(
                  color: Colors.red,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
              child: const Text(
                'Cancelar corrida',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideStopsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: Colors.orange),
              SizedBox(width: 8),
              Text('Paradas da viagem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _rideStops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_rideStops[i]['address']?.toString() ?? 'Parada ${i + 1}')),
                ],
              ),
            ),
          const Text('O mapa mostra cada parada em ordem.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // BOTÃO REDONDO
  // ============================================================

  Widget _roundActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(30),
      child: Container(
        width: 43,
        height: 43,
        decoration:
            BoxDecoration(
          shape: BoxShape.circle,
          color:
              color.withOpacity(.10),
        ),
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
    );
  }

  // ============================================================
  // CANCELAR
  // ============================================================

  Future<void> _cancelRide() async {
    if (_userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar corrida?'),
          content: const Text(
            'Tem certeza que deseja cancelar a corrida atual?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Voltar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Cancelar corrida',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await ApiService.cancelRide(
      rideId: widget.rideId,
      userId: _userId!,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                'Não foi possível cancelar a corrida.',
          ),
        ),
      );
      return;
    }

    _statusTimer?.cancel();
    _locationTimer?.cancel();

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _shareRideOnWhatsApp() async {
    if (_userId == null) return;
    final result = await ApiService.createRideShare(userId: _userId!, rideId: widget.rideId);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível gerar o link.')));
      return;
    }
    final trackingUrl = result['share_url']?.toString() ?? '';
    final message = Uri.encodeComponent(
      'Estou em uma corrida MotoGo.\n'
      'Motorista: ${widget.driverName}\n'
      'Acompanhe minha viagem em tempo real: $trackingUrl',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')));
    }
  }

  Future<void> _openDriverWhatsApp() async {
    final raw = (_driverPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O WhatsApp do motorista não está disponível.')));
      return;
    }
    final phone = raw.startsWith('55') ? raw : '55$raw';
    final text = Uri.encodeComponent('Olá! Estou na minha corrida MotoGo.');
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')));
    }
  }

  void _openRideChat() {
    if (_userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideChatScreen(rideId: widget.rideId, userId: _userId!, driverName: widget.driverName),
      ),
    );
  }

  Future<void> _favoriteCurrentDriver() async {
    if (_userId == null || _driverId == null) return;
    final result = _isFavorite
        ? await ApiService.removeFavoriteDriver(userId: _userId!, driverId: _driverId!)
        : await ApiService.addFavoriteDriver(userId: _userId!, driverId: _driverId!);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _isFavorite = !_isFavorite);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível atualizar favorito.')));
  }

  // ============================================================
  // CORRIDA CONCLUÍDA
  // ============================================================

  Future<void> _showCompletedDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Corrida finalizada',
          ),
          content: const Text(
            'Sua corrida foi concluída com sucesso.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Voltar ao início',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RideRatingScreen(
          rideId: widget.rideId,
          rideType: widget.rideType,
          driverName: widget.driverName,
          vehicle: widget.vehicleModel,
          plate: widget.vehiclePlate,
          ridePrice: widget.ridePrice,
        ),
      ),
    );
  }

  // ============================================================
  // CORRIDA CANCELADA
  // ============================================================

  Future<void> _showCancelledDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Corrida cancelada',
          ),
          content: const Text(
            'Esta corrida foi cancelada.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Voltar ao início',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.popUntil(
      context,
      (route) => route.isFirst,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        backgroundColor:
            AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Corrida em andamento',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _buildRealMap(),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Future<void> _checkDriverChat() async {
    final userId = int.tryParse(await AuthService.getUserId() ?? '');
    if (userId == null) return;
    final result = await ApiService.getRideChat(userId: userId, rideId: widget.rideId);
    if (!mounted || result['success'] != true) return;
    final list = result['messages'] is List ? List<dynamic>.from(result['messages']) : <dynamic>[];
    if (_lastDriverMessageId == 0) {
      for (final item in list) {
        final m = item as Map;
        _lastDriverMessageId = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
      }
      return;
    }
    for (final item in list) {
      final m = item as Map;
      final id = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
      final mine = m['sender_type']?.toString() == 'client';
      if (id > _lastDriverMessageId) {
        _lastDriverMessageId = id;
        if (!mine) {
          await NotificationService.showChatMessage(rideId: widget.rideId, senderName: m['sender_name']?.toString() ?? widget.driverName, message: m['message']?.toString() ?? 'Nova mensagem');
        }
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _chatTimer?.cancel();
    _statusTimer?.cancel();
    _locationTimer?.cancel();

    super.dispose();
  }
}