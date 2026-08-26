import '../../../config/api_config.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import '../../../config/colors.dart';

import '../../../services/auth_service.dart';

class DriverVehicleScreen extends StatefulWidget {

  const DriverVehicleScreen({

    super.key,

  });

  @override

  State<DriverVehicleScreen> createState() =>

      _DriverVehicleScreenState();

}

class _DriverVehicleScreenState

    extends State<DriverVehicleScreen> {

  // ============================================================

  // API

  // ============================================================

  static const String baseUrl = ApiConfig.baseUrl;

  // ============================================================

  // CONTROLLERS

  // ============================================================

  final brandController =

      TextEditingController();

  final modelController =

      TextEditingController();

  final yearController =

      TextEditingController();

  final colorController =

      TextEditingController();

  final plateController =

      TextEditingController();

  // ============================================================

  // FORM

  // ============================================================

  final formKey =

      GlobalKey<FormState>();

  // ============================================================

  // ESTADO

  // ============================================================

  String vehicleType = 'moto';

  bool isLoading = false;

  bool isCheckingVehicle = true;
  Map<String, dynamic>? existingVehicle;

  // ============================================================

  // DISPOSE

  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadExistingVehicle();
  }

  // ============================================================
  // CARREGAR VEÍCULO JÁ CADASTRADO
  // ============================================================

  Future<void> _loadExistingVehicle() async {
    try {
      final String? savedUserId = await AuthService.getUserId();

      if (savedUserId == null || savedUserId.isEmpty) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final driverUrl = Uri.parse(
        '$baseUrl/drivers/by_user.php?user_id=$savedUserId',
      );

      final driverResponse = await http.get(
        driverUrl,
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (driverResponse.statusCode != 200) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final dynamic driverData = jsonDecode(driverResponse.body);
      if (driverData is! Map) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final dynamic driver = driverData['driver'];
      if (driver is! Map || driver['id'] == null) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final int driverId = int.tryParse(
            driver['id'].toString(),
          ) ??
          0;

      if (driverId <= 0) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final vehicleUrl = Uri.parse(
        '$baseUrl/drivers/vehicle.php?driver_id=$driverId',
      );

      final vehicleResponse = await http.get(
        vehicleUrl,
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (vehicleResponse.statusCode < 200 ||
          vehicleResponse.statusCode >= 300) {
        if (mounted) {
          setState(() => isCheckingVehicle = false);
        }
        return;
      }

      final dynamic data = jsonDecode(vehicleResponse.body);
      Map<String, dynamic>? vehicle;

      if (data is Map) {
        final dynamic rawVehicle = data['vehicle'];
        if (rawVehicle is Map) {
          vehicle = Map<String, dynamic>.from(rawVehicle);
        }
      }

      if (!mounted) return;

      setState(() {
        existingVehicle = vehicle;
        isCheckingVehicle = false;

        if (vehicle != null) {
          final type = vehicle['vehicle_type']
              ?.toString()
              .toLowerCase();

          if (type == 'carro') {
            vehicleType = 'carro';
          } else if (type == 'bicicleta' || type == 'bike') {
            vehicleType = 'bicicleta';
          } else {
            vehicleType = 'moto';
          }
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isCheckingVehicle = false;
      });
    }
  }

  // ============================================================
  // VEÍCULO CADASTRADO
  // ============================================================

  Widget _buildExistingVehicle() {
    final vehicle = existingVehicle ?? <String, dynamic>{};

    final type =
        (vehicle['vehicle_type'] ?? 'moto')
            .toString()
            .toLowerCase();

    final brand = vehicle['brand']?.toString() ?? '-';
    final model = vehicle['model']?.toString() ?? '-';
    final year = vehicle['year']?.toString() ?? '-';
    final color = vehicle['color']?.toString() ?? '-';
    final plate = vehicle['plate']?.toString() ?? '';
    final status =
        vehicle['status']?.toString().toLowerCase() ?? 'pending';

    String typeLabel;
    IconData typeIcon;

    if (type == 'carro') {
      typeLabel = 'Carro';
      typeIcon = Icons.directions_car;
    } else if (type == 'bicicleta' || type == 'bike') {
      typeLabel = 'Bike';
      typeIcon = Icons.pedal_bike;
    } else {
      typeLabel = 'Moto';
      typeIcon = Icons.two_wheeler;
    }

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'approved':
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.verified_outlined;
        statusLabel = 'Veículo aprovado';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        statusLabel = 'Veículo não aprovado';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_outlined;
        statusLabel = 'Veículo em análise';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Veículo cadastrado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      typeIcon,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$brand $model',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$typeLabel • $year',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _vehicleInfoRow('Marca', brand),
              _vehicleInfoRow('Modelo', model),
              _vehicleInfoRow('Ano', year),
              _vehicleInfoRow('Cor', color),
              if (type != 'bicicleta' &&
                  type != 'bike' &&
                  plate.trim().isNotEmpty)
                _vehicleInfoRow(
                  'Placa',
                  plate.toUpperCase(),
                ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vehicleInfoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override

  void dispose() {

    brandController.dispose();

    modelController.dispose();

    yearController.dispose();

    colorController.dispose();

    plateController.dispose();

    super.dispose();

  }

  // ============================================================

  // CADASTRAR

  // ============================================================

  Future<void> _registerVehicle() async {

    if (isLoading) return;

    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {

      return;

    }

    setState(() {

      isLoading = true;

    });

    try {

      // ========================================================

      // PEGAR USER ID

      // ========================================================

      final String? savedUserId =

          await AuthService.getUserId();

      if (savedUserId == null ||

          savedUserId.isEmpty) {

        _showMessage(

          'Motorista não identificado. Faça login novamente.',

        );

        return;

      }

      // ========================================================

      // BUSCAR MOTORISTA

      // ========================================================

      final driverUrl = Uri.parse(

        '$baseUrl/drivers/by_user.php'

        '?user_id=$savedUserId',

      );

      final driverResponse =

          await http.get(

        driverUrl,

        headers: {

          'Accept': 'application/json',

        },

      );

      if (driverResponse.statusCode != 200) {

        _showMessage(

          'Não foi possível identificar o motorista.',

        );

        return;

      }

      final driverData =

          jsonDecode(driverResponse.body);

      final driver =

          driverData['driver'];

      if (driver == null ||

          driver['id'] == null) {

        _showMessage(

          'Dados do motorista não encontrados.',

        );

        return;

      }

      final int driverId =

          int.parse(

        driver['id'].toString(),

      );

      // ========================================================

      // CADASTRAR VEÍCULO

      // ========================================================

      final vehicleUrl = Uri.parse(

        '$baseUrl/vehicles/create.php',

      );

      final response =

          await http.post(

        vehicleUrl,

        headers: {

          'Content-Type':

              'application/json',

          'Accept':

              'application/json',

        },

        body: jsonEncode(

          {

            'driver_id': driverId,

            'vehicle_type':

                vehicleType,

            'brand':

                brandController.text.trim(),

            'model':

                modelController.text.trim(),

            'year':

                int.parse(

              yearController.text.trim(),

            ),

            'color':

                colorController.text.trim(),

            'plate':

                vehicleType == 'bicicleta'

                    ? ''

                    : plateController.text

                        .trim()

                        .toUpperCase(),

          },

        ),

      );

      // ========================================================

      // RESPOSTA

      // ========================================================

      final data =

          jsonDecode(response.body);

      if (response.statusCode == 201 &&

          data['success'] == true) {

        if (!mounted) return;

        _showMessage(

          'Veículo cadastrado! Aguarde a aprovação.',

          success: true,

        );

        await Future.delayed(

          const Duration(

            milliseconds: 900,

          ),

        );

        if (!mounted) return;

        Navigator.pop(context);

        return;

      }

      _showMessage(

        data['message'] ??

            'Não foi possível cadastrar o veículo.',

      );

    } catch (e) {

      _showMessage(

        'Erro ao conectar com o servidor.',

      );

    } finally {

      if (!mounted) return;

      setState(() {

        isLoading = false;

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

  // TÍTULO DO TIPO

  // ============================================================

  String get vehicleTypeLabel {

    switch (vehicleType) {

      case 'carro':

        return 'Carro';

      case 'bicicleta':

        return 'Bicicleta';

      default:

        return 'Moto';

    }

  }

  // ============================================================

  // ÍCONE

  // ============================================================

  IconData get vehicleIcon {

    switch (vehicleType) {

      case 'carro':

        return Icons.directions_car;

      case 'bicicleta':

        return Icons.pedal_bike;

      default:

        return Icons.two_wheeler;

    }

  }

  // ============================================================

  // CAMPO

  // ============================================================

  Widget _textField({

    required TextEditingController controller,

    required String label,

    required IconData icon,

    TextInputType? keyboardType,

    String? Function(String?)? validator,

    bool enabled = true,

    TextCapitalization textCapitalization =

        TextCapitalization.sentences,

  }) {

    return Padding(

      padding:

          const EdgeInsets.only(

        bottom: 14,

      ),

      child: TextFormField(

        controller: controller,

        enabled: enabled,

        keyboardType:

            keyboardType,

        textCapitalization:

            textCapitalization,

        decoration:

            InputDecoration(

          labelText: label,

          prefixIcon:

              Icon(

            icon,

            color:

                AppColors.primary,

          ),

          filled: true,

          fillColor:

              Colors.white,

          border:

              OutlineInputBorder(

            borderRadius:

                BorderRadius.circular(

              15,

            ),

            borderSide:

                BorderSide.none,

          ),

          enabledBorder:

              OutlineInputBorder(

            borderRadius:

                BorderRadius.circular(

              15,

            ),

            borderSide:

                BorderSide(

              color:

                  Colors.grey.shade200,

            ),

          ),

          focusedBorder:

              OutlineInputBorder(

            borderRadius:

                BorderRadius.circular(

              15,

            ),

            borderSide:

                const BorderSide(

              color:

                  AppColors.primary,

              width: 1.5,

            ),

          ),

        ),

        validator:

            validator,

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

    final bool requiresPlate =

        vehicleType != 'bicicleta';

    return Scaffold(

      backgroundColor:

          AppColors.background,

      appBar: AppBar(

        title:

            const Text(

          'Meu veículo',

          style: TextStyle(

            fontWeight:

                FontWeight.bold,

          ),

        ),

        backgroundColor:

            AppColors.background,

        elevation: 0,

        foregroundColor:

            Colors.black,

      ),

      body:

          SafeArea(

        child:

            Form(

          key: formKey,

          child:

              SingleChildScrollView(

            padding:

                const EdgeInsets.fromLTRB(

              20,

              10,

              20,

              30,

            ),

            child:

                Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                // ==================================================

                // CABEÇALHO

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

                        Colors.white,

                    borderRadius:

                        BorderRadius.circular(

                      20,

                    ),

                  ),

                  child:

                      Row(

                    children: [

                      Container(

                        width: 58,

                        height: 58,

                        decoration:

                            BoxDecoration(

                          color:

                              AppColors.primary

                                  .withOpacity(.10),

                          borderRadius:

                              BorderRadius.circular(

                            16,

                          ),

                        ),

                        child:

                            Icon(

                          vehicleIcon,

                          color:

                              AppColors.primary,

                          size: 30,

                        ),

                      ),

                      const SizedBox(

                        width: 14,

                      ),

                      Expanded(

                        child:

                            Column(

                          crossAxisAlignment:

                              CrossAxisAlignment.start,

                          children: [

                            Text(

                              isCheckingVehicle
                                  ? 'Carregando veículo...'
                                  : existingVehicle != null
                                      ? 'Seu veículo'
                                      : 'Cadastre seu veículo',

                              style:

                                  TextStyle(

                                fontSize: 18,

                                fontWeight:

                                    FontWeight.bold,

                              ),

                            ),

                            const SizedBox(

                              height: 5,

                            ),

                            Text(

                              isCheckingVehicle
                                  ? 'Consultando seu cadastro...'
                                  : existingVehicle != null
                                      ? 'Dados do veículo cadastrado'
                                      : 'Informe os dados do seu $vehicleTypeLabel.',

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

                    ],

                  ),

                ),

                const SizedBox(

                  height: 22,

                ),

                if (isCheckingVehicle) ...[

                  const SizedBox(height: 40),

                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                  const SizedBox(height: 12),

                  const Center(
                    child: Text(
                      'Carregando seus dados...',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),

                ] else if (existingVehicle != null) ...[

                  _buildExistingVehicle(),

                ] else ...[

                // ==================================================

                // TIPO

                // ==================================================

                const Text(

                  'Tipo de veículo',

                  style:

                      TextStyle(

                    fontSize: 16,

                    fontWeight:

                        FontWeight.bold,

                  ),

                ),

                const SizedBox(

                  height: 12,

                ),

                Row(

                  children: [

                    Expanded(

                      child:

                          _vehicleTypeButton(

                        type: 'moto',

                        label: 'Moto',

                        icon:

                            Icons.two_wheeler,

                      ),

                    ),

                    const SizedBox(

                      width: 10,

                    ),

                    Expanded(

                      child:

                          _vehicleTypeButton(

                        type: 'carro',

                        label: 'Carro',

                        icon:

                            Icons.directions_car,

                      ),

                    ),

                    const SizedBox(

                      width: 10,

                    ),

                    Expanded(

                      child:

                          _vehicleTypeButton(

                        type: 'bicicleta',

                        label: 'Bike',

                        icon:

                            Icons.pedal_bike,

                      ),

                    ),

                  ],

                ),

                const SizedBox(

                  height: 22,

                ),

                // ==================================================

                // DADOS

                // ==================================================

                const Text(

                  'Dados do veículo',

                  style:

                      TextStyle(

                    fontSize: 16,

                    fontWeight:

                        FontWeight.bold,

                  ),

                ),

                const SizedBox(

                  height: 12,

                ),

                _textField(

                  controller:

                      brandController,

                  label:

                      'Marca',

                  icon:

                      Icons.business_outlined,

                  validator: (value) {

                    if (value == null ||

                        value.trim().isEmpty) {

                      return 'Informe a marca';

                    }

                    return null;

                  },

                ),

                _textField(

                  controller:

                      modelController,

                  label:

                      'Modelo',

                  icon:

                      Icons.directions_car_outlined,

                  validator: (value) {

                    if (value == null ||

                        value.trim().isEmpty) {

                      return 'Informe o modelo';

                    }

                    return null;

                  },

                ),

                _textField(

                  controller:

                      yearController,

                  label:

                      'Ano',

                  icon:

                      Icons.calendar_today_outlined,

                  keyboardType:

                      TextInputType.number,

                  validator: (value) {

                    if (value == null ||

                        value.trim().isEmpty) {

                      return 'Informe o ano';

                    }

                    final year =

                        int.tryParse(

                      value.trim(),

                    );

                    if (year == null) {

                      return 'Ano inválido';

                    }

                    if (year < 1900 ||

                        year >

                            DateTime.now()

                                    .year +

                                1) {

                      return 'Ano inválido';

                    }

                    return null;

                  },

                ),

                _textField(

                  controller:

                      colorController,

                  label:

                      'Cor',

                  icon:

                      Icons.palette_outlined,

                  validator: (value) {

                    if (value == null ||

                        value.trim().isEmpty) {

                      return 'Informe a cor';

                    }

                    return null;

                  },

                ),

                if (requiresPlate)

                  _textField(

                    controller:

                        plateController,

                    label:

                        'Placa',

                    icon:

                        Icons.pin_outlined,

                    textCapitalization:

                        TextCapitalization.characters,

                    validator: (value) {

                      if (value == null ||

                          value.trim().isEmpty) {

                        return 'Informe a placa';

                      }

                      return null;

                    },

                  ),

                // ==================================================

                // AVISO BIKE

                // ==================================================

                if (!requiresPlate)

                  Container(

                    width:

                        double.infinity,

                    padding:

                        const EdgeInsets.all(

                      15,

                    ),

                    margin:

                        const EdgeInsets.only(

                      bottom: 16,

                    ),

                    decoration:

                        BoxDecoration(

                      color:

                          Colors.blue.withOpacity(

                        .06,

                      ),

                      borderRadius:

                          BorderRadius.circular(

                        14,

                      ),

                    ),

                    child:

                        Row(

                      children: [

                        Icon(

                          Icons.info_outline,

                          color:

                              Colors.blue.shade700,

                        ),

                        const SizedBox(

                          width: 10,

                        ),

                        Expanded(

                          child:

                              Text(

                            'Bicicletas não precisam informar placa.',

                            style:

                                TextStyle(

                              color:

                                  Colors.blue.shade800,

                              fontSize: 13,

                            ),

                          ),

                        ),

                      ],

                    ),

                  ),

                // ==================================================

                // APROVAÇÃO

                // ==================================================

                Container(

                  width:

                      double.infinity,

                  padding:

                      const EdgeInsets.all(

                    15,

                  ),

                  margin:

                      const EdgeInsets.only(

                    bottom: 20,

                  ),

                  decoration:

                      BoxDecoration(

                    color:

                        Colors.orange.withOpacity(

                      .07,

                    ),

                    borderRadius:

                        BorderRadius.circular(

                      14,

                    ),

                  ),

                  child:

                      Row(

                    crossAxisAlignment:

                        CrossAxisAlignment.start,

                    children: [

                      Icon(

                        Icons

                            .verified_outlined,

                        color:

                            Colors.orange.shade700,

                      ),

                      const SizedBox(

                        width: 10,

                      ),

                      Expanded(

                        child:

                            Text(

                          'Após o cadastro, seu veículo será analisado pela equipe antes de ser utilizado nas corridas.',

                          style:

                              TextStyle(

                            color:

                                Colors.orange.shade900,

                            fontSize: 13,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

                // ==================================================

                // BOTÃO

                // ==================================================

                SizedBox(

                  width:

                      double.infinity,

                  height: 56,

                  child:

                      ElevatedButton(

                    onPressed:

                        isLoading

                            ? null

                            : _registerVehicle,

                    style:

                        ElevatedButton.styleFrom(

                      backgroundColor:

                          AppColors.primary,

                      foregroundColor:

                          Colors.white,

                      disabledBackgroundColor:

                          Colors.grey.shade300,

                      elevation: 0,

                      shape:

                          RoundedRectangleBorder(

                        borderRadius:

                            BorderRadius.circular(

                          16,

                        ),

                      ),

                    ),

                    child:

                        isLoading

                            ? const SizedBox(

                                width: 24,

                                height: 24,

                                child:

                                    CircularProgressIndicator(

                                  strokeWidth: 2.5,

                                  color:

                                      Colors.white,

                                ),

                              )

                            : const Text(

                                'Cadastrar veículo',

                                style:

                                    TextStyle(

                                  fontSize: 16,

                                  fontWeight:

                                      FontWeight.bold,

                                ),

                              ),

                  ),

                ),

                ],

              ],

            ),

          ),

        ),

      ),

    );

  }

  // ============================================================

  // BOTÃO TIPO

  // ============================================================

  Widget _vehicleTypeButton({

    required String type,

    required String label,

    required IconData icon,

  }) {

    final bool selected =

        vehicleType == type;

    return GestureDetector(

      onTap: () {

        setState(() {

          vehicleType = type;

        });

      },

      child:

          AnimatedContainer(

        duration:

            const Duration(

          milliseconds: 180,

        ),

        padding:

            const EdgeInsets.symmetric(

          vertical: 15,

          horizontal: 6,

        ),

        decoration:

            BoxDecoration(

          color:

              selected

                  ? AppColors.primary

                  : Colors.white,

          borderRadius:

              BorderRadius.circular(

            16,

          ),

          border:

              Border.all(

            color:

                selected

                    ? AppColors.primary

                    : Colors.grey.shade200,

          ),

        ),

        child:

            Column(

          children: [

            Icon(

              icon,

              color:

                  selected

                      ? Colors.white

                      : AppColors.primary,

              size: 27,

            ),

            const SizedBox(

              height: 7,

            ),

            Text(

              label,

              style:

                  TextStyle(

                color:

                    selected

                        ? Colors.white

                        : Colors.black87,

                fontWeight:

                    FontWeight.w600,

                fontSize: 12,

              ),

            ),

          ],

        ),

      ),

    );

  }

}