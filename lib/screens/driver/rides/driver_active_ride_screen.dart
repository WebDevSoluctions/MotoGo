import '../../../config/api_config.dart';

import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import 'package:geolocator/geolocator.dart';

import 'package:http/http.dart' as http;

import '../../../config/colors.dart';

import '../../../services/auth_service.dart';

import '../../../services/api_service.dart';

import '../../../services/notification_service.dart';
import '../../../services/active_ride_storage.dart';

import '../../client/ride/ride_chat_screen.dart';

import 'driver_rating_screen.dart';

class DriverActiveRideScreen extends StatefulWidget {

  final int rideId;

  final String passengerName;

  final String rideType;

  final String origin;

  final String destination;

  final double distanceKm;

  final double ridePrice;

  final int passengerPoints;

  final String passengerLevel;

  final List<Map<String, dynamic>> stops;

  const DriverActiveRideScreen({

    super.key,

    required this.rideId,

    required this.passengerName,

    required this.rideType,

    required this.origin,

    required this.destination,

    required this.distanceKm,

    required this.ridePrice,

    this.passengerPoints = 0,

    this.passengerLevel = 'Bronze',

    this.stops = const [],

  });

  @override

  State<DriverActiveRideScreen> createState() =>

      _DriverActiveRideScreenState();

}

