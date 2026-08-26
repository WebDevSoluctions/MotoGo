import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../config/colors.dart';

import '../../../services/fare_service.dart';

import '../../../services/api_service.dart';

import '../../../services/auth_service.dart';

import '../../../services/location_service.dart';

import '../../../services/route_service.dart';

import 'searching_driver_screen.dart';

import '../../maps/point_picker_screen.dart';

import 'widgets/origin_card.dart';

import 'widgets/destination_card.dart';

import 'widgets/ride_type_card.dart';

import 'widgets/payment_card.dart';

import 'widgets/price_card.dart';

import 'widgets/confirm_button.dart';
import '../../../widgets/address_search_field.dart';

class RideRequestScreen extends StatefulWidget {

  final String rideType;

  final LatLng? destination;

  final String? destinationName;

  const RideRequestScreen({

    super.key,

    this.rideType = 'mototaxi',

    this.destination,

    this.destinationName,

  });

  @override

  State<RideRequestScreen> createState() =>

      _RideRequestScreenState();

}

class _RideRequestScreenState

    extends State<RideRequestScreen> {

  // ============================================================

  // SERVIÇOS

  // ============================================================

  final RouteService _routeService =

      RouteService();

  final LocationService _locationService =

      LocationService();

  // ============================================================

  // CONTROLLERS

  // ============================================================

  final TextEditingController originController =

      TextEditingController();

  final TextEditingController destinationController =

      TextEditingController();

  // ============================================================

  // ESTADO

  // ============================================================

  late String rideType;

  String payment = 'pix';

  double? distanceKm;

  double? estimatedPrice;

  double? estimatedMinutes;

  FareResult? fareResult;

  LatLng? currentLocation;

  // ORIGEM REAL SELECIONADA

  LatLng? selectedOrigin;

  bool settingOriginText = false;

  // DESTINO REAL SELECIONADO

  LatLng? selectedDestination;

  bool calculatingRoute = false;

  bool searchingDestination = false;

  bool loadingLocation = true;

  bool confirmingRide = false;

  String? scheduledAt;

  String? passengerName;

  String? passengerPhone;

  int? favoriteDriverId;

  String? favoriteDriverName;

  final List<Map<String, dynamic>> rideStops = [];

  String? locationError;

  String? destinationError;

  // Melhor precisão GPS obtida para a origem automática.
  double? originAccuracyMeters;

  // ============================================================

  // INIT

  // ============================================================

  @override

  void initState() {

    super.initState();

    rideType = widget.rideType;

    // Se a tela já recebeu coordenadas

    selectedDestination =

        widget.destination;

    // Se recebeu nome do destino

    if (widget.destinationName != null &&

        widget.destinationName!

            .trim()

            .isNotEmpty) {

      destinationController.text =

          widget.destinationName!;

    }

    originController.addListener(_onOriginChanged);

    _initializeFareAndLocation();

  }

  Future<void> _initializeFareAndLocation() async {

    await FareService.loadFromApi();

    if (!mounted) return;

    await _loadRealLocation();

  }

  // ============================================================

  // DISPOSE

  // ============================================================

  @override

  void dispose() {

    originController.removeListener(_onOriginChanged);

    originController.dispose();

    destinationController.dispose();

    super.dispose();

  }

  // ============================================================

  // ORIGEM ALTERADA MANUALMENTE

  // ============================================================

  void _onOriginChanged() {

    if (settingOriginText) return;

    final text = originController.text.trim();

    if (text.isEmpty || text == 'Minha localização atual') {

      return;

    }

    if (selectedOrigin != null) {

      selectedOrigin = null;

      currentLocation = null;

      fareResult = null;

      distanceKm = null;

      estimatedPrice = null;

      estimatedMinutes = null;

      if (mounted) setState(() {});

    }

  }

  // ============================================================

  // PESQUISAR ORIGEM

  // ============================================================

  Future<bool> _searchOrigin() async {

    final query = originController.text.trim();

    if (query.isEmpty || query == 'Minha localização atual') {

      await _loadRealLocation();

      return currentLocation != null;

    }

    try {

      final result = await _routeService.searchDestination(
        query,
        nearby: currentLocation,
      );

      if (!mounted) return false;

      if (result == null) {

        _showMessage(

          'Origem não encontrada. Digite rua, bairro, número e cidade.',

        );

        return false;

      }

      selectedOrigin = result;

      currentLocation = result;

      setState(() {

        locationError = null;

        fareResult = null;

        distanceKm = null;

        estimatedPrice = null;

        estimatedMinutes = null;

      });

      if (selectedDestination != null) {

        await _calculateEstimatedFare();

      }

      return true;

    } catch (e) {

      debugPrint('Erro ao pesquisar origem: $e');

      if (mounted) {

        _showMessage('Não foi possível pesquisar a origem.');

      }

      return false;

    }

  }

  // ============================================================

  // LOCALIZAÇÃO ATUAL

  // ============================================================

Future<void> _loadRealLocation() async {
    if (!mounted) return;

    setState(() {
      loadingLocation = true;
      locationError = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('GPS desativado. Ative a localização do aparelho.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização não concedida.');
      }

      // IMPORTANTE: não deixar o Chrome/desktop ficar preso indefinidamente
      // em "Obtendo sua localização...". No celular o GPS pode demorar alguns
      // segundos na primeira leitura; no PC o navegador pode nunca responder.
      Position? bestPosition;

      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            ),
          ).timeout(const Duration(seconds: 7));

          if (bestPosition == null ||
              position.accuracy < bestPosition.accuracy) {
            bestPosition = position;
          }

          // 15 m ou menos é uma boa precisão para embarque urbano.
          if (position.accuracy <= 15) break;
        } on TimeoutException {
          debugPrint('GPS demorou mais de 7s na tentativa ${attempt + 1}.');
        }

        if (attempt == 0) {
          await Future<void>.delayed(
            const Duration(milliseconds: 400),
          );
        }
      }

      // Última tentativa de recuperar uma posição já conhecida pelo sistema.
      // Ela só é usada se não conseguimos nenhuma leitura atual.
      if (bestPosition == null) {
        try {
          bestPosition = await Geolocator.getLastKnownPosition();
        } catch (_) {
          // Alguns ambientes, especialmente Web, não oferecem posição salva.
        }
      }

      if (bestPosition == null) {
        throw Exception(
          'Não foi possível obter uma posição GPS dentro do tempo esperado.',
        );
      }

      debugPrint(
        'GPS passageiro: ${bestPosition.latitude}, '
        '${bestPosition.longitude} | precisão: '
        '${bestPosition.accuracy.toStringAsFixed(1)} m',
      );

      if (!mounted) return;

      currentLocation = LatLng(
        bestPosition.latitude,
        bestPosition.longitude,
      );
      selectedOrigin = currentLocation;
      originAccuracyMeters = bestPosition.accuracy;

      settingOriginText = true;
      originController.text = 'Minha localização atual';
      settingOriginText = false;

      setState(() {
        loadingLocation = false;
        locationError = null;
      });

      if (selectedDestination != null) {
        await _calculateEstimatedFare();
      }
    } catch (e) {
      debugPrint('Erro ao obter localização GPS: $e');

      if (!mounted) return;

      setState(() {
        loadingLocation = false;
        locationError =
            'Não foi possível obter sua localização. Verifique o GPS e a permissão.';
      });
    }
  }

  // ============================================================

  // PESQUISAR DESTINO

  // ============================================================

  Future<bool> _searchDestination() async {

    final query =

        destinationController.text.trim();

    if (query.isEmpty) {

      if (!mounted) return false;

      setState(() {

        destinationError =

            'Digite um destino.';

      });

      return false;

    }

    if (searchingDestination) {

      return false;

    }

    setState(() {

      searchingDestination = true;

      destinationError = null;

    });

    try {

      final result =

          await _routeService

              .searchDestination(
                query,
                nearby: currentLocation,
              );

      if (!mounted) return false;

      if (result == null) {

        setState(() {

          searchingDestination = false;

          selectedDestination = null;

          destinationError =

              'Destino não encontrado. '

              'Digite uma cidade ou endereço válido.';

        });

        return false;

      }

      // DESTINO AGORA POSSUI LATITUDE/LONGITUDE

      setState(() {

        selectedDestination = result;

        searchingDestination = false;

        destinationError = null;

      });

      // Se já temos a localização atual,

      // calcula a rota imediatamente.

      if (currentLocation != null) {

        await _calculateEstimatedFare();

      }

      return true;

    } catch (e) {

      debugPrint(

        'Erro ao pesquisar destino: $e',

      );

      if (!mounted) return false;

      setState(() {

        searchingDestination = false;

        selectedDestination = null;

        destinationError =

            'Não foi possível pesquisar o destino.';

      });

      return false;

    }

  }

  // ============================================================

  // CALCULAR ROTA + PREÇO

  // ============================================================

