import '../../../config/api_config.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../config/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../client/ride/ride_chat_screen.dart';
import '../../../services/notification_service.dart';
import '../../../services/active_ride_storage.dart';
import 'driver_active_ride_screen.dart';

class DriverRideRequestScreen extends StatefulWidget {
  // ============================================================
  // DADOS DA CORRIDA
  // ============================================================

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

  // ============================================================
  // CONSTRUTOR
  // ============================================================

  const DriverRideRequestScreen({
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
  State<DriverRideRequestScreen> createState() =>
      _DriverRideRequestScreenState();
}

class _DriverRideRequestScreenState
    extends State<DriverRideRequestScreen> {

  // ============================================================
  // API
  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================
  // ESTADO
  // ============================================================

  bool processing = false;

  // Paradas da corrida, mantidas no estado para exibição ao motorista.
  List<Map<String, dynamic>> activeStops = [];

  @override
  void initState() {
    super.initState();
    activeStops = widget.stops
        .map((stop) => Map<String, dynamic>.from(stop))
        .toList();
  }

  // ============================================================
  // SERVIÇO
  // ============================================================

  String get serviceName {
    switch (widget.rideType) {
      case 'carro':
        return 'Carro';

      case 'delivery':
        return 'Delivery';

      case 'delivery_moto':
        return 'Delivery Moto';

      case 'delivery_bicicleta':
        return 'Bike Express';

      case 'delivery_pedestre':
        return 'Entrega a pé';

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

  Widget _buildStopsCard() {
    if (widget.stops.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.alt_route, color: Colors.orange), SizedBox(width: 8), Text('Paradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.stops.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 15, backgroundColor: Colors.orange, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              title: Text(widget.stops[i]['address']?.toString() ?? 'Parada ${i + 1}'),
            ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.stopIncomingRide(rideId: widget.rideId);
    super.dispose();
  }

  // ============================================================
  // ACEITAR CORRIDA
  // ============================================================

  Future<void> _acceptRide() async {
    if (processing) return;

    await NotificationService.stopIncomingRide(rideId: widget.rideId);

    setState(() {
      processing = true;
    });

    try {
      // ----------------------------------------------------------
      // 1. USUÁRIO LOGADO
      // ----------------------------------------------------------
      final String? userId = await AuthService.getUserId();

      if (userId == null || userId.trim().isEmpty) {
        throw Exception(
          'Motorista não identificado. Faça login novamente.',
        );
      }

      // ----------------------------------------------------------
      // 2. DESCOBRIR DRIVER_ID
      // ----------------------------------------------------------
      final Uri driverUrl = Uri.parse(
        '$baseUrl/drivers/by_user.php?user_id=${Uri.encodeQueryComponent(userId)}',
      );

      final http.Response driverResponse = await http.get(
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

      final dynamic driverDecoded = jsonDecode(driverResponse.body);

      if (driverDecoded is! Map<String, dynamic>) {
        throw Exception('Resposta inválida do servidor.');
      }

      if (driverDecoded['success'] != true) {
        throw Exception(
          driverDecoded['message']?.toString() ??
              'Motorista não encontrado.',
        );
      }

      final dynamic driverData = driverDecoded['driver'];

      if (driverData is! Map) {
        throw Exception('Dados do motorista inválidos.');
      }

      final int? driverId = int.tryParse(
        driverData['id']?.toString() ?? '',
      );

      if (driverId == null || driverId <= 0) {
        throw Exception('ID do motorista não encontrado.');
      }

      // ----------------------------------------------------------
      // 3. ACEITAR A CORRIDA
      // ----------------------------------------------------------
      final Uri acceptUrl = Uri.parse(
        '$baseUrl/rides/accept.php',
      );

      final http.Response response = await http.post(
        acceptUrl,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'ride_id': widget.rideId,
          'driver_id': driverId,
        }),
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'Resposta inválida da API: ${response.body}',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Resposta inválida da API.');
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Não foi possível aceitar a corrida.',
        );
      }

      // ----------------------------------------------------------
      // 4. CORRIDA ACEITA
      //
      // NÃO voltamos para a Home.
      // A tela atual é substituída imediatamente pela
      // tela da corrida ativa.
      // ----------------------------------------------------------
      if (!mounted) return;

      final dynamic apiRide = decoded['ride'];

      int activeRideId = widget.rideId;
      String activePassengerName = widget.passengerName;
      String activeRideType = widget.rideType;
      String activeOrigin = widget.origin;
      String activeDestination = widget.destination;
      double activeDistanceKm = widget.distanceKm;
      double activeRidePrice = widget.ridePrice;

      // Se o accept.php devolver os dados da corrida,
      // usamos os dados do servidor.
      if (apiRide is Map) {
        final int? returnedRideId = int.tryParse(
          apiRide['id']?.toString() ?? '',
        );

        if (returnedRideId != null && returnedRideId > 0) {
          activeRideId = returnedRideId;
        }

        final String? returnedPassenger =
            apiRide['passenger_name']?.toString();

        if (returnedPassenger != null &&
            returnedPassenger.trim().isNotEmpty) {
          activePassengerName = returnedPassenger;
        }

        final String? returnedRideType =
            apiRide['ride_type']?.toString();

        if (returnedRideType != null &&
            returnedRideType.trim().isNotEmpty) {
          activeRideType = returnedRideType;
        }

        final String? returnedOrigin =
            apiRide['origin_address']?.toString();

        if (returnedOrigin != null &&
            returnedOrigin.trim().isNotEmpty) {
          activeOrigin = returnedOrigin;
        }

        final String? returnedDestination =
            apiRide['destination_address']?.toString();

        if (returnedDestination != null &&
            returnedDestination.trim().isNotEmpty) {
          activeDestination = returnedDestination;
        }

        final double? returnedDistance =
            double.tryParse(
          apiRide['distance_km']?.toString() ?? '',
        );

        if (returnedDistance != null) {
          activeDistanceKm = returnedDistance;
        }

        final double? returnedFare =
            double.tryParse(
          apiRide['total_fare']?.toString() ?? '',
        );

        if (returnedFare != null) {
          activeRidePrice = returnedFare;
        }
        final rawStops = apiRide['stops'];
        if (rawStops is List) {
          activeStops = rawStops.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      await ActiveRideStorage.save(
        rideId: activeRideId,
        passengerName: activePassengerName,
        rideType: activeRideType,
        origin: activeOrigin,
        destination: activeDestination,
        distanceKm: activeDistanceKm,
        ridePrice: activeRidePrice,
        stops: activeStops,
        passengerPoints: widget.passengerPoints,
        passengerLevel: widget.passengerLevel,
      );

      setState(() {
        processing = false;
      });

      // ----------------------------------------------------------
      // 5. ABRIR A CORRIDA ATIVA
      // ----------------------------------------------------------
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DriverActiveRideScreen(
            rideId: activeRideId,
            passengerName: activePassengerName,
            rideType: activeRideType,
            origin: activeOrigin,
            destination: activeDestination,
            distanceKm: activeDistanceKm,
            ridePrice: activeRidePrice,
            stops: activeStops,
            passengerPoints: widget.passengerPoints,
            passengerLevel: widget.passengerLevel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }
    }
  }

  // ============================================================
  // RECUSAR
  // ============================================================

  Future<void> _rejectRide() async {
  if (processing) return;

  await NotificationService.stopIncomingRide(rideId: widget.rideId);

  setState(() {
    processing = true;
  });

  try {
    // ========================================================
    // PEGAR USER ID DO LOGIN
    // ========================================================

    final String? userId =
        await AuthService.getUserId();

    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        processing = false;
      });

      _showMessage(
        'Motorista não identificado. Faça login novamente.',
      );

      return;
    }

    // ========================================================
    // DESCOBRIR DRIVER ID
    // ========================================================

    final Uri driverUrl = Uri.parse(
      '$baseUrl/drivers/by_user.php?user_id=$userId',
    );

    final http.Response driverResponse =
        await http.get(
      driverUrl,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (driverResponse.statusCode != 200) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          'Não foi possível identificar o motorista.',
        );
      }

      return;
    }

    final dynamic driverDecoded =
        jsonDecode(driverResponse.body);

    if (driverDecoded
        is! Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          'Resposta inválida do servidor.',
        );
      }

      return;
    }

