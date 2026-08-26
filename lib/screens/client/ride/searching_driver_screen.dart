import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import 'driver_found_screen.dart';

class SearchingDriverScreen extends StatefulWidget {
  final int rideId;
  final String rideType;
  final double ridePrice;

  const SearchingDriverScreen({
    super.key,
    required this.rideId,
    required this.rideType,
    required this.ridePrice,
  });

  @override
  State<SearchingDriverScreen> createState() =>
      _SearchingDriverScreenState();
}

class _SearchingDriverScreenState
    extends State<SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _statusTimer;

  int searchSeconds = 0;

  late AnimationController _animationController;

  bool openingDriver = false;
  bool checkingStatus = false;

  int? _userId;

  String _currentStatus = 'pending';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startCounter();
    _startPolling();
  }

  // ============================================================
  // CONTADOR
  // ============================================================

  void _startCounter() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || openingDriver) return;

        setState(() {
          searchSeconds++;
        });
      },
    );
  }

  // ============================================================
  // POLLING DO STATUS
  // ============================================================

  Future<void> _startPolling() async {
    final userIdString = await AuthService.getUserId();

    if (!mounted) return;

    final userId = int.tryParse(
      userIdString ?? '',
    );

    if (userId == null || userId <= 0) {
      _showMessage(
        'Sua sessão não foi encontrada. Faça login novamente.',
      );
      return;
    }

    _userId = userId;

    // Primeira consulta imediatamente.
    await _checkRideStatus();

    if (!mounted || openingDriver) {
      return;
    }

    // Depois continua verificando a cada 2 segundos.
    _statusTimer?.cancel();

    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _checkRideStatus();
      },
    );
  }

  // ============================================================
  // CONSULTAR STATUS DA CORRIDA
  // ============================================================

  Future<void> _checkRideStatus() async {
    if (!mounted ||
        openingDriver ||
        checkingStatus ||
        _userId == null) {
      return;
    }

    checkingStatus = true;

    try {
      final result = await ApiService.getRideStatus(
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

      final status = ride['status']?.toString() ?? '';

      if (status.isEmpty) {
        return;
      }

      _currentStatus = status;

      // ========================================================
      // MOTORISTA ENCONTRADO
      // ========================================================

    if (status == 'driver_found' ||
    status == 'driver_arriving' ||
    status == 'driver_arrived' ||
    status == 'in_progress') {
  _openDriverFound(ride);
  return;
}

      // ========================================================
      // CORRIDA CONCLUÍDA
      // ========================================================
if (status == 'completed') {
  _statusTimer?.cancel();
  _timer?.cancel();
  _animationController.stop();

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
          'A corrida foi concluída com sucesso.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'OK',
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

  return;
}

      // ========================================================
      // CORRIDA CANCELADA
      // ========================================================

      if (status == 'cancelled') {
        _statusTimer?.cancel();
        _timer?.cancel();
        _animationController.stop();

        if (!mounted) return;

        _showMessage(
          'A corrida foi cancelada.',
        );

        await Future.delayed(
          const Duration(milliseconds: 800),
        );

        if (!mounted) return;

        Navigator.pop(context);
      }
    } catch (e) {
      // Não derruba a tela se uma consulta falhar.
      debugPrint(
        'Erro ao consultar status da corrida: $e',
      );
    } finally {
      checkingStatus = false;
    }
  }

  // ============================================================
  // ABRIR TELA DO MOTORISTA
  // ============================================================

void _openDriverFound(Map ride) {
  if (!mounted || openingDriver) {
    return;
  }

  openingDriver = true;

  _timer?.cancel();
  _statusTimer?.cancel();
  _animationController.stop();

  final driver = ride['driver'];

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => DriverFoundScreen(
        rideId: widget.rideId,
        rideType: widget.rideType,
        ridePrice: widget.ridePrice,

        driverData:
            driver is Map
                ? Map<String, dynamic>.from(driver)
                : null,
              
              vehicleData:
    ride['vehicle'] is Map
        ? Map<String, dynamic>.from(
            ride['vehicle'],
          )
        : null,
      ),
    ),
  );
}

  // ============================================================
  // CANCELAR CORRIDA
  // ============================================================

  Future<void> _cancelRide() async {
    if (openingDriver || _userId == null) return;

    _timer?.cancel();
    _statusTimer?.cancel();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancelar corrida?',
          ),
          content: const Text(
            'Tem certeza que deseja cancelar esta solicitação?',
          ),
          actions: [
            TextButton(
              onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Continuar esperando'),
            ),
            TextButton(
              onPressed: () {
              Navigator.pop(dialogContext, true);
            },
              child: const Text(
                'Cancelar corrida',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      if (mounted) {
        _startCounter();
        _startPolling();
      }
      return;
    }

    final result = await ApiService.cancelRide(
      rideId: widget.rideId,
      userId: _userId!,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      _showMessage(
        result['message']?.toString() ??
            'Não foi possível cancelar a corrida.',
      );
      _startCounter();
      _startPolling();
      return;
    }

    Navigator.pop(context);
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();
    _statusTimer?.cancel();
    _animationController.dispose();

    super.dispose();
  }

  // ============================================================
  // NOME DO SERVIÇO
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
  // TEMPO FORMATADO
  // ============================================================

  String get formattedTime {
    final minutes = searchSeconds ~/ 60;
    final seconds = searchSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  String get _searchAudience {
    switch (widget.rideType) {
      case 'carro':
        return 'Buscando motoristas disponíveis na sua região';
      case 'delivery_pedestre':
        return 'Buscando entregadores disponíveis na sua região';
      case 'delivery_bicicleta':
        return 'Buscando entregadores disponíveis na sua região';
      case 'delivery':
      case 'delivery_moto':
        return 'Buscando motoboys disponíveis na sua região';
      default:
        return 'Buscando motoristas disponíveis na sua região';
    }
  }

  String get _waitingMessage {
    switch (widget.rideType) {
      case 'delivery_pedestre':
        return 'Fique tranquilo, vamos te conectar com o melhor entregador!';
      default:
        return 'Fique tranquilo, vamos te conectar com o melhor motorista!';
    }
  }

  String get _cancelLabel {
    return widget.rideType.startsWith('delivery_') ||
            widget.rideType == 'delivery'
        ? 'Cancelar entrega'
        : 'Cancelar corrida';
  }

  Widget _searchInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 720;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Procurando motorista'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              isCompact ? 4 : 10,
              18,
              24,
            ),
            child: Column(
              children: [
                _buildSearchingAnimation(),

                SizedBox(height: isCompact ? 8 : 14),

                const Text(
                  'Procurando motorista',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Estamos procurando um motorista disponível '
                  'próximo de você.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 17,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _searchInfoRow(
                        Icons.sync,
                        _searchAudience,
                      ),
                      _searchInfoRow(
                        Icons.autorenew,
                        'Isso pode levar alguns segundos',
                      ),
                      _searchInfoRow(
                        Icons.notifications_active_outlined,
                        'Você será avisado quando encontrarmos alguém',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _waitingMessage,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _buildRideSummary(),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: openingDriver ? null : _cancelRide,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _cancelLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
  // ANIMAÇÃO
  // ============================================================

  Widget _buildSearchingAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value =
            _animationController.value;

        return SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale:
                    0.65 +
                    (value * .35),
                child: Container(
                  width: 175,
                  height: 175,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary
                        .withOpacity(.04),
                  ),
                ),
              ),

              Transform.scale(
                scale:
                    0.55 +
                    (value * .30),
                child: Container(
                  width: 135,
                  height: 135,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary
                        .withOpacity(.08),
                  ),
                ),
              ),

              Container(
                width: 92,
                height: 92,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withOpacity(.30),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  serviceIcon,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // RESUMO DA CORRIDA
  // ============================================================

  Widget _buildRideSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  AppColors.primary
                      .withOpacity(.10),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              serviceIcon,
              color:
                  AppColors.primary,
              size: 25,
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
                  serviceName,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  _statusDescription,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              const Text(
                'Estimativa',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                'R\$ '
                '${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}',
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXTO DO STATUS
  // ============================================================

  String get _statusDescription {
    switch (_currentStatus) {
      case 'driver_found':
        return 'Motorista encontrado';

      case 'driver_arriving':
        return 'Motorista está a caminho';

      case 'driver_arrived':
        return 'Motorista chegou';

      case 'in_progress':
        return 'Corrida em andamento';

      case 'completed':
        return 'Corrida finalizada';

      case 'cancelled':
        return 'Corrida cancelada';

      default:
        return 'Aguardando motorista';
    }
  }
}