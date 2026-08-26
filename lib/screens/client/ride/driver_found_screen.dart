import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import 'ride_in_progress_screen.dart';

class DriverFoundScreen extends StatefulWidget {
final int rideId;
final String rideType;
final double ridePrice;
final Map<String, dynamic>? driverData;
final Map<String, dynamic>? vehicleData;

const DriverFoundScreen({
  super.key,
  required this.rideId,
  required this.rideType,
  required this.ridePrice,
  this.driverData,
  this.vehicleData,
});

  @override
  State<DriverFoundScreen> createState() =>
      _DriverFoundScreenState();
}

class _DriverFoundScreenState
    extends State<DriverFoundScreen> {
  // ============================================================
  // DADOS DO MOTORISTA
  // ============================================================
String get driverName {
  return widget.driverData?['name']?.toString() ??
      'Motorista';
}

double get driverRating {
  final value = widget.driverData?['rating'];

  if (value == null) {
    return 0;
  }

  return double.tryParse(
        value.toString(),
      ) ??
      0;
}

String get driverLevel => widget.driverData?['driver_level']?.toString() ?? 'Bronze';
int get driverScore => int.tryParse(widget.driverData?['driver_score']?.toString() ?? '0') ?? 0;

String get vehicleModel {
  final brand =
      widget.vehicleData?['brand']?.toString();

  final model =
      widget.vehicleData?['model']?.toString();

  if (brand != null &&
      brand.isNotEmpty &&
      model != null &&
      model.isNotEmpty) {
    return '$brand $model';
  }

  if (model != null && model.isNotEmpty) {
    return model;
  }

  return 'Veículo';
}

String get vehicleColor {
  final color =
      widget.vehicleData?['color']?.toString();

  if (color != null && color.isNotEmpty) {
    return color;
  }

  return 'Não informado';
}

String get vehiclePlate {
  final plate =
      widget.vehicleData?['plate']?.toString();

  if (plate != null && plate.isNotEmpty) {
    return plate;
  }

  return '---';
}
int get arrivalMinutes {
  final value =
      widget.driverData?['arrival_minutes'];

  if (value == null) {
    return 3;
  }

  return int.tryParse(
        value.toString(),
      ) ??
      3;
}
  // ============================================================
  // CONFIRMAR MOTORISTA
  // ============================================================

void _confirmDriver() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          RideInProgressScreen(
        rideId: widget.rideId,
        rideType: widget.rideType,
        ridePrice: widget.ridePrice,
        driverName: driverName,
        vehicleModel: vehicleModel,
        vehiclePlate: vehiclePlate,
        driverLevel: driverLevel,
        driverScore: driverScore,
      ),
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
          title: const Text(
            'Cancelar corrida?',
          ),
          content: const Text(
            'Você deseja cancelar esta corrida?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Voltar',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'Cancelar',
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
  // NOME SERVIÇO
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
          'Motorista encontrado',
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding:
              const EdgeInsets.all(20),

          child: Column(
            children: [
              // ==================================================
              // SUCESSO
              // ==================================================

              _buildSuccessHeader(),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // MOTORISTA
              // ==================================================

              _buildDriverCard(),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // VEÍCULO
              // ==================================================

              _buildVehicleCard(),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // RESUMO DA CORRIDA
              // ==================================================

              _buildRideSummary(),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // BOTÃO CONFIRMAR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height: 58,

                child:
                    ElevatedButton(
                  onPressed:
                      _confirmDriver,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primary,

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

                  child: const Text(
                    'Acompanhar corrida',

                    style: TextStyle(
                      fontSize: 17,

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
              // CANCELAR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height: 54,

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
                        17,
                      ),
                    ),
                  ),

                  child: const Text(
                    'Cancelar corrida',

                    style: TextStyle(
                      fontSize: 16,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // AVISO
              // ==================================================

              _buildSafetyInfo(),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,

          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,

            color:
                Colors.green
                    .withOpacity(.12),
          ),

          child: const Icon(
            Icons.check_circle,
            color:
                Colors.green,
            size: 52,
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        const Text(
          'Motorista encontrado!',

          textAlign:
              TextAlign.center,

          style: TextStyle(
            fontSize: 27,

            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          'Seu ${serviceName.toLowerCase()} '
          'está a aproximadamente '
          '$arrivalMinutes minutos.',

          textAlign:
              TextAlign.center,

          style: TextStyle(
            color:
                Colors.grey.shade600,

            fontSize: 15,

            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOTORISTA
  // ============================================================

  Widget _buildDriverCard() {
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
          22,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .04,
            ),

            blurRadius: 14,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [
          // ==================================================
          // FOTO
          // ==================================================

          Container(
            width: 70,
            height: 70,

            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,

              color:
                  AppColors.primary
                      .withOpacity(
                .10,
              ),
            ),

            child: Icon(
              Icons.person,

              color:
                  AppColors.primary,

              size: 42,
            ),
          ),

          const SizedBox(
            width: 15,
          ),

          // ==================================================
          // DADOS
          // ==================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  driverName,

                  style:
                      const TextStyle(
                    fontSize: 19,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color:
                          Colors.amber,
                      size: 18,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      driverRating
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
                      width: 6,
                    ),

                    Text(
                      'Motorista parceiro',

                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade600,

                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================================================
          // STATUS
          // ==================================================

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
                      .withOpacity(
                .10,
              ),

              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),

            child: const Text(
              'Online',

              style: TextStyle(
                color:
                    Colors.green,

                fontSize: 12,

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
  // VEÍCULO
  // ============================================================

  Widget _buildVehicleCard() {
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
          22,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Veículo',

            style: TextStyle(
              fontSize: 17,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Container(
                width: 50,
                height: 50,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey
                          .withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  serviceIcon,

                  color:
                      Colors.grey.shade700,

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
                    Text(
                      vehicleModel,

                      style:
                          const TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      vehicleColor,

                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade600,

                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade100,

                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),

                child: Text(
                  vehiclePlate,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,

                    letterSpacing:
                        1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESUMO
  // ============================================================

  Widget _buildRideSummary() {
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
          22,
        ),
      ),

      child: Column(
        children: [
          _infoRow(
            Icons.two_wheeler,
            'Serviço',
            serviceName,
          ),

          const SizedBox(
            height: 14,
          ),

          _infoRow(
            Icons.access_time,
            'Chegada',
            '$arrivalMinutes minutos',
          ),

          const SizedBox(
            height: 14,
          ),

          _infoRow(
            Icons.payment,
            'Valor estimado',
            'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LINHA DE INFORMAÇÃO
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

          size: 22,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Text(
            title,

            style:
                TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 14,
            ),
          ),
        ),

        Text(
          value,

          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,

            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEGURANÇA
  // ============================================================

  Widget _buildSafetyInfo() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            Colors.blue.withOpacity(
          .06,
        ),

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              Colors.blue.withOpacity(
            .12,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.shield_outlined,

            color:
                Colors.blue,

            size: 23,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Confira o veículo e a placa antes de embarcar.',

              style:
                  TextStyle(
                color:
                    Colors.blue.shade800,

                fontSize: 12.5,

                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}