    if (driverDecoded['success'] != true) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          driverDecoded['message']?.toString() ??
              'Motorista não encontrado.',
        );
      }

      return;
    }

    final dynamic driver =
        driverDecoded['driver'];

    if (driver is! Map) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          'Dados do motorista inválidos.',
        );
      }

      return;
    }

    final int? driverId =
        int.tryParse(
      driver['id'].toString(),
    );

    if (driverId == null || driverId <= 0) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          'ID do motorista não encontrado.',
        );
      }

      return;
    }

    // ========================================================
    // REGISTRAR RECUSA NA API
    // ========================================================

    final Uri rejectUrl = Uri.parse(
      '$baseUrl/rides/reject.php',
    );

    final http.Response response =
        await http.post(
      rejectUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'ride_id': widget.rideId,
        'driver_id': driverId,
      }),
    );

    // ========================================================
    // DECODIFICAR
    // ========================================================

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded
        is! Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          'Resposta inválida da API.',
        );
      }

      return;
    }

    // ========================================================
    // ERRO
    // ========================================================

    if (decoded['success'] != true) {
      if (mounted) {
        setState(() {
          processing = false;
        });

        _showMessage(
          decoded['message']?.toString() ??
              'Não foi possível recusar a corrida.',
        );
      }

      return;
    }

    // ========================================================
    // SUCESSO
    // ========================================================

    if (!mounted) return;

    setState(() {
      processing = false;
    });

    _showMessage(
      'Corrida recusada.',
      success: true,
    );

    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      false,
    );

  } catch (e) {

    debugPrint(
      'Erro ao recusar corrida: $e',
    );

    if (!mounted) return;

    setState(() {
      processing = false;
    });

    _showMessage(
      'Não foi possível conectar à API.',
    );
  }
}

  // ============================================================
  // FORMATAÇÃO
  // ============================================================

  String get formattedPrice {
    return 'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get formattedDistance {
    return '${widget.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: !processing,

      child: Scaffold(
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
            'Nova solicitação',
          ),
        ),

        body: SafeArea(
          child: SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),

            padding:
                const EdgeInsets.fromLTRB(
              20,
              5,
              20,
              30,
            ),

            child: Column(
              children: [

                // ==================================================
                // AVISO
                // ==================================================

                _buildRequestHeader(),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // PASSAGEIRO
                // ==================================================

                _buildPassengerCard(),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // ROTA
                // ==================================================

                _buildRouteCard(),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // VALOR
                // ==================================================

                _buildPriceCard(),

                const SizedBox(
                  height: 18,
                ),

                // ==================================================
                // INFORMAÇÕES
                // ==================================================

                _buildRideInfo(),

                const SizedBox(
                  height: 25,
                ),

                // ==================================================
                // ACEITAR
                // ==================================================

                SizedBox(
                  width:
                      double.infinity,

                  height: 58,

                  child:
                      ElevatedButton(
                    onPressed:
                        processing
                            ? null
                            : _acceptRide,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.green,

                      foregroundColor:
                          Colors.white,

                      elevation: 0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),

                    child:
                        processing
                            ? const SizedBox(
                                width: 25,
                                height: 25,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,

                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'Aceitar corrida',

                                style:
                                    TextStyle(
                                  fontSize:
                                      17,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // RECUSAR
                // ==================================================

                SizedBox(
                  width:
                      double.infinity,

                  height: 54,

                  child:
                      OutlinedButton(
                    onPressed:
                        processing
                            ? null
                            : _rejectRide,

                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          Colors.red,

                      side:
                          const BorderSide(
                        color:
                            Colors.red,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),

                    child:
                        const Text(
                      'Recusar',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                Text(
                  'Confira os dados da corrida antes de aceitar.',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        Colors.grey.shade600,

                    fontSize: 11.5,
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
  // HEADER
  // ============================================================

  Widget _buildRequestHeader() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            AppColors.primary
                .withOpacity(.08),

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors.primary
                  .withOpacity(.12),
        ),
      ),

      child: Row(
        children: [

          Container(
            width: 55,
            height: 55,

            decoration:
                BoxDecoration(
              color:
                  AppColors.primary,

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                Icon(
              serviceIcon,

              color:
                  Colors.white,

              size: 29,
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

                const Text(
                  'Nova corrida disponível',

                  style:
                      TextStyle(
                    fontSize: 17,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  serviceName,

                  style:
                      TextStyle(
                    color:
                        Colors.grey.shade700,

                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.green
                      .withOpacity(.10),

              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),

            child:
                const Text(
              'NOVO',

              style:
                  TextStyle(
                color:
                    Colors.green,

                fontSize:
                    10,

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASSAGEIRO
  // ============================================================

  Widget _buildPassengerCard() {
    return _card(
      child: Row(
        children: [

          Container(
            width: 54,
            height: 54,

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

                const Text(
                  'Passageiro',

                  style:
                      TextStyle(
                    color:
                        Colors.grey,

                    fontSize:
                        12,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  widget.passengerName,

                  style:
                      const TextStyle(
                    fontSize:
                        17,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: Text('${widget.passengerLevel} • ${widget.passengerPoints} pts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),

          const Row(
            children: [

              Icon(
                Icons.star,

                color:
                    Colors.amber,

                size: 18,
              ),

              SizedBox(
                width: 4,
              ),

              Text(
                '5.0',

                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROTA
  // ============================================================

  Widget _buildRouteCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Text(
            'Rota',

            style:
                TextStyle(
              fontSize:
                  17,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          _locationRow(
            icon:
                Icons.radio_button_checked,

            color:
                Colors.blue,

            title:
                'Origem',

            address:
                widget.origin,
          ),

          Padding(
            padding:
                const EdgeInsets.only(
              left: 11,
            ),

            child:
                Container(
              width: 2,
              height: 25,

              color:
                  Colors.grey.shade300,
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

          color:
              color,

          size: 24,
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
                    const TextStyle(
                  color:
                      Colors.grey,

                  fontSize:
                      11,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                address,

                maxLines:
                    2,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize:
                      14,

                  fontWeight:
                      FontWeight.w500,

                  height:
                      1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PREÇO
  // ============================================================

  Widget _buildPriceCard() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color:
            Colors.green
                .withOpacity(.07),

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              Colors.green
                  .withOpacity(.15),
        ),
      ),

      child: Row(
        children: [

          Container(
            width: 50,
            height: 50,

            decoration:
                BoxDecoration(
              color:
                  Colors.green
                      .withOpacity(.12),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child:
                const Icon(
              Icons
                  .account_balance_wallet_outlined,

              color:
                  Colors.green,

              size: 27,
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

                const Text(
                  'Valor da corrida',

                  style:
                      TextStyle(
                    color:
                        Colors.grey,

                    fontSize:
                        12,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  formattedPrice,

                  style:
                      const TextStyle(
                    fontSize:
                        23,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Text(
            formattedDistance,

            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,

              fontSize:
                  14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES
  // ============================================================

  Widget _buildRideInfo() {
    return _card(
      child: Column(
        children: [

          _infoRow(
            Icons.two_wheeler,
            'Serviço',
            serviceName,
          ),

          const Divider(
            height: 24,
          ),

          _infoRow(
            Icons.straighten,
            'Distância',
            formattedDistance,
          ),

          const Divider(
            height: 24,
          ),

          _infoRow(
            Icons.payments_outlined,
            'Pagamento',
            formattedPrice,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [

        Icon(
          icon,

          color:
              AppColors.primary,

          size: 21,
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Text(
            title,

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize:
                  13,
            ),
          ),
        ),

        Text(
          value,

          style:
              const TextStyle(
            fontSize:
                13,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,

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
                    .withOpacity(.035),

            blurRadius:
                10,

            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child:
          child,
    );
  }
}