Future<void> _calculateEstimatedFare() async {    if (!mounted) return;

    // NÃO USA MAIS widget.destination

    if (selectedDestination == null) {

      setState(() {

        calculatingRoute = false;

        fareResult = null;

        distanceKm = null;

        estimatedPrice = null;

        estimatedMinutes = null;

      });

      return;

    }

    if (currentLocation == null) {

      return;

    }

    setState(() {

      calculatingRoute = true;

    });

    try {

      final stopPoints = rideStops

          .map((s) => LatLng(

                double.parse(s['latitude'].toString()),

                double.parse(s['longitude'].toString()),

              ))

          .toList();

      final route = stopPoints.isEmpty

          ? await _routeService.calculateRoute(

              origin: currentLocation!,

              destination: selectedDestination!,

            )

          : await _routeService.calculateMultiStopRoute(

              origin: currentLocation!,

              stops: stopPoints,

              destination: selectedDestination!,

            );

      if (!mounted) return;

      if (route == null) {

        setState(() {

          calculatingRoute = false;

          fareResult = null;

          distanceKm = null;

          estimatedPrice = null;

          estimatedMinutes = null;

        });

        _showMessage(

          'Não foi possível calcular a rota.',

        );

        return;

      }

      final bool isLongTrip =

          route.distanceKm > FareService.longDistanceLimitKm;

      if (isLongTrip && rideType != 'viagem') {

        rideType = 'viagem';

      } else if (!isLongTrip && rideType == 'viagem') {

        rideType = widget.rideType;

      }

      final fare =

          FareService.calculate(

        distanceKm: route.distanceKm,

        rideType: rideType,

      );

      setState(() {

        distanceKm =

            route.distanceKm;

        estimatedMinutes =

            route.durationMinutes;

        estimatedPrice =

            fare.total;

        fareResult = fare;

        calculatingRoute = false;

      });

    } catch (e) {

      debugPrint(

        'Erro ao calcular rota: $e',

      );

      if (!mounted) return;

      setState(() {

        calculatingRoute = false;

        fareResult = null;

        distanceKm = null;

        estimatedPrice = null;

        estimatedMinutes = null;

      });

      _showMessage(

        'Erro ao calcular rota.',

      );

    }

  }

  // ============================================================

  // ALTERAR TIPO DE CORRIDA

  // ============================================================

  void _changeRideType(

    String type,

  ) {

    if (type == 'viagem' &&

        (distanceKm == null ||

            distanceKm! <= FareService.longDistanceLimitKm)) {

      _showMessage(

        'Viagem fica disponível para trajetos acima de ${FareService.longDistanceLimitKm.toStringAsFixed(0)} km.',

      );

      return;

    }

    setState(() {

      rideType = type;

    });

    if (selectedDestination != null &&

        currentLocation != null) {

      _calculateEstimatedFare();

    }

  }

  // ============================================================

  // ALTERAR PAGAMENTO

  // ============================================================

  void _changePayment(

    String value,

  ) {

    setState(() {

      payment = value;

    });

  }

  Future<void> _pickPoint({required bool origin}) async {

    final current = origin ? (selectedOrigin ?? currentLocation) : selectedDestination;

    if (current == null) {

      _showMessage('Primeiro pesquise ou obtenha uma localização.');

      return;

    }

    final point = await Navigator.push<LatLng>(

      context,

      MaterialPageRoute(

        builder: (_) => PointPickerScreen(

          initialPoint: current,

          title: origin ? 'Confirmar partida' : 'Confirmar destino',

        ),

      ),

    );

    if (!mounted || point == null) return;

    setState(() {

      if (origin) {

        selectedOrigin = point;

        currentLocation = point;
        // Ao confirmar manualmente no mapa, o ponto passa a ser a fonte
        // oficial da origem, independentemente da precisão do GPS.
        originAccuracyMeters = null;

      } else {

        selectedDestination = point;

      }

      fareResult = null;

      distanceKm = null;

      estimatedPrice = null;

    });

    if (selectedOrigin != null && selectedDestination != null) {

      await _calculateEstimatedFare();

    }

  }

  Future<void> _chooseFavoriteDriver() async {

    final userId = int.tryParse(await AuthService.getUserId() ?? '');

    if (userId == null || userId <= 0) return;

    final result = await ApiService.getFavoriteDrivers(userId);

    if (!mounted) return;

    final favorites = result['favorites'] is List ? List<dynamic>.from(result['favorites']) : <dynamic>[];

    if (favorites.isEmpty) { _showMessage('Você ainda não possui motoristas favoritos.'); return; }

    final selected = await showDialog<dynamic>(

      context: context,

      builder: (_) => AlertDialog(

        title: const Text('Escolha seu motorista favorito'),

        content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: favorites.map((f) => ListTile(

          leading: const Icon(Icons.star, color: Colors.amber),

          title: Text('${f["name"] ?? 'Motorista'}'),

          subtitle: Text('${f["vehicle_model"] ?? ''} ${f["plate"] ?? ''}'),

          onTap: () => Navigator.pop(context, f),

        )).toList())),

      ),

    );

    if (selected is Map && mounted) {

      setState(() {

        favoriteDriverId = int.tryParse(selected['driver_id']?.toString() ?? '');

        favoriteDriverName = selected['name']?.toString();

      });

    }

  }

  Future<void> _configurePassenger() async {

    final name = TextEditingController(text: passengerName ?? '');

    final phone = TextEditingController(text: passengerPhone ?? '');

    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(

      title: const Text('Corrida para outra pessoa'),

      content: Column(mainAxisSize: MainAxisSize.min, children: [

        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do passageiro')),

        const SizedBox(height: 12),

        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone')),

      ]),

      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))],

    ));

    if (ok == true && mounted) setState(() { passengerName = name.text.trim(); passengerPhone = phone.text.trim(); });

    name.dispose(); phone.dispose();

  }

  Future<void> _configureSchedule() async {

    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: DateTime.now());

    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (!dt.isAfter(DateTime.now())) { _showMessage('Escolha um horário futuro.'); return; }

    setState(() => scheduledAt = dt.toLocal().toString().substring(0, 19));

  }

  Future<void> _configureStops() async {

    final count = rideStops.length > 4 ? 4 : rideStops.length;

    final controllers = List.generate(count, (i) => TextEditingController(text: rideStops[i]['address']?.toString() ?? ''));

    while (controllers.length < 1) controllers.add(TextEditingController());

    final result = await showDialog<List<String>>(context: context, builder: (_) => AlertDialog(

      title: const Text('Paradas múltiplas'),

      content: StatefulBuilder(builder: (context, setDialogState) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

        for (int i = 0; i < controllers.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[i], decoration: InputDecoration(labelText: 'Parada ${i + 1}', suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: controllers.length > 1 ? () { controllers[i].clear(); } : null)))),

        if (controllers.length < 4) TextButton.icon(onPressed: () { controllers.add(TextEditingController()); setDialogState(() {}); }, icon: const Icon(Icons.add), label: const Text('Adicionar parada')),

      ]))),

      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, controllers.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList()), child: const Text('Salvar'))],

    ));

    // O diálogo ainda pode estar desmontando quando showDialog retorna.
    // Adiar o dispose evita o erro do Flutter `dependents.isEmpty`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) { c.dispose(); }
    });

    if (result == null || !mounted) return;

    final parsed = <Map<String, dynamic>>[];

    for (final address in result) {

      final point = await _routeService.searchDestination(address);

      if (point == null) { _showMessage('Não foi possível localizar a parada: $address'); return; }

      parsed.add({'address': address, 'latitude': point.latitude, 'longitude': point.longitude});

    }

    setState(() { rideStops..clear()..addAll(parsed); });

  }

  // ============================================================

  // CONFIRMAR CORRIDA

  // ============================================================