class _DriverActiveRideScreenState

    extends State<DriverActiveRideScreen> {

  // ============================================================

  // API

  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================

  // ESTADO

  // ============================================================

  String status = 'driver_found';
  String? _lastNotifiedStatus;

  bool processing = false;

  // Evita tratar o mesmo cancelamento remoto mais de uma vez.
  bool _remoteCancellationHandled = false;

  // ============================================================

  // GPS

  // ============================================================

  StreamSubscription<Position>? _positionSubscription;

  Timer? _gpsHeartbeatTimer;

  Timer? _trackTimer;

  Timer? _chatTimer;
  Timer? _rideStatusTimer;
  bool _checkingRideStatus = false;

  int _lastClientMessageId = 0;

  final MapController _mapController = MapController();

  LatLng? _originPosition;

  LatLng? _destinationPosition;

  LatLng? _serverDriverPosition;

  List<LatLng> _routePoints = [];

  List<Map<String, dynamic>> _rideStops = [];

  bool _loadingTrack = false;

  DateTime? _lastRouteAt;

  Position? _currentPosition;

  int? _driverId;

  bool _locationStarted = false;
  bool _autoFollowMap = true;

  bool _sendingLocation = false;

  String _locationMessage = 'Localização aguardando...';

  Future<void> _checkChat() async {

    final userId = int.tryParse(await AuthService.getUserId() ?? '');

    if (userId == null) return;

    final result = await ApiService.getRideChat(userId: userId, rideId: widget.rideId);

    if (!mounted || result['success'] != true) return;

    final list = result['messages'] is List ? List<dynamic>.from(result['messages']) : <dynamic>[];

    if (_lastClientMessageId == 0) {

      for (final item in list) {

        final m = item as Map;

        _lastClientMessageId = int.tryParse(m['id']?.toString() ?? '0') ?? 0;

      }

      return;

    }

    for (final item in list) {

      final m = item as Map;

      final id = int.tryParse(m['id']?.toString() ?? '0') ?? 0;

      final mine = m['sender_type']?.toString() == 'driver';

      if (id > _lastClientMessageId) {

        _lastClientMessageId = id;

        if (!mine) {

          await NotificationService.showChatMessage(rideId: widget.rideId, senderName: m['sender_name']?.toString() ?? 'Cliente', message: m['message']?.toString() ?? 'Nova mensagem');

        }

      }

    }

  }

  // ============================================================

  // STATUS

  // ============================================================

  String get statusText {

    switch (status) {

      case 'driver_found':

        return 'Corrida aceita';

      case 'driver_arriving':

        return 'A caminho do passageiro';

      case 'driver_arrived':

        return 'Você chegou ao local';

      case 'in_progress':

        return 'Corrida em andamento';

      case 'completed':

        return 'Corrida concluída';

      case 'cancelled':

        return 'Corrida cancelada';

      default:

        return status;

    }

  }

  // ============================================================

  // COR DO STATUS

  // ============================================================

  Color get statusColor {

    switch (status) {

      case 'driver_found':

        return Colors.blue;

      case 'driver_arriving':

        return Colors.orange;

      case 'driver_arrived':
        return Colors.green;

      case 'in_progress':
        return AppColors.primary;

      case 'completed':
        return Colors.green;

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

    _loadMapPreference();
    _initializeDriverAndLocation();

    _chatTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkChat());

  }

  // ============================================================

  // INICIALIZAR MOTORISTA + GPS

  // ============================================================

  Future<void> _loadMapPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoFollowMap = prefs.getBool('driver_auto_follow_map') ?? true;
    });
  }

  Future<void> _initializeDriverAndLocation() async {

    try {

      final String? userId =

          await AuthService.getUserId();

      if (userId == null || userId.trim().isEmpty) {

        if (mounted) {

          setState(() {

            _locationMessage =

                'Motorista não identificado.';

          });

        }

        return;

      }

      // ========================================================

      // BUSCAR DRIVER ID

      // ========================================================

      final Uri driverUrl = Uri.parse(

        '$baseUrl/drivers/by_user.php'

        '?user_id=${Uri.encodeQueryComponent(userId)}',

      );

      final http.Response driverResponse =

          await http.get(

        driverUrl,

        headers: const {

          'Accept': 'application/json',

        },

      );

      if (driverResponse.statusCode != 200) {

        throw Exception(

          'Não foi possível identificar o motorista.',

        );

      }

      dynamic driverDecoded;

      try {

        driverDecoded =

            jsonDecode(driverResponse.body);

      } catch (_) {

        throw Exception(

          'Resposta inválida ao buscar motorista.',

        );

      }

      if (driverDecoded

          is! Map<String, dynamic>) {

        throw Exception(

          'Resposta inválida do servidor.',

        );

      }

      if (driverDecoded['success'] != true) {

        throw Exception(

          driverDecoded['message']?.toString() ??

              'Motorista não encontrado.',

        );

      }

      final dynamic driverData =

          driverDecoded['driver'];

      if (driverData is! Map) {

        throw Exception(

          'Dados do motorista inválidos.',

        );

      }

      final int? driverId =

          int.tryParse(

        driverData['id']?.toString() ?? '',

      );

      if (driverId == null || driverId <= 0) {

        throw Exception(

          'ID do motorista não encontrado.',

        );

      }

      _driverId = driverId;

      // ========================================================
      // INICIAR MONITORAMENTO DO STATUS DA CORRIDA
      // ========================================================
      // O servidor é a fonte da verdade. A consulta começa somente
      // depois que o driver_id foi identificado.
      _startRideStatusPolling();

      // ========================================================

      // INICIAR GPS

      // ========================================================

      await _startLocationTracking();

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _locationMessage =

            e.toString().replaceFirst(

                  'Exception: ',

                  '',

                );

      });

      _showMessage(

        e.toString().replaceFirst(

              'Exception: ',

              '',

            ),

      );

    }

  }

  // ============================================================

  // INICIAR RASTREAMENTO GPS

  // ============================================================

  Future<void> _startLocationTracking() async {

    if (_locationStarted) return;

    // ==========================================================

    // VERIFICAR SERVIÇO DE LOCALIZAÇÃO

    // ==========================================================

    final bool serviceEnabled =

        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {

      if (mounted) {

        setState(() {

          _locationMessage =

              'Ative o GPS do aparelho.';

        });

      }

      _showMessage(

        'Ative o GPS do aparelho para continuar.',

      );

      return;

    }

    // ==========================================================

    // VERIFICAR PERMISSÃO

    // ==========================================================

    LocationPermission permission =

        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {

      permission =

          await Geolocator.requestPermission();

    }

    if (permission == LocationPermission.denied) {

      if (mounted) {

        setState(() {

          _locationMessage =

              'Permissão de localização negada.';

        });

      }

      _showMessage(

        'Permissão de localização negada.',

      );

      return;

    }

    if (permission ==

            LocationPermission.deniedForever) {

      if (mounted) {

        setState(() {

          _locationMessage =

              'Permissão bloqueada nas configurações.';

        });

      }

      _showMessage(

        'A localização está bloqueada. '

        'Permita o acesso ao GPS nas configurações.',

      );

      return;

    }

    // ==========================================================

    // PEGAR POSIÇÃO INICIAL

    // ==========================================================

    try {

      final Position position =

          await Geolocator.getCurrentPosition(

        locationSettings:

            const LocationSettings(

          accuracy: LocationAccuracy.high,

        ),

      );

      _currentPosition = position;

      await _sendLocation(position);

    } catch (e) {

      if (mounted) {

        setState(() {

          _locationMessage =

              'Não foi possível obter sua localização.';

        });

      }

    }

    // ==========================================================

    // CONFIGURAÇÃO DO STREAM

    // ==========================================================

    const LocationSettings locationSettings =

        LocationSettings(

      accuracy: LocationAccuracy.high,

      distanceFilter: 5,

    );

    _positionSubscription =

        Geolocator.getPositionStream(

      locationSettings: locationSettings,

    ).listen(

      (Position position) async {

        _currentPosition = position;

        if (_autoFollowMap) {
          try {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
            );
          } catch (_) {}
        }

        if (mounted) {

          setState(() {

            _locationMessage =

                'GPS conectado • '

                '${position.latitude.toStringAsFixed(5)}, '

                '${position.longitude.toStringAsFixed(5)}';

          });

        }

        await _sendLocation(position);

      },

      onError: (error) {

        if (!mounted) return;

        setState(() {

          _locationMessage =

              'Erro no GPS: $error';

        });

      },

    );

    _locationStarted = true;

    _gpsHeartbeatTimer?.cancel();

    _gpsHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {

      try {

        final position = await Geolocator.getCurrentPosition(

          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),

        );

        _currentPosition = position;

        await _sendLocation(position);

      } catch (_) {}

    });

    _trackTimer?.cancel();

    _loadRideTrack();

    _trackTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadRideTrack());

    if (mounted) {

      setState(() {

        _locationMessage =

            'GPS conectado. Localização sendo enviada.';

      });

    }

  }

  // ============================================================

  // ENVIAR LOCALIZAÇÃO PARA API

  // ============================================================

  Future<void> _sendLocation(

    Position position,

  ) async {

    if (_driverId == null) return;

    // Evita várias requisições simultâneas

    if (_sendingLocation) return;

    _sendingLocation = true;

    try {

      final Uri url = Uri.parse(

        '$baseUrl/drivers/location.php',

      );

      final http.Response response =

          await http.post(

        url,

        headers: const {

          'Content-Type':

              'application/json',

          'Accept':

              'application/json',

        },

        body: jsonEncode({

          'driver_id': _driverId,

          'latitude': position.latitude,

          'longitude': position.longitude,

        }),

      );

      if (response.statusCode != 200) {

        debugPrint(

          'Erro ao enviar localização: '

          '${response.statusCode}',

        );

        return;

      }

      dynamic decoded;

      try {

        decoded = jsonDecode(response.body);

      } catch (_) {

        debugPrint(

          'Resposta inválida ao enviar localização.',

        );

        return;

      }

      if (decoded is Map &&

          decoded['success'] == true) {

        if (mounted) {

          setState(() {

            _locationMessage =

                'Localização atualizada • '

                '${position.latitude.toStringAsFixed(5)}, '

                '${position.longitude.toStringAsFixed(5)}';

          });

        }

      } else {

        debugPrint(

          'API recusou localização: '

          '${response.body}',

        );

      }

    } catch (e) {

      debugPrint(

        'Erro ao enviar GPS: $e',

      );

    } finally {

      _sendingLocation = false;

    }

  }

  // ============================================================

  // PARAR GPS

  // ============================================================

  Future<void> _stopLocationTracking() async {

    await _positionSubscription?.cancel();

    _positionSubscription = null;

    _gpsHeartbeatTimer?.cancel();

    _gpsHeartbeatTimer = null;

    _trackTimer?.cancel();

    _trackTimer = null;

    _locationStarted = false;

  }

  Future<void> _loadRideTrack() async {

    if (_driverId == null || _loadingTrack || !mounted) return;

    _loadingTrack = true;

    try {

      final response = await http.post(

        Uri.parse('$baseUrl/rides/track.php'),

        headers: const {

          'Content-Type': 'application/json',

          'Accept': 'application/json',

        },

        body: jsonEncode({

          'ride_id': widget.rideId,

          'driver_id': _driverId,

        }),

      );

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['success'] != true) return;

      final ride = decoded['ride'];

      if (ride is Map) {

        final rawStops = ride['stops'];

        if (rawStops is List) {

          _rideStops = rawStops.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

        }

        final olat = double.tryParse(ride['origin_latitude']?.toString() ?? '');

        final olng = double.tryParse(ride['origin_longitude']?.toString() ?? '');

        final dlat = double.tryParse(ride['destination_latitude']?.toString() ?? '');

        final dlng = double.tryParse(ride['destination_longitude']?.toString() ?? '');

        if (olat != null && olng != null) _originPosition = LatLng(olat, olng);

        if (dlat != null && dlng != null) _destinationPosition = LatLng(dlat, dlng);

      }

      final location = decoded['location'];

      if (location is Map) {

        final lat = double.tryParse(location['latitude']?.toString() ?? '');

        final lng = double.tryParse(location['longitude']?.toString() ?? '');

        if (lat != null && lng != null) {

          _serverDriverPosition = LatLng(lat, lng);

        }

      }

      final current = _currentPosition;

      final currentMap = _serverDriverPosition

          ?? (current != null ? LatLng(current.latitude, current.longitude) : null);

      final rideStatus = ride is Map ? ride['status']?.toString() : null;
      if (rideStatus != null && mounted) {
        final previousStatus = status;

        if (rideStatus != status) {
          setState(() {
            status = rideStatus;
          });
        }

        // O passageiro pode cancelar a corrida enquanto o motorista
        // está nesta tela. O track.php já devolve o status atual da
        // corrida, então usamos essa mesma consulta para detectar o
        // cancelamento em tempo real.
        if (rideStatus == 'cancelled' &&
            previousStatus != 'cancelled' &&
            !_remoteCancellationHandled) {
          await _handleRemoteCancellation();
          return;
        }
      }

      final target = (status == 'driver_found' ||

              status == 'driver_arriving' ||

              status == 'driver_arrived')

          ? _originPosition

          : _destinationPosition;

      if (currentMap != null && target != null) {

        final now = DateTime.now();

        if (_lastRouteAt == null || now.difference(_lastRouteAt!).inSeconds >= 8) {

          _lastRouteAt = now;

        final from = currentMap;

        final url = Uri.parse(

          'https://router.project-osrm.org/route/v1/driving/'

          '${from.longitude},${from.latitude};'

          '${target.longitude},${target.latitude}'

          '?overview=full&geometries=geojson',

        );

        final routeResponse = await http.get(url);

        if (routeResponse.statusCode == 200) {

          final data = jsonDecode(routeResponse.body);

          final routes = data is Map ? data['routes'] : null;

          final geometry = routes is List && routes.isNotEmpty ? routes.first['geometry'] : null;

          final coords = geometry is Map ? geometry['coordinates'] : null;

          final points = <LatLng>[];

          if (coords is List) {

            for (final c in coords) {

              if (c is List && c.length >= 2) {

                final lng = double.tryParse(c[0].toString());

                final lat = double.tryParse(c[1].toString());

                if (lat != null && lng != null) points.add(LatLng(lat, lng));

              }

            }

          }

          if (points.length >= 2) _routePoints = points;

        }

        }

      }

      if (mounted) {

        setState(() {});

        final followPosition = _serverDriverPosition

            ?? (_currentPosition != null

                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)

                : null);

        if (followPosition != null) {

          WidgetsBinding.instance.addPostFrameCallback((_) {

            if (!mounted) return;

            try {

              _mapController.move(

                followPosition,

                15.5,

              );

            } catch (_) {}

          });

        }

      }

    } catch (_) {

      // Falhas transitórias não encerram a corrida.

    } finally {

      _loadingTrack = false;

    }

  }

  // ============================================================

  // ============================================================
  // MONITORAR STATUS REAL DA CORRIDA
  // ============================================================

  void _startRideStatusPolling() {
    _rideStatusTimer?.cancel();

    // Consulta imediatamente e depois a cada 2 segundos.
    _checkRideStatusFromServer();

    _rideStatusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkRideStatusFromServer(),
    );
  }

