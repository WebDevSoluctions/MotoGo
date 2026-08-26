import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/colors.dart';
import 'ride_rating_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideType;

  final String driverName;

  final String vehicle;

  final String plate;

  final double rating;

  // Valor real calculado pelo FareService
  final double ridePrice;

  const RideTrackingScreen({
    super.key,
    this.rideType = 'mototaxi',
    this.driverName = 'Motorista',
    this.vehicle = 'Veículo',
    this.plate = '---',
    this.rating = 4.9,
    this.ridePrice = 0.0,
  });

  @override
  State<RideTrackingScreen> createState() =>
      _RideTrackingScreenState();
}

class _RideTrackingScreenState
    extends State<RideTrackingScreen> {
  final MapController _mapController =
      MapController();

  Timer? _timer;

  int remainingMinutes = 3;

  bool driverArrived = false;

  bool rideStarted = false;

  bool rideFinished = false;

  // ============================================================
  // COORDENADAS TEMPORÁRIAS
  // ============================================================

  final LatLng passengerLocation =
      const LatLng(
    -21.1150,
    -44.2600,
  );

  final LatLng driverLocation =
      const LatLng(
    -21.1200,
    -44.2580,
  );

  @override
  void initState() {
    super.initState();

    _startSimulation();
  }

  // ============================================================
  // SIMULAÇÃO DO MOTORISTA
  // ============================================================

  void _startSimulation() {
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (!mounted) return;

        if (remainingMinutes > 1) {
          setState(() {
            remainingMinutes--;
          });

          return;
        }

        setState(() {
          remainingMinutes = 0;
          driverArrived = true;
        });

        timer.cancel();
      },
    );
  }

  // ============================================================
  // TIPO
  // ============================================================

  bool get isCar {
    return widget.rideType == 'carro';
  }

  String get serviceName {
    switch (widget.rideType) {
      case 'carro':
        return 'Carro';

      case 'delivery':
        return 'Moto Express';

      default:
        return 'Mototáxi';
    }
  }

  IconData get vehicleIcon {
    switch (widget.rideType) {
      case 'carro':
        return Icons.directions_car;

      case 'delivery':
        return Icons.two_wheeler;

      default:
        return Icons.two_wheeler;
    }
  }

  Color get serviceColor {
    switch (widget.rideType) {
      case 'carro':
        return Colors.indigo;

      case 'delivery':
        return Colors.blue;

      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // PREÇO FORMATADO
  // ============================================================

  String get formattedPrice {
    return 'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String get statusTitle {
    if (rideFinished) {
      return 'Corrida finalizada';
    }

    if (rideStarted) {
      return 'Corrida em andamento';
    }

    if (driverArrived) {
      return 'Motorista chegou';
    }

    return 'Motorista a caminho';
  }

  String get statusDescription {
    if (rideFinished) {
      return 'Obrigado por utilizar o MotoGo.';
    }

    if (rideStarted) {
      return 'Você está a caminho do destino.';
    }

    if (driverArrived) {
      return 'Seu motorista está esperando por você.';
    }

    if (remainingMinutes == 1) {
      return 'Chegando em aproximadamente 1 minuto.';
    }

    return 'Chegando em aproximadamente $remainingMinutes minutos.';
  }

  // ============================================================
  // INICIAR CORRIDA
  // ============================================================

  void _startRide() {
    setState(() {
      rideStarted = true;
      driverArrived = false;
    });
  }

  // ============================================================
  // FINALIZAR CORRIDA
  // ============================================================

  void _finishRide() {
    _timer?.cancel();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RideRatingScreen(
          rideType: widget.rideType,
          driverName: widget.driverName,
          vehicle: widget.vehicle,
          plate: widget.plate,

          // IMPORTANTE:
          // passa o valor real da corrida
          // para a tela de avaliação.
          ridePrice: widget.ridePrice,
        ),
      ),
    );
  }

  // ============================================================
  // CONTATO
  // ============================================================

  void _contactDriver() {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Contato com o motorista será integrado em breve.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CANCELAR
  // ============================================================

  void _cancelRide() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),

          title: const Text(
            'Cancelar corrida?',
          ),

          content: const Text(
            'Deseja realmente cancelar esta corrida?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Continuar',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                _timer?.cancel();

                Navigator.pop(
                  context,
                );
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
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      body: Stack(
        children: [
          // ======================================================
          // MAPA
          // ======================================================

          _buildMap(),

          // ======================================================
          // BOTÃO VOLTAR
          // ======================================================

          Positioned(
            top: 50,
            left: 18,

            child: _circleButton(
              icon: Icons.arrow_back,
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
            ),
          ),

          // ======================================================
          // CENTRALIZAR
          // ======================================================

          Positioned(
            top: 50,
            right: 18,

            child: _circleButton(
              icon: Icons.my_location,
              onPressed: () {
                _mapController.move(
                  passengerLocation,
                  15,
                );
              },
            ),
          ),

          // ======================================================
          // STATUS
          // ======================================================

          Positioned(
            top: 110,
            left: 18,
            right: 18,

            child:
                _buildStatusCard(),
          ),

          // ======================================================
          // PAINEL INFERIOR
          // ======================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,

            child:
                _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAPA
  // ============================================================

  Widget _buildMap() {
    return FlutterMap(
      mapController:
          _mapController,

      options: MapOptions(
        initialCenter:
            passengerLocation,

        initialZoom: 14.5,

        interactionOptions:
            const InteractionOptions(
          flags:
              InteractiveFlag.all,
        ),
      ),

      children: [
        // ========================================================
        // OPENSTREETMAP
        // ========================================================

        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

          userAgentPackageName:
              'com.motogo.app',
        ),

        // ========================================================
        // ROTA
        // ========================================================

        PolylineLayer(
          polylines: [
            Polyline(
              points: [
                driverLocation,
                passengerLocation,
              ],

              strokeWidth: 5,

              color:
                  serviceColor,
            ),
          ],
        ),

        // ========================================================
        // MARCADORES
        // ========================================================

        MarkerLayer(
          markers: [
            // MOTORISTA
            Marker(
              point:
                  driverLocation,

              width: 60,
              height: 60,

              child:
                  _buildMapMarker(
                vehicleIcon,
                serviceColor,
              ),
            ),

            // PASSAGEIRO
            Marker(
              point:
                  passengerLocation,

              width: 50,
              height: 50,

              child:
                  _buildMapMarker(
                Icons.person,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MARCADOR DO MAPA
  // ============================================================

  Widget _buildMapMarker(
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color: Colors.white,

        shape:
            BoxShape.circle,

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.20),

            blurRadius: 8,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      padding:
          const EdgeInsets.all(7),

      child: Container(
        decoration:
            BoxDecoration(
          color: color,

          shape:
              BoxShape.circle,
        ),

        child: Icon(
          icon,

          color:
              Colors.white,

          size: 24,
        ),
      ),
    );
  }

  // ============================================================
  // CARD DE STATUS
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.10),

            blurRadius: 18,

            offset:
                const Offset(0, 6),
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
                  serviceColor.withOpacity(.10),

              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              rideStarted
                  ? Icons.navigation
                  : vehicleIcon,

              color:
                  serviceColor,
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
                  statusTitle,

                  style:
                      const TextStyle(
                    fontSize: 16,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  statusDescription,

                  maxLines: 2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.grey,

                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (!rideStarted &&
              !driverArrived &&
              !rideFinished)
            Text(
              '$remainingMinutes min',

              style:
                  TextStyle(
                color:
                    serviceColor,

                fontWeight:
                    FontWeight.bold,

                fontSize: 15,
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
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        25,
      ),

      decoration:
          const BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(30),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black12,

            blurRadius:
                20,

            offset:
                Offset(0, -5),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            // ==================================================
            // MOTORISTA
            // ==================================================

            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,

                  decoration:
                      BoxDecoration(
                    color:
                        serviceColor
                            .withOpacity(.10),

                    shape:
                        BoxShape.circle,
                  ),

                  child:
                      Icon(
                    vehicleIcon,

                    size: 32,

                    color:
                        serviceColor,
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
                        widget.driverName,

                        style:
                            const TextStyle(
                          fontSize: 17,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons.star,

                            size: 16,

                            color:
                                Colors.amber,
                          ),

                          const SizedBox(
                            width: 4,
                          ),

                          Text(
                            widget.rating
                                .toStringAsFixed(
                              1,
                            ),

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Flexible(
                            child: Text(
                              widget.vehicle,

                              overflow:
                                  TextOverflow
                                      .ellipsis,

                              style:
                                  const TextStyle(
                                color:
                                    Colors.grey,

                                fontSize:
                                    12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed:
                      _contactDriver,

                  style:
                      IconButton.styleFrom(
                    backgroundColor:
                        Colors.green
                            .withOpacity(.10),
                  ),

                  icon:
                      const Icon(
                    Icons.phone,

                    color:
                        Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            // ==================================================
            // PLACA
            // ==================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.grey.shade100,

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons
                        .confirmation_number_outlined,

                    size: 20,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Text(
                    'Placa',

                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    widget.plate,

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // VALOR DA CORRIDA
            // ==================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                13,
              ),

              decoration:
                  BoxDecoration(
                color:
                    serviceColor
                        .withOpacity(.07),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons
                        .payments_outlined,

                    size: 21,

                    color:
                        serviceColor,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Expanded(
                    child: Text(
                      'Valor da corrida',

                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),

                  Text(
                    formattedPrice,

                    style:
                        const TextStyle(
                      fontSize: 17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // ==================================================
            // BOTÃO PRINCIPAL
            // ==================================================

            if (driverArrived &&
                !rideStarted &&
                !rideFinished)
              SizedBox(
                width:
                    double.infinity,

                height: 54,

                child:
                    ElevatedButton.icon(
                  onPressed:
                      _startRide,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        serviceColor,

                    foregroundColor:
                        Colors.white,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  icon:
                      const Icon(
                    Icons.play_arrow,
                  ),

                  label:
                      const Text(
                    'Iniciar corrida',

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,

                      fontSize:
                          16,
                    ),
                  ),
                ),
              )
            else if (rideStarted)
              SizedBox(
                width:
                    double.infinity,

                height: 54,

                child:
                    ElevatedButton.icon(
                  onPressed:
                      _finishRide,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.green,

                    foregroundColor:
                        Colors.white,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  icon:
                      const Icon(
                    Icons.check_circle,
                  ),

                  label:
                      const Text(
                    'Finalizar corrida',

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,

                      fontSize:
                          16,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width:
                    double.infinity,

                height: 54,

                child:
                    OutlinedButton.icon(
                  onPressed:
                      _cancelRide,

                  style:
                      OutlinedButton
                          .styleFrom(
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
                        16,
                      ),
                    ),
                  ),

                  icon:
                      const Icon(
                    Icons.close,
                  ),

                  label:
                      const Text(
                    'Cancelar corrida',

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTÃO CIRCULAR
  // ============================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,

        shape:
            BoxShape.circle,

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.12),

            blurRadius:
                10,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child:
          IconButton(
        onPressed:
            onPressed,

        icon:
            Icon(
          icon,

          color:
              Colors.black87,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }
}