Future<void> _confirmRide() async {

  if (confirmingRide) {

    return;

  }

  // ==========================================================

  // DESTINO

  // ==========================================================

  final String destinationText =

      destinationController.text.trim();

  if (destinationText.isEmpty) {

    _showMessage(

      'Digite um destino antes de continuar.',

    );

    return;

  }

  // ==========================================================

  // PESQUISAR DESTINO SE NECESSÁRIO

  // ==========================================================

  if (selectedDestination == null) {

    final bool found =

        await _searchDestination();

    if (!found) {

      return;

    }

  }

  if (!mounted) {

    return;

  }

  // ==========================================================

  // LOCALIZAÇÃO

  // ==========================================================

  if (loadingLocation) {

    _showMessage(

      'Obtendo sua localização...',

    );

    return;

  }

  if (currentLocation == null) {

    _showMessage(

      'Não foi possível obter sua localização.',

    );

    return;

  }

  // ==========================================================

  // ROTA

  // ==========================================================

  if (calculatingRoute) {

    _showMessage(

      'Aguarde o cálculo da rota.',

    );

    return;

  }

  // ==========================================================

  // CALCULAR PREÇO

  // ==========================================================

  if (fareResult == null ||

      estimatedPrice == null) {

    await _calculateEstimatedFare();

  }

  if (!mounted) {

    return;

  }

  // ==========================================================

  // VERIFICAR PREÇO

  // ==========================================================

  if (fareResult == null ||

      estimatedPrice == null) {

    _showMessage(

      'Não foi possível calcular o valor.',

    );

    return;

  }

  // ==========================================================

  // CONFIRMANDO CORRIDA

  // ==========================================================

  setState(() {

    confirmingRide = true;

  });

  try {

    // ========================================================

    // USUÁRIO LOGADO

    // ========================================================

    final String? userIdString =

        await AuthService.getUserId();

    if (userIdString == null ||

        userIdString.trim().isEmpty) {

      if (mounted) {

        setState(() {

          confirmingRide = false;

        });

        _showMessage(

          'Sua sessão não foi encontrada. Faça login novamente.',

        );

      }

      return;

    }

    final int? userId =

        int.tryParse(userIdString.trim());

    if (userId == null || userId <= 0) {

      if (mounted) {

        setState(() {

          confirmingRide = false;

        });

        _showMessage(

          'ID do usuário inválido. Faça login novamente.',

        );

      }

      return;

    }

    // ========================================================

    // DADOS DA CORRIDA

    // ========================================================
final double distance =
    distanceKm ?? fareResult!.distanceKm;

final double duration =
    estimatedMinutes ?? 0;

final double baseFare =
    fareResult!.baseFare;

final double farePerKm =
    fareResult?.pricePerKm ?? 0.0;

final double distanceFare =
    farePerKm * distance;

final double calculatedAdditional =
    fareResult!.total -
    baseFare -
    distanceFare;

final double additionalFee =
    calculatedAdditional > 0
        ? calculatedAdditional
        : 0;
    // ========================================================

    // CRIAR CORRIDA

    // ========================================================

    final result =

        await ApiService.createRide(

      userId: userId,

      rideType: rideType,

      originAddress:

          originController.text.trim().isEmpty

              ? 'Minha localização atual'

              : originController.text.trim(),

      // Sempre envia a origem efetivamente selecionada/confirmada.
      // Isso evita que uma posição GPS antiga substitua o ponto escolhido.
      originLatitude:

          (selectedOrigin ?? currentLocation)!.latitude,

      originLongitude:

          (selectedOrigin ?? currentLocation)!.longitude,

      destinationAddress:

          destinationController.text.trim(),

      destinationLatitude:

          selectedDestination!.latitude,

      destinationLongitude:

          selectedDestination!.longitude,

      distanceKm:

          distance,

      durationMinutes:

          duration,

      baseFare:

          baseFare,

      distanceFare:

          distanceFare,

      additionalFee:

          additionalFee,

      discount:

          0,

      totalFare:

          estimatedPrice!,

      scheduledAt: scheduledAt,

      passengerName: passengerName,

      passengerPhone: passengerPhone,

      favoriteDriverId: favoriteDriverId,

      stops: rideStops.isEmpty ? null : rideStops,

    );

    if (!mounted) {

      return;

    }

    // ========================================================

    // ERRO AO CRIAR

    // ========================================================

    if (result['success'] != true) {

      setState(() {

        confirmingRide = false;

      });

      _showMessage(

        result['message']?.toString() ??

            'Não foi possível criar a corrida.',

      );

      return;

    }

    // ========================================================

    // PEGAR ID DA CORRIDA

    // ========================================================

    dynamic rideIdValue;

    final dynamic rideData =

        result['ride'];

    if (rideData is Map) {

      rideIdValue =

          rideData['id'];

    }

    rideIdValue ??=

        result['ride_id'];

    final int? rideId =

        int.tryParse(

      rideIdValue?.toString() ?? '',

    );

    if (rideId == null || rideId <= 0) {

      setState(() {

        confirmingRide = false;

      });

      _showMessage(

        'A corrida foi criada, mas o ID não foi retornado pela API.',

      );

      return;

    }

    // ========================================================

    // SUCESSO

    // ========================================================

    final dynamic createdRide = result['ride'];

    final double finalRidePrice = createdRide is Map

        ? (double.tryParse(createdRide['total_fare']?.toString() ?? '') ?? estimatedPrice!)

        : estimatedPrice!;

    setState(() {

      confirmingRide = false;

    });

    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder: (_) =>

            SearchingDriverScreen(

          rideId: rideId,

          rideType: rideType,

          ridePrice: finalRidePrice,

        ),

      ),

    );

  } catch (e) {

    debugPrint(

      'Erro ao criar corrida: $e',

    );

    if (!mounted) {

      return;

    }

    setState(() {

      confirmingRide = false;

    });

    _showMessage(

      'Não foi possível solicitar a corrida.',

    );

  }

}

  // ============================================================

  // MENSAGEM

  // ============================================================

  void _showMessage(

    String message,

  ) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)

        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)

        .showSnackBar(

      SnackBar(

        content: Text(message),

        behavior:

            SnackBarBehavior.floating,

      ),

    );

  }

  // ============================================================

  // NOME DO SERVIÇO

  // ============================================================

  String get serviceName {

  switch (rideType) {
  case 'carro':
    return 'Carro';
    
case 'delivery_moto':
  return 'Moto Express';

case 'delivery_bicicleta':
  return 'Delivery Bicicleta';

  case 'viagem':
    return 'Viagem';

  default:
    return 'Mototáxi';
}
  }

  // ============================================================

  // ÍCONE DO SERVIÇO

  // ============================================================

  IconData get serviceIcon {

    switch (rideType) {

      case 'carro':

        return Icons.directions_car;

      case 'delivery':

        return Icons.two_wheeler;

      case 'viagem':

        return Icons.directions_car_filled;

      default:

        return Icons.two_wheeler;

    }

  }

  // ============================================================

  // COR DO SERVIÇO

  // ============================================================

  Color get serviceColor {

    switch (rideType) {

      case 'carro':

        return Colors.indigo;

      case 'delivery':

        return Colors.blue;

      case 'viagem':

        return Colors.deepOrange;

      default:

        return AppColors.primary;

    }

  }

  // ============================================================

  // NOME DO PAGAMENTO

  // ============================================================

  String _paymentName() {

    switch (payment) {

      case 'pix':

        return 'PIX';

      case 'cash':

        return 'Dinheiro';

      case 'card':

        return 'Cartão';

      default:

        return payment;

    }

  }

  // ============================================================

  // BUILD

  // ============================================================

  @override

  Widget build(

    BuildContext context,

  ) {

    final fare = fareResult;

    return Scaffold(

      backgroundColor:

          AppColors.background,

      appBar: AppBar(

        title: const Text(

          'Solicitar Corrida',

        ),

        centerTitle: true,

        backgroundColor:

            AppColors.background,

        elevation: 0,

      ),

      body: SingleChildScrollView(

        physics:

            const BouncingScrollPhysics(),

        padding:

            const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:

              CrossAxisAlignment.start,

          children: [

            // ==================================================

            // SERVIÇO

            // ==================================================

            _buildServiceHeader(),

            const SizedBox(

              height: 20,

            ),

            // ==================================================

            // ORIGEM

            // ==================================================

            AddressSearchField(
              controller: originController,
              icon: Icons.my_location,
              hint: 'Rua, bairro, número ou endereço de partida',
              nearby: currentLocation,
              onSelected: (result) {
                setState(() {
                  selectedOrigin = result.location;
                  currentLocation = result.location;
                  locationError = null;
                  fareResult = null;
                  distanceKm = null;
                  estimatedPrice = null;
                  estimatedMinutes = null;
                });
              },
            ),

            const SizedBox(

              height: 10,

            ),

            SizedBox(

              width: double.infinity,

              height: 48,

              child: OutlinedButton.icon(

                onPressed: _searchOrigin,

                icon: const Icon(Icons.search),

                label: const Text('Buscar endereço de partida'),

                style: OutlinedButton.styleFrom(

                  foregroundColor: AppColors.primary,

                  side: BorderSide(

                    color: AppColors.primary.withOpacity(.35),

                  ),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(15),

                  ),

                ),

              ),

            ),

            const SizedBox(

              height: 20,

            ),

            // ==================================================

            // DESTINO

            // ==================================================

            AddressSearchField(
              controller: destinationController,
              icon: Icons.location_on,
              hint: 'Rua, bairro, número ou endereço de destino',
              nearby: currentLocation,
              onSelected: (result) {
                setState(() {
                  selectedDestination = result.location;
                  destinationError = null;
                  fareResult = null;
                  distanceKm = null;
                  estimatedPrice = null;
                  estimatedMinutes = null;
                });

                if (currentLocation != null) {
                  _calculateEstimatedFare();
                }
              },
            ),

            const SizedBox(

              height: 12,

            ),

            // ==================================================

            // BOTÃO PESQUISAR DESTINO

            // ==================================================

            SizedBox(

              width: double.infinity,

              height: 52,

              child:

                  ElevatedButton.icon(

                onPressed:

                    searchingDestination

                        ? null

                        : _searchDestination,

                icon:

                    searchingDestination

                        ? const SizedBox(

                            width: 20,

                            height: 20,

                            child:

                                CircularProgressIndicator(

                              strokeWidth:

                                  2.2,

                              color:

                                  Colors.white,

                            ),

                          )

                        : const Icon(

                            Icons.search,

                          ),

                label: Text(

                  searchingDestination

                      ? 'Pesquisando destino...'

                      : 'Selecionar destino',

                ),

                style:

                    ElevatedButton.styleFrom(

                  backgroundColor:

                      AppColors.primary,

                  foregroundColor:

                      Colors.white,

                  shape:

                      RoundedRectangleBorder(

                    borderRadius:

                        BorderRadius.circular(

                      16,

                    ),

                  ),

                ),

              ),

            ),

            // ==================================================

            // ERRO DESTINO

            // ==================================================

            if (destinationError != null) ...[

              const SizedBox(

                height: 10,

              ),

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

                      Colors.red.withOpacity(

                    .06,

                  ),

                  borderRadius:

                      BorderRadius.circular(

                    14,

                  ),

                  border:

                      Border.all(

                    color:

                        Colors.red.withOpacity(

                      .15,

                    ),

                  ),

                ),

                child: Row(

                  children: [

                    const Icon(

                      Icons.error_outline,

                      color:

                          Colors.red,

                    ),

                    const SizedBox(

                      width: 10,

                    ),

                    Expanded(

                      child: Text(

                        destinationError!,

                        style:

                            const TextStyle(

                          color:

                              Colors.red,

                          fontSize: 13,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ],

            // ==================================================

            // DESTINO ENCONTRADO

            // ==================================================

            if (selectedDestination !=

                null) ...[

              const SizedBox(

                height: 12,

              ),

              _buildSelectedDestination(),

            ],

            const SizedBox(

              height: 25,

            ),

            // ==================================================

            // TIPO

            // ==================================================

            const Text(

              'Tipo de Serviço',

              style: TextStyle(

                fontSize: 22,

                fontWeight:

                    FontWeight.bold,

              ),

            ),

            const SizedBox(

              height: 18,

            ),

            RideTypeCard(

              title: 'Mototáxi',

              subtitle:

                  'Chegada rápida',

              icon:

                  Icons.two_wheeler,

              value: 'mototaxi',

              selectedValue:

                  rideType,

              onChanged:

                  _changeRideType,

            ),

            const SizedBox(

              height: 15,

            ),

            RideTypeCard(

              title: 'Carro',

              subtitle:

                  'Conforto e segurança',

              icon:

                  Icons.directions_car,

              value: 'carro',

              selectedValue:

                  rideType,

              onChanged:

                  _changeRideType,

            ),

            const SizedBox(

              height: 15,

            ),

            if (distanceKm != null &&

                distanceKm! > FareService.longDistanceLimitKm) ...[

              RideTypeCard(

                title: 'Viagem',

                subtitle:

                    'Acima de ${FareService.longDistanceLimitKm.toStringAsFixed(0)} km • tarifa especial',

                icon:

                    Icons.directions_car_filled,

                value: 'viagem',

                selectedValue:

                    rideType,

                onChanged:

                    _changeRideType,

              ),

              const SizedBox(

                height: 15,

              ),

            ],

            RideTypeCard(

              title: 'Moto Express',

              subtitle:

                  'Entrega rápida',

              icon:

                  Icons.two_wheeler,

              value:'delivery_moto',

              selectedValue:

                  rideType,

              onChanged:

                  _changeRideType,

            ),

            const SizedBox(

              height: 30,

            ),

            // ==================================================

            // LOCALIZAÇÃO

            // ==================================================

            if (loadingLocation)

              _buildLoadingCard()

            else if (locationError != null)

              _buildLocationError()

            else

              _buildLocationReady(),

            const SizedBox(

              height: 20,

            ),

            // ==================================================

            // PREÇO

            // ==================================================

            if (calculatingRoute)

              _buildCalculatingCard()

            else if (fare != null)

              PriceCard(

                price: fare.total,

              )

            else

              _buildNoRouteCard(),

            const SizedBox(

              height: 25,

            ),

            // ==================================================

            // DETALHAMENTO

            // ==================================================

            if (fare != null)

              _buildFareDetails(fare),

            const SizedBox(

              height: 25,

            ),

            // ==================================================

            // MOTOGO+

            // ==================================================

            _buildPlusOptions(),

            const SizedBox(height: 25),

            // ==================================================

            // PAGAMENTO

            // ==================================================

            PaymentCard(

              selectedMethod:

                  payment,

              onChanged:

                  _changePayment,

            ),

            const SizedBox(

              height: 25,

            ),

            // ==================================================

            // RESUMO

            // ==================================================

            if (fare != null &&

                estimatedMinutes != null)

              _buildSummary(fare),

            const SizedBox(

              height: 30,

            ),

            // ==================================================

            // CONFIRMAR

            // ==================================================

            ConfirmButton(

              onPressed:

                  _confirmRide,

              loading:

                  confirmingRide,

            ),

            const SizedBox(

              height: 40,

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // CABEÇALHO SERVIÇO

  // ============================================================

  Widget _buildServiceHeader() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(16),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(18),

        boxShadow: [

          BoxShadow(

            color:

                Colors.black.withOpacity(.04),

            blurRadius: 10,

            offset:

                const Offset(0, 4),

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

              color: serviceColor

                  .withOpacity(.10),

              borderRadius:

                  BorderRadius.circular(14),

            ),

            child: Icon(

              serviceIcon,

              color:

                  serviceColor,

              size: 26,

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

                  'Serviço selecionado',

                  style: TextStyle(

                    color: Colors.grey,

                    fontSize: 12,

                  ),

                ),

                const SizedBox(

                  height: 3,

                ),

                Text(

                  serviceName,

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

        ],

      ),

    );

  }

  Widget _buildPlusOptions() {

    return Card(

      margin: EdgeInsets.zero,

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const Text('MotoGo+ nesta corrida', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),

          const SizedBox(height: 10),

          Wrap(spacing: 8, runSpacing: 8, children: [

            OutlinedButton.icon(onPressed: () => _pickPoint(origin: true), icon: const Icon(Icons.pin_drop), label: const Text('Confirmar partida')),

            OutlinedButton.icon(onPressed: () => _pickPoint(origin: false), icon: const Icon(Icons.location_on), label: const Text('Confirmar destino')),

            OutlinedButton.icon(onPressed: _configurePassenger, icon: const Icon(Icons.person_add_alt_1), label: Text(passengerName == null ? 'Outra pessoa' : passengerName!)),

            OutlinedButton.icon(onPressed: _configureSchedule, icon: const Icon(Icons.calendar_month), label: Text(scheduledAt == null ? 'Agendar' : 'Agendado')),

            OutlinedButton.icon(onPressed: _chooseFavoriteDriver, icon: const Icon(Icons.star), label: Text(favoriteDriverName == null ? 'Motorista favorito' : favoriteDriverName!)),

            OutlinedButton.icon(onPressed: _configureStops, icon: const Icon(Icons.alt_route), label: Text(rideStops.isEmpty ? 'Paradas' : '${rideStops.length} paradas')),

          ]),

          if (scheduledAt != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('📅 $scheduledAt')),

          if (rideStops.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('📍 ${rideStops.length} parada(s) adicionada(s)')),

        ]),

      ),

    );

  }

  // ============================================================

  // DESTINO SELECIONADO

  // ============================================================

  Widget _buildSelectedDestination() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(15),

      decoration:

          BoxDecoration(

        color:

            Colors.green.withOpacity(.06),

        borderRadius:

            BorderRadius.circular(18),

        border:

            Border.all(

          color:

              Colors.green.withOpacity(.18),

        ),

      ),

      child: Row(

        children: [

          const Icon(

            Icons.location_on,

            color:

                Colors.green,

          ),

          const SizedBox(

            width: 10,

          ),

          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                const Text(

                  'Destino selecionado',

                  style: TextStyle(

                    color: Colors.grey,

                    fontSize: 11,

                  ),

                ),

                const SizedBox(

                  height: 3,

                ),

                Text(

                  destinationController

                      .text

                      .trim(),

                  maxLines: 2,

                  overflow:

                      TextOverflow.ellipsis,

                  style:

                      const TextStyle(

                    fontWeight:

                        FontWeight.w600,

                    fontSize: 14,

                  ),

                ),

              ],

            ),

          ),

          const Icon(

            Icons.check_circle,

            color:

                Colors.green,

          ),

        ],

      ),

    );

  }

  // ============================================================

  // LOADING LOCALIZAÇÃO

  // ============================================================

  Widget _buildLoadingCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(16),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(18),

      ),

      child: const Row(

        children: [

          SizedBox(

            width: 20,

            height: 20,

            child:

                CircularProgressIndicator(

              strokeWidth: 2,

            ),

          ),

          SizedBox(

            width: 12,

          ),

          Text(

            'Obtendo sua localização...',

          ),

        ],

      ),

    );

  }

  // ============================================================

  // LOCALIZAÇÃO OK

  // ============================================================

  Widget _buildLocationReady() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(15),

      decoration:

          BoxDecoration(

        color:

            Colors.green.withOpacity(.08),

        borderRadius:

            BorderRadius.circular(18),

        border:

            Border.all(

          color:

              Colors.green.withOpacity(.15),

        ),

      ),

      child: const Row(

        children: [

          Icon(

            Icons.my_location,

            color:

                Colors.green,

          ),

          SizedBox(

            width: 10,

          ),

          Expanded(

            child: Text(

              'Sua localização foi encontrada.',

              style: TextStyle(

                fontWeight:

                    FontWeight.w600,

              ),

            ),

          ),

          Icon(

            Icons.check_circle,

            color:

                Colors.green,

          ),

        ],

      ),

    );

  }

  // ============================================================

  // ERRO LOCALIZAÇÃO

  // ============================================================

  Widget _buildLocationError() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(15),

      decoration:

          BoxDecoration(

        color:

            Colors.orange.withOpacity(.08),

        borderRadius:

            BorderRadius.circular(18),

        border:

            Border.all(

          color:

              Colors.orange.withOpacity(.20),

        ),

      ),

      child: Row(

        children: [

          const Icon(

            Icons.location_off,

            color:

                Colors.orange,

          ),

          const SizedBox(

            width: 10,

          ),

          const Expanded(

            child: Text(

              'Não foi possível obter sua localização.',

              style: TextStyle(

                fontWeight:

                    FontWeight.w600,

              ),

            ),

          ),

          IconButton(

            onPressed:

                _loadRealLocation,

            icon:

                const Icon(

              Icons.refresh,

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // CALCULANDO ROTA

  // ============================================================

  Widget _buildCalculatingCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(20),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

      ),

      child: const Row(

        children: [

          SizedBox(

            width: 22,

            height: 22,

            child:

                CircularProgressIndicator(

              strokeWidth: 2,

            ),

          ),

          SizedBox(

            width: 14,

          ),

          Expanded(

            child: Text(

              'Calculando rota e valor da corrida...',

              style: TextStyle(

                fontWeight:

                    FontWeight.w500,

              ),

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // SEM ROTA

  // ============================================================

  Widget _buildNoRouteCard() {

    String message;

    if (destinationController

        .text

        .trim()

        .isEmpty) {

      message =

          'Digite um destino para calcular a rota e o valor.';

    } else if (selectedDestination ==

        null) {

      message =

          'Clique em "Selecionar destino" para localizar o destino.';

    } else {

      message =

          'Aguardando cálculo da rota...';

    }

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(18),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(20),

      ),

      child: Row(

        children: [

          const Icon(

            Icons.route_outlined,

            color:

                Colors.grey,

          ),

          const SizedBox(

            width: 12,

          ),

          Expanded(

            child: Text(

              message,

              style:

                  const TextStyle(

                color:

                    Colors.grey,

              ),

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // DETALHAMENTO DA TARIFA

  // ============================================================

  Widget _buildFareDetails(

    FareResult fare,

  ) {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(18),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(20),

      ),

      child: Column(

        children: [

          _summaryRow(

            'Taxa base',

            FareService.formatPrice(

              fare.baseFare,

            ),

          ),

          const SizedBox(

            height: 10,

          ),

          _summaryRow(

            'Distância',

            '${fare.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',

          ),

          const SizedBox(

            height: 10,

          ),

          _summaryRow(

            'Tarifa por km',

            FareService.formatPrice(

              fare.pricePerKm,

            ),

          ),

          const Divider(

            height: 25,

          ),

          _summaryRow(

            'Total estimado',

            FareService.formatPrice(

              fare.total,

            ),

            bold: true,

          ),

        ],

      ),

    );

  }

  // ============================================================

  // RESUMO

  // ============================================================

  Widget _buildSummary(

    FareResult fare,

  ) {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(18),

      decoration:

          BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(20),

      ),

      child: Column(

        children: [

          _infoRow(

            Icons.route,

            'Distância',

            '${fare.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',

          ),

          const SizedBox(

            height: 12,

          ),

          _infoRow(

            Icons.access_time,

            'Tempo estimado',

            '${estimatedMinutes!.ceil()} min',

          ),

          const SizedBox(

            height: 12,

          ),

          _infoRow(

            Icons.payment,

            'Pagamento',

            _paymentName(),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // LINHA RESUMO

  // ============================================================

  Widget _summaryRow(

    String title,

    String value, {

    bool bold = false,

  }) {

    return Row(

      mainAxisAlignment:

          MainAxisAlignment.spaceBetween,

      children: [

        Text(

          title,

          style: TextStyle(

            color: bold

                ? Colors.black

                : Colors.grey,

            fontWeight: bold

                ? FontWeight.bold

                : FontWeight.normal,

          ),

        ),

        Text(

          value,

          style: TextStyle(

            fontSize:

                bold ? 16 : 14,

            fontWeight: bold

                ? FontWeight.bold

                : FontWeight.w600,

          ),

        ),

      ],

    );

  }

  // ============================================================

  // INFORMAÇÃO

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

                const TextStyle(

              color:

                  Colors.grey,

            ),

          ),

        ),

        Text(

          value,

          style:

              const TextStyle(

            fontWeight:

                FontWeight.bold,

          ),

        ),

      ],

    );

  }

}