Future<void> _checkRideStatusFromServer() async {
  if (!mounted ||
      _checkingRideStatus ||
      _remoteCancellationHandled ||
      _driverId == null ||
      status == 'completed' ||
      status == 'cancelled') {
    return;
  }

  _checkingRideStatus = true;

  try {
    final uri = Uri.parse(
      '$baseUrl/rides/status_for_driver.php',
    ).replace(
      queryParameters: {
        'ride_id': widget.rideId.toString(),
        'driver_id': _driverId.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
      },
    );

    if (!mounted || _remoteCancellationHandled) {
      return;
    }

    if (response.statusCode != 200) {
      debugPrint(
        'Status da corrida: HTTP ${response.statusCode} - ${response.body}',
      );
      return;
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      debugPrint(
        'Status da corrida: JSON inválido: ${response.body}',
      );
      return;
    }

    if (decoded is! Map) {
      debugPrint(
        'Status da corrida: resposta inválida: $decoded',
      );
      return;
    }

    if (decoded['success'] != true) {
      debugPrint(
        'Status da corrida: API retornou erro: $decoded',
      );
      return;
    }

    // ============================================================
    // O status vem dentro de "ride"
    // ============================================================

    final ride = decoded['ride'];

    String serverStatus = '';

    if (ride is Map) {
      serverStatus =
          ride['status']?.toString().trim() ?? '';
    }

    // Compatibilidade caso alguma versão da API retorne
    // "status" diretamente na raiz.
    if (serverStatus.isEmpty) {
      serverStatus =
          decoded['status']?.toString().trim() ?? '';
    }

    if (serverStatus.isEmpty) {
      debugPrint(
        'Status da corrida: nenhum status encontrado na resposta.',
      );
      return;
    }

    debugPrint(
      'MotoGo - corrida #${widget.rideId} - '
      'status atual: $serverStatus',
    );

    // ============================================================
    // CANCELAMENTO PELO PASSAGEIRO
    // ============================================================

    if (serverStatus == 'cancelled') {
      await _handleRemoteCancellation();
      return;
    }

    // ============================================================
    // ATUALIZAR STATUS NORMAL
    // ============================================================

    if (serverStatus != status && mounted) {
      setState(() {
        status = serverStatus;
      });

      // Notifica o motorista somente uma vez por mudança importante.
      if (_lastNotifiedStatus != serverStatus &&
          (serverStatus == 'driver_arrived' ||
              serverStatus == 'in_progress' ||
              serverStatus == 'completed' ||
              serverStatus == 'cancelled')) {
        _lastNotifiedStatus = serverStatus;

        String message;
        switch (serverStatus) {
          case 'driver_arrived':
            message = 'Você chegou ao local de embarque.';
            break;
          case 'in_progress':
            message = 'A corrida está em andamento.';
            break;
          case 'completed':
            message = 'Corrida finalizada. Seus ganhos foram atualizados.';
            break;
          case 'cancelled':
            message = 'A corrida foi cancelada.';
            break;
          default:
            message = 'O status da corrida foi atualizado.';
        }

        await NotificationService.showRideStatus(
          rideId: widget.rideId,
          status: statusText,
          message: message,
        );

        if (serverStatus == 'completed' && ride is Map) {
          final dynamic rawEarnings =
              ride['driver_earnings'] ??
              ride['driverEarnings'] ??
              ride['driver_amount'] ??
              ride['driverAmount'];
          final double amount =
              double.tryParse(rawEarnings?.toString() ?? '') ?? 0.0;

          if (amount > 0) {
            await NotificationService.showEarningsUpdate(
              rideId: widget.rideId,
              amount: amount,
              todayTotal: amount,
            );
          }
        }
      }
    }
  } catch (e) {
    debugPrint(
      'Erro ao consultar status da corrida: $e',
    );
  } finally {
    _checkingRideStatus = false;
  }
}

  // ATUALIZAR STATUS

  // ============================================================

  // ============================================================
  // CANCELAMENTO FEITO PELO PASSAGEIRO
  // ============================================================

  Future<void> _handleRemoteCancellation() async {
    if (_remoteCancellationHandled) return;
    _remoteCancellationHandled = true;

    _rideStatusTimer?.cancel();
    _rideStatusTimer = null;

    _trackTimer?.cancel();
    _trackTimer = null;

    _chatTimer?.cancel();
    _chatTimer = null;

    await _stopLocationTracking();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Corrida cancelada'),
          content: const Text(
            'O passageiro cancelou esta corrida.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    await ActiveRideStorage.clear();
    Navigator.pop(context, true);
  }

  Future<void> _updateStatus(

    String newStatus,

  ) async {

    if (processing) return;

    setState(() {

      processing = true;

    });

    try {

      // ========================================================

      // DRIVER ID

      // ========================================================

      int? driverId = _driverId;

      if (driverId == null) {

        final String? userId =

            await AuthService.getUserId();

        if (userId == null ||

            userId.trim().isEmpty) {

          throw Exception(

            'Motorista não identificado. '

            'Faça login novamente.',

          );

        }

        final Uri driverUrl = Uri.parse(

          '$baseUrl/drivers/by_user.php'

          '?user_id=${Uri.encodeQueryComponent(userId)}',

        );

        final http.Response driverResponse =

            await http.get(

          driverUrl,

          headers: const {

            'Accept': 'application/json',

          },

        );

        if (driverResponse.statusCode != 200) {

          throw Exception(

            'Não foi possível identificar o motorista.',

          );

        }

        dynamic driverDecoded =

            jsonDecode(driverResponse.body);

        if (driverDecoded

            is! Map<String, dynamic>) {

          throw Exception(

            'Resposta inválida do servidor.',

          );

        }

        if (driverDecoded['success'] != true) {

          throw Exception(

            driverDecoded['message']?.toString() ??

                'Motorista não encontrado.',

          );

        }

        final dynamic driverData =

            driverDecoded['driver'];

        if (driverData is! Map) {

          throw Exception(

            'Dados do motorista inválidos.',

          );

        }

        driverId =

            int.tryParse(

          driverData['id']?.toString() ?? '',

        );

        if (driverId == null ||

            driverId <= 0) {

          throw Exception(

            'ID do motorista não encontrado.',

          );

        }

        _driverId = driverId;

      }

      // ========================================================

      // ATUALIZAR STATUS

      // ========================================================

      final Uri url = Uri.parse(

        '$baseUrl/rides/update_status.php',

      );

      final http.Response response =

          await http.post(

        url,

        headers: const {

          'Content-Type':

              'application/json',

          'Accept':

              'application/json',

        },

        body: jsonEncode({

          'ride_id': widget.rideId,

          'driver_id': driverId,

          'status': newStatus,

        }),

      );

      if (response.statusCode != 200) {

        throw Exception(

          'Erro HTTP ${response.statusCode}.',

        );

      }

      dynamic decoded;

      try {

        decoded =

            jsonDecode(response.body);

      } catch (_) {

        throw Exception(

          'Resposta inválida da API.',

        );

      }

      if (decoded

          is! Map<String, dynamic>) {

        throw Exception(

          'Resposta inválida da API.',

        );

      }

      if (decoded['success'] != true) {

        throw Exception(

          decoded['message']?.toString() ??

              'Não foi possível atualizar a corrida.',

        );

      }

      // ========================================================

      // SUCESSO

      // ========================================================

      if (!mounted) return;

      setState(() {

        status = newStatus;

      });

      _showMessage(

        _successMessage(newStatus),

        success: true,

      );

      // ========================================================

      // CORRIDA FINALIZADA

      // ========================================================

      if (newStatus == 'completed' || newStatus == 'cancelled') {

        await _stopLocationTracking();

        await Future.delayed(

          const Duration(

            milliseconds: 500,

          ),

        );

        if (!mounted) return;

        if (newStatus == 'completed') {

          await Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) => DriverRatingScreen(

                rideId: widget.rideId,

                passengerName: widget.passengerName,

              ),

            ),

          );

        }

        if (!mounted) return;

        Navigator.pop(context, true);

      }

    } catch (e) {

      if (!mounted) return;

      _showMessage(

        e.toString().replaceFirst(

              'Exception: ',

              '',

            ),

      );

    } finally {

      if (!mounted) return;

      setState(() {

        processing = false;

      });

    }

  }

  // ============================================================

  // MENSAGEM DE SUCESSO

  // ============================================================

  String _successMessage(

    String newStatus,

  ) {

    switch (newStatus) {

      case 'driver_arriving':

        return 'Você está a caminho do passageiro.';

      case 'driver_arrived':

        return 'Você informou que chegou ao local.';

      case 'in_progress':

        return 'Corrida iniciada.';

      case 'completed':

        return 'Corrida finalizada com sucesso.';

      case 'cancelled':

        return 'Corrida cancelada. Você já pode receber outra corrida.';

      default:

        return 'Status atualizado.';

    }

  }

  Widget _buildDriverMap() {

    final center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_serverDriverPosition ??
            _originPosition ??
            const LatLng(-21.1107, -44.1752));

    final markers = <Marker>[];

    final driverMapPosition = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _serverDriverPosition;

    if (driverMapPosition != null) {

      markers.add(Marker(

        point: driverMapPosition,

        width: 52,

        height: 52,

        child: Container(

          decoration: BoxDecoration(

            color: AppColors.primary,

            shape: BoxShape.circle,

            border: Border.all(color: Colors.white, width: 3),

            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],

          ),

          child: const Icon(Icons.navigation, color: Colors.white),

        ),

      ));

    }

    if (_originPosition != null) {

      markers.add(Marker(

        point: _originPosition!,

        width: 38,

        height: 38,

        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 34),

      ));

    }

    if (_destinationPosition != null) {

      markers.add(Marker(

        point: _destinationPosition!,

        width: 38,

        height: 38,

        child: const Icon(Icons.location_pin, color: Colors.red, size: 34),

      ));

    }

    return ClipRRect(

      borderRadius: BorderRadius.circular(20),

      child: SizedBox(

        height: 260,

        child: FlutterMap(

          mapController: _mapController,

          options: MapOptions(initialCenter: center, initialZoom: 14.5),

          children: [

            TileLayer(

              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

              userAgentPackageName: 'com.example.motogo',

            ),

            if (_routePoints.length >= 2)

              PolylineLayer(

                polylines: [

                  Polyline(points: _routePoints, strokeWidth: 5, color: AppColors.primary),

                ],

              ),

            MarkerLayer(markers: markers),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // BOTÃO PRINCIPAL

  // ============================================================

  Widget _buildMainButton() {

    if (status == 'driver_found') {

      return _actionButton(

        label: 'Estou a caminho',

        icon: Icons.navigation,

        color: Colors.orange,

        onPressed: () {

          _updateStatus(

            'driver_arriving',

          );

        },

      );

    }

    if (status == 'driver_arriving') {

      return _actionButton(

        label: 'Cheguei ao local',

        icon: Icons.location_on,

        color: Colors.purple,

        onPressed: () {

          _updateStatus(

            'driver_arrived',

          );

        },

      );

    }

    if (status == 'driver_arrived') {

      return _actionButton(

        label: 'Iniciar corrida',

        icon: Icons.play_arrow,

        color: Colors.green,

        onPressed: () {

          _updateStatus(

            'in_progress',

          );

        },

      );

    }

    if (status == 'in_progress') {

      return Column(

        children: [

          _actionButton(

            label: 'Finalizar corrida',

            icon: Icons.flag,

            color: Colors.red,

            onPressed: () {

              _updateStatus(

                'completed',

              );

            },

          ),

          const SizedBox(height: 10),

          _buildCancelRideButton(),

        ],

      );

    }

    if (status == 'driver_found' ||

        status == 'driver_arriving' ||

        status == 'driver_arrived') {

      return Column(

        children: [

          _buildStatusActionButton(status),

          const SizedBox(height: 10),

          _buildCancelRideButton(),

        ],

      );

    }

    return const SizedBox.shrink();

  }

  Widget _buildStatusActionButton(String currentStatus) {

    if (currentStatus == 'driver_found') {

      return _actionButton(

        label: 'Estou a caminho',

        icon: Icons.navigation,

        color: Colors.orange,

        onPressed: () => _updateStatus('driver_arriving'),

      );

    }

    if (currentStatus == 'driver_arriving') {

      return _actionButton(

        label: 'Cheguei ao local',

        icon: Icons.location_on,

        color: Colors.purple,

        onPressed: () => _updateStatus('driver_arrived'),

      );

    }

    return _actionButton(

      label: 'Iniciar corrida',

      icon: Icons.play_arrow,

      color: Colors.green,

      onPressed: () => _updateStatus('in_progress'),

    );

  }

  Widget _buildCancelRideButton() {

    return SizedBox(

      width: double.infinity,

      height: 48,

      child: OutlinedButton.icon(

        onPressed: processing ? null : _confirmDriverCancellation,

        icon: const Icon(Icons.cancel_outlined, size: 20),

        label: const Text(

          'Cancelar corrida por problema',

          style: TextStyle(

            fontWeight: FontWeight.w600,

          ),

        ),

        style: OutlinedButton.styleFrom(

          foregroundColor: Colors.red,

          side: const BorderSide(color: Colors.red),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(14),

          ),

        ),

      ),

    );

  }

  Future<void> _confirmDriverCancellation() async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Cancelar corrida?'),

          content: const Text(

            'Use esta opção somente se houver um problema real ou se a corrida estiver travada. O motorista será liberado para receber outra corrida.',

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(dialogContext, false),

              child: const Text('Voltar'),

            ),

            FilledButton(

              style: FilledButton.styleFrom(

                backgroundColor: Colors.red,

              ),

              onPressed: () => Navigator.pop(dialogContext, true),

              child: const Text('Cancelar corrida'),

            ),

          ],

        );

      },

    );

    if (confirmed == true && mounted) {

      await _updateStatus('cancelled');

    }

  }

  // ============================================================

  // BOTÃO

  // ============================================================

  Widget _actionButton({

    required String label,

    required IconData icon,

    required Color color,

    required VoidCallback onPressed,

  }) {

    return SizedBox(

      width: double.infinity,

      height: 56,

      child: ElevatedButton.icon(

        onPressed:

            processing

                ? null

                : onPressed,

        icon: processing

            ? const SizedBox(

                width: 20,

                height: 20,

                child:

                    CircularProgressIndicator(

                  strokeWidth: 2,

                  color: Colors.white,

                ),

              )

            : Icon(icon),

        label: Text(

          processing

              ? 'Atualizando...'

              : label,

          style: const TextStyle(

            fontSize: 15,

            fontWeight:

                FontWeight.bold,

          ),

        ),

        style:

            ElevatedButton.styleFrom(

          backgroundColor: color,

          foregroundColor: Colors.white,

          elevation: 0,

          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(

              16,

            ),

          ),

        ),

      ),

    );

  }

  // ============================================================

  // MENSAGEM

  // ============================================================

  void _showMessage(

    String message, {

    bool success = false,

  }) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)

        .showSnackBar(

      SnackBar(

        content:

            Text(message),

        backgroundColor:

            success

                ? Colors.green

                : Colors.grey.shade900,

        behavior:

            SnackBarBehavior.floating,

      ),

    );

  }

  // ============================================================

  // DISPOSE

  // ============================================================

  @override

  void dispose() {
    _rideStatusTimer?.cancel();
    _chatTimer?.cancel();
    _trackTimer?.cancel();
    _gpsHeartbeatTimer?.cancel();
    _stopLocationTracking();
    super.dispose();
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override

  Widget build(

    BuildContext context,

  ) {

    return PopScope(
      canPop: status == 'completed' || status == 'cancelled',
      child: Scaffold(

      backgroundColor:

          AppColors.background,

      appBar: AppBar(

        backgroundColor:

            Colors.white,

        elevation: 0,

        automaticallyImplyLeading:

            false,

        title: const Text(

          'Corrida atual',

          style: TextStyle(

            color: Colors.black87,

            fontWeight:

                FontWeight.bold,

          ),

        ),

      ),

      body: SafeArea(

        child:

            SingleChildScrollView(

          padding:

              const EdgeInsets.all(

            20,

          ),

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

                _buildDriverMap(),

                const SizedBox(height: 16),

              // ==================================================

              // STATUS

              // ==================================================

              Container(

                width:

                    double.infinity,

                padding:

                    const EdgeInsets.all(

                  20,

                ),

                decoration:

                    BoxDecoration(

                  color:

                      statusColor

                          .withOpacity(.10),

                  borderRadius:

                      BorderRadius.circular(

                    20,

                  ),

                ),

                child: Column(

                  children: [

                    Container(

                      width: 58,

                      height: 58,

                      decoration:

                          BoxDecoration(

                        color:

                            statusColor

                                .withOpacity(.15),

                        shape:

                            BoxShape.circle,

                      ),

                      child: Icon(

                        Icons.two_wheeler,

                        color:

                            statusColor,

                        size: 30,

                      ),

                    ),

                    const SizedBox(

                      height: 12,

                    ),

                    Text(

                      statusText,

                      textAlign:

                          TextAlign.center,

                      style:

                          TextStyle(

                        color:

                            statusColor,

                        fontSize: 18,

                        fontWeight:

                            FontWeight.bold,

                      ),

                    ),

                    const SizedBox(

                      height: 5,

                    ),

                    Text(

                      'Corrida #${widget.rideId}',

                      style:

                          TextStyle(

                        color:

                            Colors.grey

                                .shade600,

                        fontSize: 12,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(

                height: 20,

              ),

              // ==================================================

              // GPS

              // ==================================================

              _sectionCard(

                title:

                    'Localização GPS',

                child: Row(

                  children: [

                    Container(

                      width: 48,

                      height: 48,

                      decoration:

                          BoxDecoration(

                        color:

                            Colors.green

                                .withOpacity(

                          .10,

                        ),

                        shape:

                            BoxShape.circle,

                      ),

                      child: Icon(

                        _locationStarted

                            ? Icons.gps_fixed

                            : Icons.gps_off,

                        color:

                            _locationStarted

                                ? Colors.green

                                : Colors.grey,

                        size: 24,

                      ),

                    ),

                    const SizedBox(

                      width: 12,

                    ),

                    Expanded(

                      child: Column(

                        crossAxisAlignment:

                            CrossAxisAlignment

                                .start,

                        children: [

                          Text(

                            _locationStarted

                                ? 'GPS ativo'

                                : 'GPS aguardando',

                            style:

                                const TextStyle(

                              fontSize: 15,

                              fontWeight:

                                  FontWeight.bold,

                            ),

                          ),

                          const SizedBox(

                            height: 4,

                          ),

                          Text(

                            _locationMessage,

                            maxLines: 2,

                            overflow:

                                TextOverflow

                                    .ellipsis,

                            style:

                                TextStyle(

                              color:

                                  Colors.grey

                                      .shade600,

                              fontSize: 11,

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(

                height: 15,

              ),

              // ==================================================

              // PASSAGEIRO

              // ==================================================

              _sectionCard(

                title:

                    'Passageiro',

                child: Row(

                  children: [

                    Container(

                      width: 48,

                      height: 48,

                      decoration:

                          BoxDecoration(

                        color:

                            AppColors.primary

                                .withOpacity(

                          .10,

                        ),

                        shape:

                            BoxShape.circle,

                      ),

                      child:

                          Icon(

                        Icons.person,

                        color:

                            AppColors.primary,

                      ),

                    ),

                    const SizedBox(

                      width: 12,

                    ),

                    Expanded(

                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        Text(widget.passengerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 4),

                        Text('${widget.passengerLevel} • ${widget.passengerPoints} pts', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),

                      ]),

                    ),

                  ],

                ),

              ),

              const SizedBox(

                height: 15,

              ),

              Card(

                child: ListTile(

                  leading: const Icon(Icons.chat_outlined),

                  title: const Text('Chat com passageiro'),

                  subtitle: const Text('Converse durante a corrida'),

                  trailing: const Icon(Icons.chevron_right),

                  onTap: () async {

                    final userId = int.tryParse(await AuthService.getUserId() ?? '');

                    if (!mounted || userId == null) return;

                    await Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(rideId: widget.rideId, userId: userId, driverName: widget.passengerName, isDriver: true)));

                  },

                ),

              ),

              const SizedBox(height: 12),

              // ==================================================

              // ROTA

              // ==================================================

              _sectionCard(

                title:

                    'Rota',

                child: Column(

                  children: [

                    _locationRow(

                      icon:

                          Icons

                              .radio_button_checked,

                      color:

                          Colors.blue,

                      title:

                          'Origem',

                      address:

                          widget.origin,

                    ),

                    Padding(

                      padding:

                          const EdgeInsets

                              .only(

                        left: 8,

                      ),

                      child:

                          Align(

                        alignment:

                            Alignment

                                .centerLeft,

                        child:

                            Container(

                          width: 1,

                          height: 28,

                          color:

                              Colors.grey

                                  .shade300,

                        ),

                      ),

                    ),

                    for (var i = 0; i < _rideStops.length; i++) ...[

                      Padding(

                        padding: const EdgeInsets.only(left: 8),

                        child: Align(

                          alignment: Alignment.centerLeft,

                          child: Container(width: 1, height: 28, color: Colors.grey.shade300),

                        ),

                      ),

                      _locationRow(

                        icon: Icons.flag,

                        color: Colors.orange,

                        title: 'Parada ${i + 1}',

                        address: _rideStops[i]['address']?.toString() ?? 'Parada ${i + 1}',

                      ),

                    ],

                    Padding(

                      padding: const EdgeInsets.only(left: 8),

                      child: Align(

                        alignment: Alignment.centerLeft,

                        child: Container(width: 1, height: 28, color: Colors.grey.shade300),

                      ),

                    ),

                    _locationRow(

                      icon:

                          Icons.location_on,

                      color:

                          Colors.red,

                      title:

                          'Destino',

                      address:

                          widget.destination,

                    ),

                  ],

                ),

              ),

              const SizedBox(

                height: 15,

              ),

              // ==================================================

              // DETALHES

              // ==================================================

              _sectionCard(

                title:

                    'Detalhes da corrida',

                child: Row(

                  children: [

                    Expanded(

                      child:

                          _detailItem(

                        icon:

                            widget.rideType == 'viagem'

                                ? Icons.directions_car_filled

                                : Icons.two_wheeler,

                        label:

                            'Tipo',

                        value:

                            widget.rideType ==

                                    'mototaxi'

                                ? 'Mototáxi'

                                : widget.rideType ==

                                        'viagem'

                                    ? 'Viagem'

                                    : widget.rideType,

                      ),

                    ),

                    Expanded(

                      child:

                          _detailItem(

                        icon:

                            Icons.route,

                        label:

                            'Distância',

                        value:

                            '${widget.distanceKm.toStringAsFixed(1)} km',

                      ),

                    ),

                    Expanded(

                      child:

                          _detailItem(

                        icon:

                            Icons

                                .payments_outlined,

                        label:

                            'Valor',

                        value:

                            'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}',

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(

                height: 25,

              ),

              // ==================================================

              // BOTÃO

              // ==================================================

              _buildMainButton(),

              const SizedBox(

                height: 20,

              ),

              if (status !=

                      'completed' &&

                  status !=

                      'in_progress')

                Center(

                  child: Text(

                    'Atualize o status conforme a corrida avançar.',

                    textAlign:

                        TextAlign.center,

                    style:

                        TextStyle(

                      color:

                          Colors.grey

                              .shade600,

                      fontSize: 12,

                    ),

                  ),

                ),

            ],

          ),

        ),

      ),

      ),
    );

  }

  // ============================================================

  // SECTION CARD

  // ============================================================

  Widget _sectionCard({

    required String title,

    required Widget child,

  }) {

    return Container(

      width:

          double.infinity,

      padding:

          const EdgeInsets.all(

        18,

      ),

      decoration:

          BoxDecoration(

        color:

            Colors.white,

        borderRadius:

            BorderRadius.circular(

          20,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Text(

            title,

            style:

                const TextStyle(

              fontSize: 15,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

          const SizedBox(

            height: 15,

          ),

          child,

        ],

      ),

    );

  }

  // ============================================================

  // LOCALIZAÇÃO

  // ============================================================

  Widget _locationRow({

    required IconData icon,

    required Color color,

    required String title,

    required String address,

  }) {

    return Row(

      crossAxisAlignment:

          CrossAxisAlignment.start,

      children: [

        Icon(

          icon,

          color: color,

          size: 20,

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

                title,

                style:

                    TextStyle(

                  color:

                      Colors.grey

                          .shade500,

                  fontSize: 11,

                ),

              ),

              const SizedBox(

                height: 3,

              ),

              Text(

                address,

                style:

                    const TextStyle(

                  fontSize: 13,

                  height: 1.3,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

  // ============================================================

  // DETALHE

  // ============================================================

  Widget _detailItem({

    required IconData icon,

    required String label,

    required String value,

  }) {

    return Column(

      children: [

        Icon(

          icon,

          color:

              AppColors.primary,

          size: 22,

        ),

        const SizedBox(

          height: 7,

        ),

        Text(

          label,

          style:

              TextStyle(

            color:

                Colors.grey.shade500,

            fontSize: 10,

          ),

        ),

        const SizedBox(

          height: 3,

        ),

        Text(

          value,

          textAlign:

              TextAlign.center,

          style:

              const TextStyle(

            fontSize: 12,

            fontWeight:

                FontWeight.bold,

          ),

        ),

      ],

    );

  }

}