import '../../../config/api_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../../config/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../services/driver_service.dart';
import '../../../services/location_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/active_ride_storage.dart';
import '../../auth/login_screen.dart';
import '../rides/driver_ride_request_screen.dart';
import '../rides/driver_active_ride_screen.dart';
import '../vehicle/vehicle_screen.dart';
import '../finance/driver_finance_screen.dart';
import '../profile/driver_profile_edit_screen.dart';
import '../profile/driver_settings_screen.dart';
import '../profile/driver_performance_screen.dart';
import 'widgets/driver_ranking_card.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() =>
      _DriverHomeScreenState();
}

class _DriverHomeScreenState
    extends State<DriverHomeScreen> with WidgetsBindingObserver {

  // ============================================================
  // API
  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================
  // ESTADO
  // ============================================================

  bool isOnline = false;

  bool isLoadingDriver = true;

  bool isCheckingRide = false;

  int currentIndex = 0;

  int? driverId;

  int? userId;

  String driverName = 'Motorista';

  String driverType = 'moto';

  Timer? rideTimer;
  Timer? _statsTimer;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _gpsHeartbeatTimer;
  bool _gpsStarted = false;
  bool _sendingGps = false;

  // Evita tocar/mostrar a mesma corrida várias vezes enquanto o
  // endpoint ainda estiver retornando a solicitação pendente.
  int? lastNotifiedRideId;

  // ============================================================
  // HISTÓRICO DE CORRIDAS
  // ============================================================

  List<Map<String, dynamic>> driverRides = [];

  bool isLoadingRides = false;

  // ============================================================
  // DADOS
  // ============================================================

  double todayEarnings = 0.00;

  int todayRides = 0;

  double rating = 5.0;

  // ============================================================
  // AVISOS DO MOTORISTA
  // ============================================================

  bool alertsLoading = true;
  bool _restoringActiveRide = false;
  bool hasPendingInvoice = false;
  bool hasOverdueInvoice = false;
  int pendingInvoiceCount = 0;
  String vehicleStatus = 'none';
  bool hasVehicle = false;
  bool vehicleRequired = true;


Future<void> _registerDriverFcmToken() async {
  if (driverId == null || driverId! <= 0) {
    return;
  }

  try {
    final messaging = FirebaseMessaging.instance;

    // Solicita permissão para receber notificações.
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final String? token = await messaging.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('MotoGo FCM: token não disponível.');
      return;
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/drivers/fcm_token.php',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'driver_id': driverId,
        'fcm_token': token,
      }),
    );

    debugPrint(
      'MotoGo FCM: HTTP ${response.statusCode} - ${response.body}',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is Map &&
          data['success'] == true) {
        debugPrint(
          'MotoGo FCM: token salvo com sucesso.',
        );
      }
    }

    // O Firebase pode trocar o token.
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        if (driverId == null ||
            driverId! <= 0 ||
            newToken.isEmpty) {
          return;
        }

        try {
          final refreshResponse = await http.post(
            Uri.parse(
              '$baseUrl/drivers/fcm_token.php',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'driver_id': driverId,
              'fcm_token': newToken,
            }),
          );

          debugPrint(
            'MotoGo FCM refresh: '
            '${refreshResponse.statusCode}',
          );
        } catch (e) {
          debugPrint(
            'MotoGo FCM refresh erro: $e',
          );
        }
      },
    );
  } catch (e) {
    debugPrint(
      'MotoGo FCM erro ao registrar token: $e',
    );
  }
}

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    NotificationService.initialize();
    _initializeDriver();
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && driverId != null) _loadDriverRides();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDriverAlerts();
      _restoreActiveRideIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    rideTimer?.cancel();
    _statsTimer?.cancel();
    _stopGpsTracking();

    super.dispose();
  }

  // ============================================================
  // INICIALIZAR MOTORISTA
  // ============================================================

  Future<void> _initializeDriver() async {
    try {
      // ============================================================
      // PEGAR USER ID SALVO NO LOGIN
      // ============================================================

      final String? savedUserId =
          await AuthService.getUserId();

      if (savedUserId == null ||
          savedUserId.isEmpty) {

        if (!mounted) return;

        setState(() {
          isLoadingDriver = false;
        });

        _showMessage(
          'Usuário não identificado. Faça login novamente.',
        );

        return;
      }

      userId = int.tryParse(savedUserId);

      if (userId == null) {

        if (!mounted) return;

        setState(() {
          isLoadingDriver = false;
        });

        _showMessage(
          'ID do usuário inválido: $savedUserId',
        );

        return;
      }

      // ============================================================
      // BUSCAR MOTORISTA PELO USER_ID
      // ============================================================

      final Uri url = Uri.parse(
        '$baseUrl/drivers/by_user.php'
        '?user_id=$userId',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      // ============================================================
      // VERIFICAR HTTP
      // ============================================================

      if (response.statusCode != 200) {
        throw Exception(
          'Erro HTTP ${response.statusCode} ao buscar motorista.',
        );
      }

      // ============================================================
      // DECODIFICAR JSON
      // ============================================================

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'A API de motorista retornou JSON inválido.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Resposta da API de motorista inválida.',
        );
      }

      // ============================================================
      // VERIFICAR SUCCESS
      // ============================================================

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Motorista não encontrado.',
        );
      }

      // ============================================================
      // PEGAR MOTORISTA
      // ============================================================

      dynamic driverData = decoded['driver'];

      if (driverData == null) {
        driverData = decoded['data'];
      }

      if (driverData == null &&
          decoded['id'] != null) {
        driverData = decoded;
      }

      if (driverData is! Map) {
        throw Exception(
          'A API respondeu sucesso, mas não retornou os dados do motorista.',
        );
      }

      // ============================================================
      // DRIVER ID
      // ============================================================

      final dynamic rawDriverId =
          driverData['id'] ??
              driverData['driver_id'];

      final int? loadedDriverId =
          int.tryParse(
        rawDriverId?.toString() ?? '',
      );

      if (loadedDriverId == null ||
          loadedDriverId <= 0) {
        throw Exception(
          'ID do motorista não encontrado na resposta da API.',
        );
      }

      // ============================================================
      // STATUS ONLINE
      // ============================================================

      final bool loadedOnline =
          driverData['online'] == true ||
              driverData['online'].toString() == '1';

      // ============================================================
      // TIPO
      // ============================================================

      final String loadedType =
          driverData['driver_type']?.toString() ??
              'moto';

      // ============================================================
      // NOME
      // ============================================================

      final String loadedName =
          driverData['name']?.toString() ??
              'Motorista';

      // ============================================================
      // ATUALIZAR ESTADO
      // ============================================================

            if (!mounted) return;

      setState(() {
        driverId = loadedDriverId;
        driverType = loadedType;
        driverName = loadedName;
        isOnline = loadedOnline;
        isLoadingDriver = false;
      });

      // ============================================================
      // REGISTRAR TOKEN FCM
      // ============================================================

      await _registerDriverFcmToken();
    

      // ============================================================
      // CARREGAR HISTÓRICO E AVISOS
      // ============================================================

      await _loadDriverRides();
      await _loadDriverAlerts();
      await _restoreActiveRideIfNeeded();

      // ============================================================
      // SE JÁ ESTIVER ONLINE
      // COMEÇAR A PROCURAR CORRIDAS
      // ============================================================

      if (isOnline) {
        _startRidePolling();
        _startGpsTracking();
      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        isLoadingDriver = false;
        driverId = null;
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
  // RECUPERAR CORRIDA ATIVA
  // ============================================================
  //
  // A corrida ativa fica salva localmente para que minimizar, fechar
  // e reabrir o aplicativo não faça a tela da corrida desaparecer.
  // O status verdadeiro continua vindo do servidor.
  // ============================================================

  Future<void> _restoreActiveRideIfNeeded() async {
    if (!mounted || driverId == null || _restoringActiveRide) return;

    final saved = await ActiveRideStorage.load();
    if (saved == null) return;

    final rideId = int.tryParse(saved['rideId']?.toString() ?? '');
    if (rideId == null || rideId <= 0) {
      await ActiveRideStorage.clear();
      return;
    }

    _restoringActiveRide = true;

    try {
      final result = await ApiService.getRideStatusForDriver(
        rideId: rideId,
        driverId: driverId!,
      );

      if (result['success'] != true) {
        return;
      }

      final ride = result['ride'];
      final status = ride is Map
          ? ride['status']?.toString() ?? ''
          : '';

      const activeStatuses = {
        'driver_found',
        'driver_arriving',
        'driver_arrived',
        'in_progress',
      };

      if (!activeStatuses.contains(status)) {
        await ActiveRideStorage.clear();
        return;
      }

      if (!mounted) return;

      _stopRidePolling();

      final map = ride is Map
          ? Map<String, dynamic>.from(ride)
          : <String, dynamic>{};

      final passengerName =
          map['passenger_name']?.toString() ??
          saved['passengerName']?.toString() ??
          'Passageiro';

      final rideType =
          map['ride_type']?.toString() ??
          saved['rideType']?.toString() ??
          'mototaxi';

      final origin =
          map['origin_address']?.toString() ??
          saved['origin']?.toString() ??
          'Origem';

      final destination =
          map['destination_address']?.toString() ??
          saved['destination']?.toString() ??
          'Destino';

      final distanceKm =
          double.tryParse(
                map['distance_km']?.toString() ??
                    saved['distanceKm']?.toString() ??
                    '0',
              ) ??
              0.0;

      final ridePrice =
          double.tryParse(
                map['total_fare']?.toString() ??
                    saved['ridePrice']?.toString() ??
                    '0',
              ) ??
              0.0;

      final stops = map['stops'] is List
          ? (map['stops'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : (saved['stops'] is List
              ? (saved['stops'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[]);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverActiveRideScreen(
            rideId: rideId,
            passengerName: passengerName,
            rideType: rideType,
            origin: origin,
            destination: destination,
            distanceKm: distanceKm,
            ridePrice: ridePrice,
            stops: stops,
            passengerPoints:
                int.tryParse(saved['passengerPoints']?.toString() ?? '0') ?? 0,
            passengerLevel:
                saved['passengerLevel']?.toString() ?? 'Bronze',
          ),
        ),
      );
    } finally {
      _restoringActiveRide = false;
    }
  }

  // ============================================================
  // CARREGAR AVISOS FINANCEIROS E VEÍCULO
  // ============================================================

  Future<void> _loadDriverAlerts() async {
    if (driverId == null) return;

    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '$baseUrl/drivers/finance.php?driver_id=$driverId',
          ),
          headers: const {'Accept': 'application/json'},
        ),
        http.get(
          Uri.parse(
            '$baseUrl/drivers/vehicle.php?driver_id=$driverId',
          ),
          headers: const {'Accept': 'application/json'},
        ),
      ]);

      bool pending = false;
      bool overdue = false;
      int pendingCount = 0;
      bool loadedHasVehicle = false;
      String loadedVehicleStatus = 'none';

      final financeResponse = results[0];
      if (financeResponse.statusCode >= 200 &&
          financeResponse.statusCode < 300) {
        final dynamic data = jsonDecode(financeResponse.body);
        if (data is Map<String, dynamic>) {
          final dynamic current = data['current_invoice'];
          final dynamic summary = data['summary'];

          if (current is Map) {
            final String status =
                current['status']?.toString().toLowerCase() ?? '';
            if (status == 'open' ||
                status == 'pending' ||
                status == 'overdue') {
              pending = true;
            }
            if (status == 'overdue') {
              overdue = true;
            }
          }

          if (summary is Map) {
            overdue = overdue || summary['has_overdue'] == true;
            final dynamic totalOpen = summary['total_open'];
            final double openAmount =
                double.tryParse(totalOpen?.toString() ?? '0') ?? 0;
            pending = pending || openAmount > 0 || overdue;
          }

          final dynamic invoices = data['invoices'];
          if (invoices is List) {
            pendingCount = invoices.where((item) {
              if (item is! Map) return false;
              final String status =
                  item['status']?.toString().toLowerCase() ?? '';
              return status == 'open' ||
                  status == 'pending' ||
                  status == 'overdue';
            }).length;
          }
        }
      }

      final vehicleResponse = results[1];
      if (vehicleResponse.statusCode >= 200 &&
          vehicleResponse.statusCode < 300) {
        final dynamic data = jsonDecode(vehicleResponse.body);
        if (data is Map<String, dynamic>) {
          loadedHasVehicle = data['has_vehicle'] == true;
          final dynamic vehicle = data['vehicle'];
          if (vehicle is Map) {
            loadedVehicleStatus =
                vehicle['status']?.toString().toLowerCase() ?? 'pending';
          }
        }
      }

      final String type = driverType.toLowerCase();
      final bool isBike =
          type == 'bicicleta' ||
          type == 'bike' ||
          type == 'delivery_bike';
      final bool isPedestrian =
          type == 'delivery_pedestre' ||
          type == 'pedestre';

      if (!mounted) return;
      setState(() {
        alertsLoading = false;
        hasPendingInvoice = pending;
        hasOverdueInvoice = overdue;
        if (overdue) {
          isOnline = false;
          _stopRidePolling();
        }
        pendingInvoiceCount = pendingCount;
        hasVehicle = loadedHasVehicle;
        vehicleStatus = loadedVehicleStatus;
        vehicleRequired = !isBike && !isPedestrian;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        alertsLoading = false;
      });
    }
  }

  // ============================================================
  // ALERTA FINANCEIRO
  // ============================================================

  Widget _buildFinanceNotice() {
    if (alertsLoading) {
      return _buildNoticeCard(
        icon: Icons.receipt_long_outlined,
        title: 'Verificando seu financeiro...',
        message: 'Estamos consultando suas faturas.',
        color: Colors.blue,
        onTap: null,
      );
    }

    if (hasPendingInvoice) {
      return _buildNoticeCard(
        icon: hasOverdueInvoice
            ? Icons.warning_amber_rounded
            : Icons.receipt_long_outlined,
        title: hasOverdueInvoice
            ? 'Você possui fatura vencida'
            : 'Você possui fatura pendente',
        message: hasOverdueInvoice
            ? 'Você precisa regularizar sua fatura para voltar a receber corridas.'
            : '${pendingInvoiceCount > 0 ? pendingInvoiceCount : 1} fatura(s) aguardando pagamento. Mantenha seu financeiro em dia.',
        color: hasOverdueInvoice ? Colors.red : Colors.orange,
        onTap: () {
          if (driverId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverFinanceScreen(driverId: driverId!),
            ),
          ).then((_) => _loadDriverAlerts());
        },
        actionLabel: 'Ver faturas',
      );
    }

    return _buildNoticeCard(
      icon: Icons.check_circle_outline,
      title: 'Tudo certo no financeiro',
      message: 'Você não possui faturas pendentes no momento.',
      color: Colors.green,
      onTap: () {
        if (driverId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverFinanceScreen(driverId: driverId!),
          ),
        );
      },
      actionLabel: 'Ver financeiro',
    );
  }

  // ============================================================
  // ALERTA DE VEÍCULO
  // ============================================================

  Widget _buildVehicleNotice() {
    if (!vehicleRequired) {
      final isPedestrian =
          driverType.toLowerCase() == 'delivery_pedestre' ||
          driverType.toLowerCase() == 'pedestre';
      return _buildNoticeCard(
        icon: isPedestrian
            ? Icons.directions_walk
            : Icons.pedal_bike_outlined,
        title: isPedestrian
            ? 'Entrega a pé pronta para trabalhar'
            : 'Bike pronta para trabalhar',
        message: isPedestrian
            ? 'Para entregas a pé, não é necessário cadastrar veículo.'
            : 'Para entregas de bicicleta, não é necessário cadastrar veículo.',
        color: Colors.green,
        onTap: null,
      );
    }

    if (!hasVehicle) {
      return _buildNoticeCard(
        icon: Icons.directions_car_outlined,
        title: 'Cadastre seu veículo',
        message: 'Para receber corridas, cadastre seu veículo e aguarde a aprovação.',
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverVehicleScreen(),
            ),
          ).then((_) => _loadDriverAlerts());
        },
        actionLabel: 'Cadastrar veículo',
      );
    }

    if (vehicleStatus == 'approved') {
      return _buildNoticeCard(
        icon: Icons.verified_outlined,
        title: 'Veículo aprovado',
        message: 'Seu veículo está aprovado e pronto para receber corridas.',
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverVehicleScreen(),
            ),
          );
        },
        actionLabel: 'Ver veículo',
      );
    }

    if (vehicleStatus == 'rejected') {
      return _buildNoticeCard(
        icon: Icons.error_outline,
        title: 'Veículo não aprovado',
        message: 'Revise os dados do veículo e faça a correção necessária.',
        color: Colors.red,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverVehicleScreen(),
            ),
          ).then((_) => _loadDriverAlerts());
        },
        actionLabel: 'Ver veículo',
      );
    }

    return _buildNoticeCard(
      icon: Icons.hourglass_top_outlined,
      title: 'Veículo em análise',
      message: 'Seu cadastro foi enviado e está aguardando aprovação.',
      color: Colors.orange,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverVehicleScreen(),
          ),
        );
      },
      actionLabel: 'Ver veículo',
    );
  }

  // ============================================================
  // CENTRAL DE AJUDA
  // ============================================================

  void _showHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final topics = <Map<String, dynamic>>[
          {
            'icon': Icons.two_wheeler_outlined,
            'title': 'Como receber uma corrida',
            'text': 'Fique online, mantenha seu cadastro aprovado e aguarde uma solicitação.',
          },
          {
            'icon': Icons.location_on_outlined,
            'title': 'Problemas com GPS',
            'text': 'Verifique a permissão de localização e mantenha o GPS do aparelho ativo.',
          },
          {
            'icon': Icons.account_balance_wallet_outlined,
            'title': 'Ganhos e comissões',
            'text': 'Consulte seus ganhos, comissões e faturas na área Meus ganhos.',
          },
          {
            'icon': Icons.receipt_long_outlined,
            'title': 'Faturas e pagamentos',
            'text': 'Envie o comprovante pelo financeiro e acompanhe a confirmação do pagamento.',
          },
          {
            'icon': Icons.directions_car_outlined,
            'title': 'Cadastro do veículo',
            'text': 'Cadastre o veículo e aguarde a aprovação antes de receber corridas que exigem veículo.',
          },
          {
            'icon': Icons.cancel_outlined,
            'title': 'Cancelamento de corrida',
            'text': 'Se precisar cancelar, use o botão de cancelamento na tela da corrida.',
          },
          {
            'icon': Icons.star_outline,
            'title': 'Avaliações',
            'text': 'As avaliações das corridas concluídas aparecem no seu perfil.',
          },
        ];

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Central de ajuda',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Encontre orientações rápidas para trabalhar no MotoGo.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  ...topics.map(
                    (topic) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(topic['icon'] as IconData, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic['title'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topic['text'].toString(),
                                  style: TextStyle(color: Colors.grey.shade600, height: 1.35),
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
                        Icon(Icons.support_agent_outlined, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ainda precisa de ajuda? Entre em contato com o suporte do MotoGo.',
                            style: TextStyle(fontWeight: FontWeight.w600),
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

  // ============================================================
  // CARD DE AVISO
  // ============================================================

  Widget _buildNoticeCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    required VoidCallback? onTap,
    String? actionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.35),
                ),
                if (onTap != null && actionLabel != null) ...[
                  const SizedBox(height: 9),
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        actionLabel,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GPS DO MOTORISTA ONLINE
  // ============================================================

  Future<void> _startGpsTracking() async {
    if (_gpsStarted || driverId == null || !isOnline) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showMessage('Ative o GPS para ficar disponível no mapa.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Permita o acesso à localização para receber corridas.');
      return;
    }

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
      await _sendOnlineGps(first);
    } catch (_) {}

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) {
      _sendOnlineGps(position);
    });

    _gpsHeartbeatTimer?.cancel();
    _gpsHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) async {
        if (!isOnline || driverId == null) return;
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await _sendOnlineGps(position);
        } catch (_) {}
      },
    );

    _gpsStarted = true;
  }

  Future<void> _sendOnlineGps(Position position) async {
    if (!_gpsStarted && driverId == null) return;
    if (driverId == null || !isOnline || _sendingGps) return;

    _sendingGps = true;
    try {
      await DriverService.updateLocation(
        driverId: driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Falha temporária não deve tirar o motorista do online.
    } finally {
      _sendingGps = false;
    }
  }

  Future<void> _stopGpsTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsHeartbeatTimer?.cancel();
    _gpsHeartbeatTimer = null;
    _gpsStarted = false;
  }

  // ============================================================
  // INICIAR BUSCA DE CORRIDAS
  // ============================================================

  void _startRidePolling() {
    rideTimer?.cancel();

    // Verifica imediatamente.
    _checkPendingRide();

    // Depois verifica a cada 5 segundos.
    rideTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _checkPendingRide();
      },
    );
  }

  // ============================================================
  // PARAR BUSCA
  // ============================================================

  void _stopRidePolling() {
    rideTimer?.cancel();

    rideTimer = null;
  }

  // ============================================================
  // BUSCAR CORRIDA PENDENTE
  // ============================================================

  Future<void> _checkPendingRide() async {
    if (!isOnline) return;

    if (driverId == null) return;

    if (isCheckingRide) return;

    isCheckingRide = true;

    try {
      final Uri url = Uri.parse(
        '$baseUrl/rides/pending_for_driver.php'
        '?driver_id=$driverId',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (decoded['success'] != true) {
        return;
      }

      if (decoded['blocked'] == true) {
        if (mounted) {
          setState(() {
            isOnline = false;
            hasPendingInvoice = true;
            hasOverdueInvoice = true;
            pendingInvoiceCount =
                pendingInvoiceCount > 0 ? pendingInvoiceCount : 1;
          });
          _stopRidePolling();
          _showMessage(
            decoded['message']?.toString() ??
                'Sua conta está bloqueada por fatura vencida.',
          );
        }
        return;
      }

      if (decoded['has_ride'] != true) {
        return;
      }

      final dynamic ride =
          decoded['ride'];

      final dynamic passenger =
          decoded['passenger'];

      if (ride is! Map) return;

      if (passenger is! Map) return;

      // ============================================================
      // DADOS DA CORRIDA
      // ============================================================

      final int? rideId =
          int.tryParse(
        ride['id'].toString(),
      );

      if (rideId == null) {
        return;
      }

      final String passengerName =
          passenger['name']
                  ?.toString() ??
              'Passageiro';

      final int passengerPoints = int.tryParse(ride['passenger_points']?.toString() ?? '0') ?? 0;
      final String passengerLevel = ride['passenger_level']?.toString() ?? 'Bronze';

      final String rideType =
          ride['ride_type']
                  ?.toString() ??
              'mototaxi';

      final String origin =
          ride['origin_address']
                  ?.toString() ??
              'Origem';

      final String destination =
          ride['destination_address']
                  ?.toString() ??
              'Destino';

      final double distanceKm =
          double.tryParse(
                ride['distance_km']
                    .toString(),
              ) ??
              0.0;

      final double ridePrice =
          double.tryParse(
                ride['total_fare']
                    .toString(),
              ) ??
              0.0;

      final List<Map<String, dynamic>> rideStops = ride['stops'] is List
          ? (ride['stops'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      // ============================================================
      // NOVA CORRIDA -> ALERTA REAL + SOM
      // ============================================================

      if (lastNotifiedRideId != rideId) {
        lastNotifiedRideId = rideId;

        await NotificationService.showIncomingRide(
          rideId: rideId,
          passengerName: passengerName,
          rideType: rideType,
          price: ridePrice,
          origin: origin,
          destination: destination,
        );
      }

      // ============================================================
      // PARAR POLLING ENQUANTO MOSTRA A CORRIDA
      // ============================================================

      _stopRidePolling();

      if (!mounted) return;

      // ============================================================
      // ABRIR SOLICITAÇÃO
      // ============================================================

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DriverRideRequestScreen(
            rideId: rideId,
            passengerName:
                passengerName,
            rideType:
                rideType,
            origin:
                origin,
            destination:
                destination,
            distanceKm:
                distanceKm,
            ridePrice:
                ridePrice,
            stops:
                rideStops,
            passengerPoints:
                passengerPoints,
            passengerLevel:
                passengerLevel,
          ),
        ),
      );

      // ============================================================
      // VOLTOU DA TELA
      // ============================================================

      if (!mounted) return;

      // Recarregar histórico.
      await _loadDriverRides();

      // Verifica novamente se continua online.
      await _refreshDriverStatus();

      if (isOnline) {
        _startRidePolling();
        _startGpsTracking();
      }

    } catch (e) {

      // Não mostrar erro a cada polling.
      // Apenas continuar tentando.

    } finally {

      isCheckingRide = false;
    }
  }

  // ============================================================
  // ATUALIZAR STATUS DO MOTORISTA
  // ============================================================

  Future<void> _refreshDriverStatus() async {
    if (userId == null) return;

    try {
      final Uri url = Uri.parse(
        '$baseUrl/drivers/by_user.php'
        '?user_id=$userId',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (decoded['success'] != true) {
        return;
      }

      final dynamic driver =
          decoded['driver'];

      if (driver is! Map) {
        return;
      }

      if (!mounted) return;

      setState(() {
        isOnline =
            driver['online'] == true ||
                driver['online'].toString() == '1';

        driverType =
            driver['driver_type']
                    ?.toString() ??
                driverType;
      });

    } catch (_) {
      // Ignorar falha temporária.
    }
  }

  // ============================================================
  // ONLINE / OFFLINE
  // ============================================================

  Future<void> _toggleOnline() async {
    if (driverId == null) {
      _showMessage(
        'Motorista ainda não foi carregado.',
      );

      return;
    }

    final bool newStatus = !isOnline;

    if (isCheckingRide) return;

    setState(() {
      isCheckingRide = true;
    });

    try {
      // When going online the driver has just interacted with the page.
      // Use that gesture to request browser notification permission and
      // unlock audio before the first incoming ride arrives.
      if (newStatus) {
        await NotificationService.prepareForUserInteraction();
      }

      final result =
          await DriverService.setOnlineStatus(
        online: newStatus,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        _showMessage(
          result['message']?.toString() ??
              'Não foi possível alterar seu status.',
        );

        return;
      }

      setState(() {
        isOnline = newStatus;
      });

      if (isOnline) {

        _showMessage(
          'Você está online e disponível para receber corridas.',
          success: true,
        );

        _startRidePolling();
        _startGpsTracking();

      } else {

        _stopRidePolling();
        _stopGpsTracking();

        _showMessage(
          'Você ficou offline.',
        );
      }

    } catch (e) {

      if (!mounted) return;

      _showMessage(
        'Não foi possível alterar seu status.',
      );

    } finally {

      if (!mounted) return;

      setState(() {
        isCheckingRide = false;
      });
    }
  }

  // ============================================================
  // CARREGAR CORRIDAS DO MOTORISTA
  // ============================================================

  Future<void> _loadDriverRides() async {
    if (driverId == null) return;

    if (isLoadingRides) return;

    if (mounted) {
      setState(() {
        isLoadingRides = true;
      });
    }

    try {
      final Uri url = Uri.parse(
        '$baseUrl/rides/driver_rides.php'
        '?driver_id=$driverId',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erro HTTP ${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Resposta inválida da API.',
        );
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Não foi possível carregar as corridas.',
        );
      }

      final dynamic data =
          decoded['rides'];

      if (data is List) {

        final List<Map<String, dynamic>>
            loadedRides =
            data
                .whereType<Map>()
                .map(
                  (ride) =>
                      Map<String, dynamic>.from(
                    ride,
                  ),
                )
                .toList();

        if (!mounted) return;

        setState(() {
          driverRides = loadedRides;

          // ======================================================
          // ATUALIZAR ESTATÍSTICAS
          // ======================================================

          final DateTime now = DateTime.now();
          final DateTime today = DateTime(now.year, now.month, now.day);

          bool isToday(Map<String, dynamic> ride) {
            final dynamic rawDate = ride['completed_at'] ?? ride['completedAt'] ?? ride['created_at'] ?? ride['createdAt'];
            if (rawDate == null) return false;
            final DateTime? date = DateTime.tryParse(rawDate.toString());
            if (date == null) return false;
            final DateTime localDate = date.toLocal();
            return localDate.year == today.year && localDate.month == today.month && localDate.day == today.day;
          }

          final completedToday = loadedRides.where((ride) =>
              ride['status']?.toString() == 'completed' && isToday(ride)).toList();

          todayRides = completedToday.length;
          todayEarnings = completedToday.fold<double>(0.0, (total, ride) {
            final dynamic value = ride['driver_earnings'] ?? ride['driverEarnings'] ?? ride['total_fare'] ?? ride['totalFare'];
            final double amount = double.tryParse(value?.toString() ?? '') ?? 0.0;
            return total + amount;
          });
        });

      } else {

        if (!mounted) return;

        setState(() {
          driverRides = [];
          todayRides = 0;
          todayEarnings = 0.0;
        });
      }

    } catch (e, stackTrace) {

  debugPrint('========================================');
  debugPrint('ERRO AO CARREGAR CORRIDAS');
  debugPrint('ERRO: $e');
  debugPrint('STACK: $stackTrace');
  debugPrint('========================================');

  // IMPORTANTE:
  // Não apagar as corridas que já estavam na tela.
  // Uma falha temporária da API não significa que
  // o motorista perdeu suas corridas.

} finally {
      if (!mounted) return;

      setState(() {
        isLoadingRides = false;
      });
    }
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
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            success
                ? Colors.green
                : Colors.grey.shade900,
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    _stopRidePolling();
    await _stopGpsTracking();
    await ActiveRideStorage.clear();
    await AuthService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    if (isLoadingDriver) {
      return Scaffold(
        backgroundColor:
            AppColors.background,

        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          AppColors.background,

      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,

          children: [
            _buildHome(),
            _buildRides(),
            _buildProfile(),
          ],
        ),
      ),

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            currentIndex,

        height: 72,

        backgroundColor:
            Colors.white,

        indicatorColor:
            AppColors.primary
                .withOpacity(.12),

        onDestinationSelected:
            (index) {

          setState(() {
            currentIndex = index;
          });

          // ======================================================
          // AO ABRIR CORRIDAS, RECARREGAR
          // ======================================================

          if (index == 1) {
            _loadDriverRides();
          }
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),

            selectedIcon: Icon(
              Icons.dashboard,
            ),

            label: 'Início',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.history_outlined,
            ),

            selectedIcon: Icon(
              Icons.history,
            ),

            label: 'Corridas',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),

            selectedIcon: Icon(
              Icons.person,
            ),

            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _buildHome() {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),

      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        30,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          _buildHeader(),

          const SizedBox(
            height: 25,
          ),

          _buildOnlineCard(),

          const SizedBox(
            height: 22,
          ),

          _buildEarningsCard(),

          const SizedBox(height: 14),

          const DriverRankingCard(),

          const SizedBox(height: 14),

          _buildFinanceNotice(),

          const SizedBox(height: 14),

          _buildVehicleNotice(),

          const SizedBox(
            height: 22,
          ),

          _buildStats(),

          const SizedBox(
            height: 25,
          ),

          const Text(
            'Solicitações',
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          _buildRequestArea(),

          const SizedBox(
            height: 25,
          ),

          _buildTips(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [

        Container(
          width: 52,
          height: 52,

          decoration:
              BoxDecoration(
            color: AppColors.primary
                .withOpacity(.12),

            shape:
                BoxShape.circle,
          ),

          child: Icon(
            Icons.person,

            color:
                AppColors.primary,

            size: 30,
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
                'Olá, $driverName 👋',

                style:
                    const TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                isOnline
                    ? 'Você está disponível'
                    : 'Você está offline',

                style: TextStyle(
                  color:
                      isOnline
                          ? Colors.green
                          : Colors.grey,

                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 44,
          height: 44,

          decoration:
              BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),

          child: IconButton(
            onPressed: _showHelpCenter,

            icon: const Icon(
              Icons.notifications_none,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD ONLINE
  // ============================================================

  Widget _buildOnlineCard() {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 250,
      ),

      width:
          double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color:
            isOnline
                ? AppColors.primary
                : Colors.white,

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        boxShadow: [
          if (!isOnline)
            BoxShadow(
              color: Colors.black
                  .withOpacity(.04),

              blurRadius: 12,

              offset:
                  const Offset(
                0,
                5,
              ),
            ),
        ],
      ),

      child: Column(
        children: [

          Row(
            children: [

              Container(
                width: 56,
                height: 56,

                decoration:
                    BoxDecoration(
                  color:
                      isOnline
                          ? Colors.white
                              .withOpacity(.18)
                          : AppColors.primary
                              .withOpacity(.10),

                  shape:
                      BoxShape.circle,
                ),

                child: Icon(
                  isOnline
                      ? Icons.wifi
                      : Icons.wifi_off,

                  color:
                      isOnline
                          ? Colors.white
                          : AppColors.primary,

                  size: 28,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      isOnline
                          ? 'Você está ONLINE'
                          : 'Você está OFFLINE',

                      style: TextStyle(
                        color:
                            isOnline
                                ? Colors.white
                                : Colors.black87,

                        fontSize: 18,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      isOnline
                          ? 'Aguardando novas corridas'
                          : 'Fique online para receber corridas',

                      style: TextStyle(
                        color:
                            isOnline
                                ? Colors.white
                                    .withOpacity(.85)
                                : Colors.grey.shade600,

                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width:
                double.infinity,

            height: 52,

            child:
                ElevatedButton(
              onPressed:
                  isCheckingRide
                      ? null
                      : _toggleOnline,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    isOnline
                        ? Colors.white
                        : AppColors.primary,

                foregroundColor:
                    isOnline
                        ? AppColors.primary
                        : Colors.white,

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),

              child:
                  isCheckingRide
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isOnline
                              ? 'Ficar offline'
                              : 'Ficar online',

                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GANHOS
  // ============================================================

  Widget _buildEarningsCard() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.04),

            blurRadius: 12,

            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(.10),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .account_balance_wallet_outlined,

                  color:
                      Colors.green,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Text(
                'Ganhos de hoje',

                style:
                    TextStyle(
                  fontSize: 14,
                  color:
                      Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            'R\$ ${todayEarnings.toStringAsFixed(2).replaceAll('.', ',')}',

            style:
                const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            '$todayRides corridas realizadas',

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ESTATÍSTICAS
  // ============================================================

  Widget _buildStats() {
    return Row(
      children: [

        Expanded(
          child:
              _statCard(
            icon:
                Icons.two_wheeler,

            title:
                'Corridas',

            value:
                '$todayRides',
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child:
              _statCard(
            icon:
                Icons.star_outline,

            title:
                'Avaliação',

            value:
                rating.toStringAsFixed(1),
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child:
              _statCard(
            icon:
                Icons.access_time,

            title:
                'Status',

            value:
                isOnline
                    ? 'Online'
                    : 'Offline',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Icon(
            icon,

            color:
                AppColors.primary,

            size: 22,
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            value,

            style:
                const TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            title,

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SOLICITAÇÕES
  // ============================================================

  Widget _buildRequestArea() {

    if (!isOnline) {
      return Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(24),

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
          children: [

            Icon(
              Icons
                  .notifications_off_outlined,

              size: 42,

              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Você está offline',

              style:
                  TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Fique online para começar a receber solicitações.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,

                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors.primary
                  .withOpacity(.15),
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
                  AppColors.primary
                      .withOpacity(.10),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .notifications_active_outlined,

              color:
                  AppColors.primary,

              size: 30,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'Você está disponível',

            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'O MotoGo está procurando novas corridas para você.',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 12.5,

              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              SizedBox(
                width: 18,
                height: 18,

                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,

                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Text(
                'Procurando corridas...',

                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,

                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DICAS
  // ============================================================

  Widget _buildTips() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color:
            Colors.blue.withOpacity(.06),

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Icon(
            Icons.lightbulb_outline,

            color:
                Colors.blue,

            size: 23,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  'Dica',

                  style:
                      TextStyle(
                    color:
                        Colors.blue.shade800,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Mantenha sua localização ativada para receber corridas próximas de você.',

                  style:
                      TextStyle(
                    color:
                        Colors.blue.shade800,

                    fontSize: 12,

                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CORRIDAS
  // ============================================================

  Widget _buildRides() {
    return RefreshIndicator(
      onRefresh:
          _loadDriverRides,

      child:
          SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            const Text(
              'Minhas corridas',

              style:
                  TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Histórico das suas corridas.',

              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            if (isLoadingRides)
              const Center(
                child:
                    Padding(
                  padding:
                      EdgeInsets.all(30),

                  child:
                      CircularProgressIndicator(),
                ),
              )

            else if (driverRides.isEmpty)
              _buildEmptyRides()

            else
              Column(
                children:
                    driverRides
                        .map(
                          (ride) =>
                              _buildRideHistoryCard(
                            ride,
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NENHUMA CORRIDA
  // ============================================================

  Widget _buildEmptyRides() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(30),

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
        children: [

          Icon(
            Icons.history,

            size: 50,

            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'Nenhuma corrida ainda',

            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Suas corridas aparecerão aqui.',

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DO HISTÓRICO
  // ============================================================

  Widget _buildRideHistoryCard(
    Map<String, dynamic> ride,
  ) {

    final String status =
        ride['status']?.toString() ??
            'unknown';

    final String origin =
        ride['origin_address']?.toString() ??
            ride['origin']?.toString() ??
            'Origem não informada';

    final String destination =
        ride['destination_address']?.toString() ??
            ride['destination']?.toString() ??
            'Destino não informado';

    final dynamic fareValue =
        ride['driver_earnings'] ??
            ride['driverEarnings'] ??
            ride['total_fare'] ??
            ride['totalFare'] ??
            0;

    final double fare =
        double.tryParse(
              fareValue.toString(),
            ) ??
            0.0;

    final String rideType =
        ride['ride_type']?.toString() ??
            ride['rideType']?.toString() ??
            'mototaxi';

    return Container(
      width:
          double.infinity,

      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(.03),

            blurRadius: 10,

            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Container(
                width: 44,
                height: 44,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary
                          .withOpacity(.10),

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child:
                    Icon(
                  Icons.two_wheeler,

                  color:
                      AppColors.primary,

                  size: 23,
                ),
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
                      rideType == 'mototaxi'
                          ? 'Mototáxi'
                          : rideType == 'viagem'
                              ? 'Viagem'
                              : rideType,

                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _formatRideStatus(
                        status,
                      ),

                      style:
                          TextStyle(
                        fontSize: 12,

                        color:
                            _rideStatusColor(
                          status,
                        ),

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'R\$ ${fare.toStringAsFixed(2).replaceAll('.', ',')}',

                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Column(
                children: [

                  Container(
                    width: 10,
                    height: 10,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.blue,

                      shape:
                          BoxShape.circle,
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 30,

                    color:
                        Colors.grey.shade300,
                  ),

                  Container(
                    width: 10,
                    height: 10,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.red,

                      shape:
                          BoxShape.circle,
                    ),
                  ),
                ],
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
                      origin,

                      maxLines: 2,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(
                      height: 19,
                    ),

                    Text(
                      destination,

                      maxLines: 2,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS DA CORRIDA
  // ============================================================

  String _formatRideStatus(
    String status,
  ) {

    switch (status) {

      case 'pending':
        return 'Pendente';

      case 'driver_found':
        return 'Motorista encontrado';

      case 'driver_arriving':
        return 'A caminho';

      case 'in_progress':
        return 'Em andamento';

      case 'completed':
        return 'Concluída';

      case 'cancelled':
        return 'Cancelada';

      case 'rejected':
        return 'Recusada';

      default:
        return status;
    }
  }

  // ============================================================
  // COR DA STATUS
  // ============================================================

  Color _rideStatusColor(
    String status,
  ) {

    switch (status) {

      case 'completed':
        return Colors.green;

      case 'cancelled':
      case 'rejected':
        return Colors.red;

      case 'in_progress':
        return Colors.blue;

      case 'driver_arriving':
      case 'driver_found':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // PERFIL
  // ============================================================

  Widget _buildProfile() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),

      child: Column(
        children: [

          const SizedBox(
            height: 15,
          ),

          Container(
            width: 82,
            height: 82,

            decoration:
                BoxDecoration(
              color:
                  AppColors.primary
                      .withOpacity(.12),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.person,

              color:
                  AppColors.primary,

              size: 45,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            driverName,

            style:
                const TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Motorista parceiro',

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _profileOption(
            icon:
                Icons.person_outline,

            title:
                'Meus dados',

            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverProfileEditScreen()));
            },
          ),
_profileOption(
  icon:
      Icons.directions_car_outlined,

  title:
      'Meu veículo',

  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DriverVehicleScreen(),
      ),
    );
  },
),
        
          _profileOption(
  icon:
      Icons.account_balance_wallet_outlined,

  title:
      'Meus ganhos',

  onTap: () {

    if (driverId == null) {

      _showMessage(
        'Motorista ainda não foi carregado.',
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DriverFinanceScreen(
          driverId: driverId!,
        ),
      ),
    );
  },
),

          _profileOption(
            icon: Icons.emoji_events_outlined,
            title: 'Meu desempenho',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPerformanceScreen()));
            },
          ),

          _profileOption(
            icon:
                Icons.settings_outlined,

            title:
                'Configurações',

            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSettingsScreen()));
            },
          ),

          const SizedBox(
            height: 10,
          ),

          _profileOption(
            icon:
                Icons.logout,

            title:
                'Sair',

            danger:
                true,

            onTap:
                _logout,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPÇÃO PERFIL
  // ============================================================

  Widget _profileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),

      child: ListTile(
        onTap:
            onTap,

        leading:
            Icon(
          icon,

          color:
              danger
                  ? Colors.red
                  : AppColors.primary,
        ),

        title:
            Text(
          title,

          style:
              TextStyle(
            color:
                danger
                    ? Colors.red
                    : Colors.black87,

            fontWeight:
                FontWeight.w500,
          ),
        ),

        trailing:
            const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}