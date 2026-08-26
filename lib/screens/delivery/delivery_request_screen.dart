import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/colors.dart';

import '../../widgets/custom_appbar.dart';

import '../../services/fare_service.dart';

import '../../services/location_service.dart';

import '../../services/route_service.dart';

import '../../services/api_service.dart';

import '../../services/auth_service.dart';

import '../../widgets/address_search_field.dart';

import '../client/ride/searching_driver_screen.dart';

import '../maps/point_picker_screen.dart';

class DeliveryRequestScreen extends StatefulWidget {

  /// Abre o fluxo já selecionado em Moto Express ou Bike Express.
  final String initialDeliveryType;
  final bool allowPedestrian;

  const DeliveryRequestScreen({

    super.key,
    this.initialDeliveryType = 'moto',
    this.allowPedestrian = true,

  });

  @override

  State<DeliveryRequestScreen> createState() =>

      _DeliveryRequestScreenState();

}

class _DeliveryRequestScreenState

    extends State<DeliveryRequestScreen> {

  // ============================================================

  // MODALIDADE

  // ============================================================

  late String deliveryType;

  bool get pedestrianAvailable => widget.allowPedestrian;

  @override
  void initState() {
    super.initState();

    final requestedType = widget.initialDeliveryType.trim().toLowerCase();
    deliveryType = requestedType == 'bicicleta'
        ? 'bicicleta'
        : requestedType == 'pedestre' || requestedType == 'a_pe'
            ? 'pedestre'
            : 'moto';

    FareService.loadFromApi();

    originNumberController.addListener(_onOriginNumberChanged);
    destinationNumberController.addListener(_onDestinationNumberChanged);
    originController.addListener(_onOriginAddressChanged);
    destinationController.addListener(_onDestinationAddressChanged);

    // Igual ao fluxo de Mototáxi: a coleta começa pela localização atual.
    // O usuário ainda pode trocar a coleta por um endereço manualmente.
    _initializeDeliveryLocation();
  }

  // ============================================================

  // ENDEREÇOS

  // ============================================================

  final TextEditingController originController =

      TextEditingController();

  final TextEditingController destinationController =

      TextEditingController();

  final TextEditingController originNumberController = TextEditingController();

  final TextEditingController originComplementController = TextEditingController();

  final TextEditingController originReferenceController = TextEditingController();

  final TextEditingController destinationNumberController = TextEditingController();

  final TextEditingController destinationComplementController = TextEditingController();

  final TextEditingController destinationReferenceController = TextEditingController();

  // ============================================================

  // DESCRIÇÃO

  // ============================================================

  final TextEditingController descriptionController =

      TextEditingController();

  // ============================================================

  // PAGAMENTO

  // ============================================================

  String payment = 'pix';

  // ============================================================

  // PREÇO

  // ============================================================

  double price = 12.00;

  // ============================================================

  // DISTÂNCIA DE TESTE

  // ============================================================

  double distanceKm = 0.0;

  LatLng? originPosition;

  LatLng? destinationPosition;

  bool originPointConfirmedByMap = false;
  double? originAccuracyMeters;

  bool destinationPointConfirmedByMap = false;
  bool _updatingAddressFields = false;

  double durationMinutes = 0.0;

  bool loadingRoute = false;

  bool sending = false;

  final LocationService _locationService = LocationService();

  final RouteService _routeService = RouteService();



  void _onOriginAddressChanged() {
    if (_updatingAddressFields) return;
    final text = originController.text.trim();
    if (text.isEmpty || text == 'Minha localização atual') return;
    // Se o usuário começou a editar a coleta, o GPS/ponto anterior deixa
    // de ser a fonte oficial e será resolvido pelo endereço digitado.
    if (originPointConfirmedByMap || originPosition != null) {
      originPointConfirmedByMap = false;
      originPosition = null;
      distanceKm = 0.0;
      durationMinutes = 0.0;
      if (mounted) setState(() {});
    }
  }

  void _onDestinationAddressChanged() {
    if (_updatingAddressFields) return;
    // Qualquer edição invalida o ponto anterior. Isso impede o bug em que
    // a origem e o destino acabavam enviados com exatamente as mesmas
    // coordenadas.
    if (destinationPointConfirmedByMap || destinationPosition != null) {
      destinationPointConfirmedByMap = false;
      destinationPosition = null;
      distanceKm = 0.0;
      durationMinutes = 0.0;
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeDeliveryLocation() async {
    await _useCurrentLocationForOrigin(showError: false);
  }

  void _onOriginNumberChanged() {
    if (_updatingAddressFields) return;
    if (originPointConfirmedByMap &&
        originNumberController.text.trim().isNotEmpty) {
      originPointConfirmedByMap = false;
    }
  }

  void _onDestinationNumberChanged() {
    if (_updatingAddressFields) return;
    if (destinationPointConfirmedByMap &&
        destinationNumberController.text.trim().isNotEmpty) {
      destinationPointConfirmedByMap = false;
    }
  }

  @override

  void dispose() {

    originNumberController.removeListener(_onOriginNumberChanged);

    destinationNumberController.removeListener(_onDestinationNumberChanged);
    originController.removeListener(_onOriginAddressChanged);
    destinationController.removeListener(_onDestinationAddressChanged);

    originController.dispose();

    destinationController.dispose();

    originNumberController.dispose();

    originComplementController.dispose();

    originReferenceController.dispose();

    destinationNumberController.dispose();

    destinationComplementController.dispose();

    destinationReferenceController.dispose();

    descriptionController.dispose();

    super.dispose();

  }

  Future<void> _useCurrentLocationForOrigin({bool showError = true}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (showError) _showMessage('Ative o GPS para usar sua localização atual.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showError) _showMessage('Permita o acesso à localização para usar o GPS.');
        return;
      }

      Position? bestPosition;

      for (var attempt = 0; attempt < 5; attempt++) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );

        if (bestPosition == null ||
            position.accuracy < bestPosition.accuracy) {
          bestPosition = position;
        }

        if (position.accuracy <= 15) break;

        if (attempt < 2) {
          await Future<void>.delayed(
            const Duration(milliseconds: 700),
          );
        }
      }

      if (bestPosition == null) {
        if (showError) _showMessage('Não foi possível obter sua localização.');
        return;
      }

      debugPrint(
        'GPS coleta: ${bestPosition.latitude}, '
        '${bestPosition.longitude} | precisão: '
        '${bestPosition.accuracy.toStringAsFixed(1)} m',
      );

      if (!mounted) return;

      setState(() {
        originPosition = LatLng(
          bestPosition!.latitude,
          bestPosition.longitude,
        );
        originPointConfirmedByMap = true;
        originAccuracyMeters = bestPosition.accuracy;
        originController.text = 'Minha localização atual';
        originNumberController.clear();
        originComplementController.clear();
        originReferenceController.clear();
        distanceKm = 0.0;
        durationMinutes = 0.0;
      });

      // Se o destino já estiver preenchido, calcula imediatamente.
      if (destinationPosition != null) {
        await _calculatePrice();
      }
    } catch (e) {
      debugPrint('Erro ao obter GPS da coleta: $e');
      if (mounted) {
        _showMessage(
          'Não foi possível obter sua localização. Verifique o GPS.',
        );
      }
    }
  }

  Future<void> _searchOriginAddress() async {
    final query = originController.text.trim();
    if (query.isEmpty || query == 'Minha localização atual') {
      _showMessage('Digite o endereço de coleta para pesquisar.');
      return;
    }

    final address = _geocodingAddress(
      query,
      originNumberController.text,
    );

    try {
      final result = await _routeService.searchDestination(
        address,
        nearby: originPosition,
      );
      if (!mounted) return;
      if (result == null) {
        _showMessage('Coleta não encontrada. Informe rua, número, bairro e cidade.');
        return;
      }

      setState(() {
        originPosition = result;
        originPointConfirmedByMap = true;
        distanceKm = 0.0;
        durationMinutes = 0.0;
      });

      if (destinationPosition != null) await _calculatePrice();
    } catch (e) {
      debugPrint('Erro ao pesquisar coleta: $e');
      if (mounted) _showMessage('Não foi possível pesquisar a coleta.');
    }
  }

  Future<void> _searchDestinationAddress() async {
    final query = destinationController.text.trim();
    if (query.isEmpty) {
      _showMessage('Digite o endereço de destino.');
      return;
    }

    final address = _geocodingAddress(
      query,
      destinationNumberController.text,
    );

    try {
      final result = await _routeService.searchDestination(
        address,
        nearby: originPosition,
        avoidPoint: originPosition,
      );
      if (!mounted) return;
      if (result == null) {
        _showMessage('Destino não encontrado. Informe rua, número, bairro e cidade.');
        return;
      }

      setState(() {
        destinationPosition = result;
        destinationPointConfirmedByMap = true;
        distanceKm = 0.0;
        durationMinutes = 0.0;
      });

      await _calculatePrice();
    } catch (e) {
      debugPrint('Erro ao pesquisar destino: $e');
      if (mounted) _showMessage('Não foi possível pesquisar o destino.');
    }
  }

  Future<void> _pickDeliveryPoint({required bool origin}) async {

    final current = origin ? originPosition : destinationPosition;

    if (current == null) {

      _showMessage('Primeiro pesquise o endereço.');

      return;

    }

    final point = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => PointPickerScreen(

      initialPoint: current,

      title: origin ? 'Confirmar coleta' : 'Confirmar entrega',

    )));

    if (!mounted || point == null) return;

    setState(() {

      if (origin) {

        originPosition = point;

        originPointConfirmedByMap = true;

      } else {

        destinationPosition = point;

        destinationPointConfirmedByMap = true;

      }

    });

    if (originPosition != null && destinationPosition != null) await _calculatePrice();

  }

  // ============================================================

  // CALCULAR PREÇO

  // ============================================================

  Future<void> _calculatePrice() async {

    if (originPosition == null || destinationPosition == null) return;

    final straightDistance = const Distance().as(
      LengthUnit.Meter,
      originPosition!,
      destinationPosition!,
    );

    if (straightDistance < 25) {
      if (mounted) {
        setState(() => loadingRoute = false);
        _showMessage(
          'A coleta e o destino estão no mesmo ponto. Selecione um destino diferente.',
        );
      }
      return;
    }

    setState(() => loadingRoute = true);

    try {

      // Todas as entregas usam o mesmo motor de rota que já está
      // comprovadamente funcionando no Mototáxi/Carro.
      //
      // O tipo de entrega (Moto, Bike ou A pé) continua sendo usado
      // normalmente para tarifa, limite e compatibilidade do entregador,
      // mas não força um perfil externo de roteamento que estava falhando.
      // Assim, endereço -> coordenadas -> rota usa exatamente o fluxo
      // estável já utilizado pelo Mototáxi.
      const routeMode = 'car';

      final route = await _routeService.calculateRoute(
        origin: originPosition!,
        destination: destinationPosition!,
        mode: routeMode,
      );

      if (!mounted) return;

      if (route == null) {

        setState(() => loadingRoute = false);

        _showMessage(
          'Não foi possível encontrar uma rota entre os dois pontos. '
          'Confirme os endereços e tente novamente.',
        );

        return;

      }

      final type = deliveryType == 'bicicleta'
          ? 'delivery_bicicleta'
          : deliveryType == 'pedestre'
              ? 'delivery_pedestre'
              : 'delivery_moto';

      final fare = FareService.calculate(

        distanceKm: route.distanceKm,

        rideType: type,

      );

      setState(() {

        distanceKm = route.distanceKm;

        durationMinutes = route.durationMinutes;

        price = fare.total;

        loadingRoute = false;

      });

    } catch (_) {

      if (!mounted) return;

      setState(() => loadingRoute = false);

      _showMessage('Não foi possível calcular o valor.');

    }

  }

  Future<void> _resolveAddresses() async {

    // Para geocodificação usamos somente o endereço físico.
    // Complemento e referência são informações para o entregador, não
    // fazem parte da busca cartográfica e podem piorar o resultado.
    final originText = _geocodingAddress(
      originController.text,
      originNumberController.text,
    );

    final destinationText = _geocodingAddress(
      destinationController.text,
      destinationNumberController.text,
    );

    final originIsGps =

        originController.text.trim().isEmpty ||

        originController.text.trim() == 'Minha localização atual';

    // Quando o usuário digitou um endereço, não confiamos no ponto

    // aproximado que o autocomplete colocou anteriormente.

    if (!originPointConfirmedByMap && !originIsGps) {

      LatLng? addressContext;

      // Usa o GPS somente como contexto da busca do endereço.

      // Isso ajuda a identificar cidade/UF quando o usuário digita

      // apenas rua + bairro + número.

      try {

        final position =

            await _locationService.getCurrentLocation();

        addressContext = LatLng(

          position.latitude,

          position.longitude,

        );

      } catch (_) {

        addressContext = null;

      }

      final resolvedOrigin =

          await _routeService.searchDestination(

        originText,

        nearby: addressContext,

      );

      if (resolvedOrigin != null) {

        originPosition = resolvedOrigin;

      }

    } else if (originPosition == null && originIsGps) {

      try {

        final position =

            await _locationService.getCurrentLocation();

        originPosition = LatLng(

          position.latitude,

          position.longitude,

        );

      } catch (_) {

        _showMessage(

          'Informe o local de coleta ou permita o GPS.',

        );

        return;

      }

    }

    if (originPosition == null) {

      _showMessage(

        'Local de coleta não encontrado. '

        'Informe rua, número, bairro e cidade.',

      );

      return;

    }

    if (!destinationPointConfirmedByMap &&

        destinationText.trim().isNotEmpty) {

      final resolvedDestination =

          await _routeService.searchDestination(

        destinationText,

        nearby: originPosition,
        avoidPoint: originPosition,

      );

      if (resolvedDestination != null) {

        destinationPosition = resolvedDestination;

      }

    }

    if (destinationPosition == null) {

      _showMessage(

        'Destino não encontrado. '

        'Informe rua, número, bairro e cidade.',

      );

      return;

    }

    await _calculatePrice();

  }

  String _geocodingAddress(String base, String number) {
    final parts = <String>[];
    if (base.trim().isNotEmpty) parts.add(base.trim());
    if (number.trim().isNotEmpty) parts.add(number.trim());
    return parts.join(', ');
  }

  String _composeAddress(

    String base,

    String number,

    String complement,

    String reference,

  ) {

    final parts = <String>[];

    if (base.trim().isNotEmpty) parts.add(base.trim());

    if (number.trim().isNotEmpty) parts.add('Nº ${number.trim()}');

    if (complement.trim().isNotEmpty) parts.add('Complemento: ${complement.trim()}');

    if (reference.trim().isNotEmpty) parts.add('Referência: ${reference.trim()}');

    return parts.join(' • ');

  }

  Widget _addressExtraFields({

    required TextEditingController number,

    required TextEditingController complement,

    required TextEditingController reference,

  }) {

    return Column(

      children: [

        Row(

          children: [

            Expanded(

              child: TextField(

                controller: number,

                keyboardType: TextInputType.number,

                decoration: const InputDecoration(

                  labelText: 'Número',

                  prefixIcon: Icon(Icons.pin_outlined),

                  filled: true,

                  fillColor: Colors.white,

                  border: OutlineInputBorder(borderSide: BorderSide.none),

                ),

              ),

            ),

            const SizedBox(width: 10),

            Expanded(

              child: TextField(

                controller: complement,

                decoration: const InputDecoration(

                  labelText: 'Complemento',

                  prefixIcon: Icon(Icons.home_work_outlined),

                  filled: true,

                  fillColor: Colors.white,

                  border: OutlineInputBorder(borderSide: BorderSide.none),

                ),

              ),

            ),

          ],

        ),

        const SizedBox(height: 10),

        TextField(

          controller: reference,

          decoration: const InputDecoration(

            labelText: 'Referência',

            hintText: 'Ex.: perto da praça',

            prefixIcon: Icon(Icons.flag_outlined),

            filled: true,

            fillColor: Colors.white,

            border: OutlineInputBorder(borderSide: BorderSide.none),

          ),

        ),

      ],

    );

  }

  void _showMessage(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(SnackBar(content: Text(message)));

  }

  // ============================================================

  // SOLICITAR ENTREGA

  // ============================================================

  Future<void> _requestDelivery() async {

    if (sending) return;

    if (destinationController.text.trim().isEmpty) {

      _showMessage('Informe o destino.');

      return;

    }

    if (descriptionController.text.trim().isEmpty) {

      _showMessage('Informe o que será entregue.');

      return;

    }

    // Revalida os endereços antes da rota.

    // O autocomplete pode ter colocado somente o centro da rua.

    await _resolveAddresses();

    if (!mounted ||

        originPosition == null ||

        destinationPosition == null) {

      return;

    }

    if (loadingRoute || distanceKm <= 0) {

      await _calculatePrice();

    }

    if (!mounted || distanceKm <= 0) {

      _showMessage('Não foi possível calcular a rota.');

      return;

    }

    final userId = int.tryParse((await AuthService.getUserId()) ?? '');

    if (userId == null || userId <= 0) {

      _showMessage('Faça login novamente para solicitar a entrega.');

      return;

    }

    if (deliveryType == 'pedestre' && distanceKm > FareService.pedestrianDeliveryMaxKm) {
      _showMessage('Entrega a pé disponível somente até ${FareService.pedestrianDeliveryMaxKm.toStringAsFixed(0)} km.');
      return;
    }

    setState(() => sending = true);

    try {

      final rideType = deliveryType == 'bicicleta'
          ? 'delivery_bicicleta'
          : deliveryType == 'pedestre'
              ? 'delivery_pedestre'
              : 'delivery_moto';

      final fare = FareService.calculate(

        distanceKm: distanceKm,

        rideType: rideType,

      );

      final result = await ApiService.createRide(

        userId: userId,

        rideType: rideType,

        deliveryMode: deliveryType,

        originAddress: originController.text.trim().isEmpty

            ? 'Minha localização atual'

            : _composeAddress(

                originController.text,

                originNumberController.text,

                originComplementController.text,

                originReferenceController.text,

              ),

        originLatitude: originPosition!.latitude,

        originLongitude: originPosition!.longitude,

        destinationAddress: _composeAddress(

          destinationController.text,

          destinationNumberController.text,

          destinationComplementController.text,

          destinationReferenceController.text,

        ),

        destinationLatitude: destinationPosition!.latitude,

        destinationLongitude: destinationPosition!.longitude,

        distanceKm: distanceKm,

        durationMinutes: durationMinutes,

        baseFare: fare.baseFare,

        distanceFare: fare.distanceFare,

        additionalFee: 0,

        discount: 0,

        totalFare: fare.total,

      );

      if (!mounted) return;

      if (result['success'] != true) {

        setState(() => sending = false);

        _showMessage(

          result['message']?.toString() ?? 'Não foi possível solicitar a entrega.',

        );

        return;

      }

      final ride = result['ride'];

      final rideId = ride is Map

          ? int.tryParse(ride['id']?.toString() ?? '')

          : int.tryParse(result['ride_id']?.toString() ?? '');

      if (rideId == null || rideId <= 0) {

        setState(() => sending = false);

        _showMessage('A entrega foi criada, mas o ID não foi retornado.');

        return;

      }

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(

          builder: (_) => SearchingDriverScreen(

            rideId: rideId,

            rideType: rideType,

            ridePrice: fare.total,

          ),

        ),

      );

    } catch (e) {

      if (!mounted) return;

      setState(() => sending = false);

      _showMessage('Erro ao solicitar entrega.');

    }

  }

  // ============================================================

  // FORMATAR PREÇO

  // ============================================================

  String _formatPrice(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

  // ============================================================

  // BUILD

  // ============================================================

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: const CustomAppBar(

        title: 'Enviar encomenda',

      ),

      body: SafeArea(

        child: SingleChildScrollView(

          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(

            20,

            20,

            20,

            40,

          ),

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

              // ==================================================

              // CABEÇALHO

              // ==================================================

              const Text(

                'Delivery',

                style: TextStyle(

                  fontSize: 28,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 8),

              const Text(

                'Envie sua encomenda com segurança e rapidez.',

                style: TextStyle(

                  color: Colors.grey,

                  fontSize: 15,

                ),

              ),

              const SizedBox(height: 28),

              // ==================================================

              // ORIGEM

              // ==================================================

              const Text(

                'Local de coleta',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 10),

              AddressSearchField(

                controller: originController,

                icon: Icons.my_location,

                hint: 'Rua, bairro, número ou endereço de coleta',
                nearby: originPosition ?? destinationPosition,
                avoidPoint: destinationPosition,

                onSelected: (result) {

                  final raw =

                      originController.text.trim();

                  final numberMatch = RegExp(

                    r'\b(?:número|numero|nº|n°|num|n)\s*[:.-]?\s*(\d+[A-Za-z]?)\b',

                    caseSensitive: false,

                  ).firstMatch(raw);

                  final numberFromText =
                      result.houseNumber.isNotEmpty
                          ? result.houseNumber
                          : numberMatch?.group(1);

                  _updatingAddressFields = true;
                  originController.text = result.shortAddress;
                  if (numberFromText != null && numberFromText.isNotEmpty) {
                    originNumberController.text = numberFromText;
                  }
                  _updatingAddressFields = false;

                  setState(() {
                    originPosition = result.location;
                    // Preserve as coordenadas exatas do resultado selecionado.
                    originPointConfirmedByMap = true;
                  });

                },

              ),

              const SizedBox(height: 10),

              _addressExtraFields(

                number: originNumberController,

                complement: originComplementController,

                reference: originReferenceController,

              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _searchOriginAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar endereço de partida'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _useCurrentLocationForOrigin(), icon: const Icon(Icons.my_location), label: const Text('Usar minha localização atual'))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _pickDeliveryPoint(origin: true), icon: const Icon(Icons.pin_drop), label: const Text('Ajustar ponto exato no mapa'))),

              const SizedBox(height: 20),

              // ==================================================

              // DESTINO

              // ==================================================

              const Text(

                'Destino',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 10),

              AddressSearchField(

                controller: destinationController,

                icon: Icons.location_on,

                hint: 'Rua, bairro, número ou endereço de entrega',
                nearby: originPosition ?? destinationPosition,
                avoidPoint: originPosition,

                onSelected: (result) {

                  final raw =

                      destinationController.text.trim();

                  final numberMatch = RegExp(

                    r'\b(?:número|numero|nº|n°|num|n)\s*[:.-]?\s*(\d+[A-Za-z]?)\b',

                    caseSensitive: false,

                  ).firstMatch(raw);

                  final numberFromText =
                      result.houseNumber.isNotEmpty
                          ? result.houseNumber
                          : numberMatch?.group(1);

                  _updatingAddressFields = true;
                  destinationController.text = result.shortAddress;
                  if (numberFromText != null && numberFromText.isNotEmpty) {
                    destinationNumberController.text = numberFromText;
                  }
                  _updatingAddressFields = false;

                  final origin = originPosition;
                  if (origin != null) {
                    final meters = const Distance().as(
                      LengthUnit.Meter,
                      origin,
                      result.location,
                    );
                    if (meters < 25) {
                      setState(() {
                        destinationPosition = null;
                        destinationPointConfirmedByMap = false;
                        distanceKm = 0.0;
                        durationMinutes = 0.0;
                        price = 0.0;
                      });
                      _showMessage(
                        'O destino ficou no mesmo ponto da coleta. '
                        'Escolha outro endereço ou confirme o ponto correto no mapa.',
                      );
                      return;
                    }
                  }

                  setState(() {
                    destinationPosition = result.location;
                    // Preserve as coordenadas exatas do resultado selecionado.
                    destinationPointConfirmedByMap = true;
                  });

                  if (originPosition != null) {
                    _calculatePrice();
                  }

                },

              ),

              const SizedBox(height: 10),

              _addressExtraFields(

                number: destinationNumberController,

                complement: destinationComplementController,

                reference: destinationReferenceController,

              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _searchDestinationAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('Selecionar destino'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _pickDeliveryPoint(origin: false), icon: const Icon(Icons.pin_drop), label: const Text('Confirmar ponto exato no mapa'))),

              const SizedBox(height: 30),

              // ==================================================

              // TIPO DE ENTREGADOR

              // ==================================================

              const Text(

                'Tipo de entrega',

                style: TextStyle(

                  fontSize: 20,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 8),

              const Text(

                'Escolha como sua encomenda será transportada.',

                style: TextStyle(

                  color: Colors.grey,

                ),

              ),

              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = 10.0;
                  final width = (constraints.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(width: width, child: _DeliveryTypeCard(selected: deliveryType == 'moto', icon: Icons.two_wheeler, title: 'Moto', subtitle: 'Mais rápida', color: AppColors.primary, onTap: () { setState(() => deliveryType = 'moto'); _calculatePrice(); })),
                      SizedBox(width: width, child: _DeliveryTypeCard(selected: deliveryType == 'bicicleta', icon: Icons.pedal_bike, title: 'Bike', subtitle: 'Econômica', color: Colors.green, onTap: () { setState(() => deliveryType = 'bicicleta'); _calculatePrice(); })),
                      if (pedestrianAvailable)
                        SizedBox(width: width, child: _DeliveryTypeCard(selected: deliveryType == 'pedestre', icon: Icons.directions_walk, title: 'A pé', subtitle: 'Até 2 km', color: Colors.orange, onTap: () { setState(() => deliveryType = 'pedestre'); _calculatePrice(); })),
                    ],
                  );
                },
              ),

              const SizedBox(height: 30),

              // ==================================================

              // DESCRIÇÃO DA ENCOMENDA

              // ==================================================

              const Text(

                'O que será entregue?',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 10),

              TextField(

                controller:

                    descriptionController,

                maxLines: 3,

                decoration:

                    InputDecoration(

                  hintText:

                      'Ex.: documentos, alimentos, pequena encomenda...',

                  filled: true,

                  fillColor:

                      Colors.white,

                  prefixIcon:

                      const Padding(

                    padding:

                        EdgeInsets.only(

                      bottom: 35,

                    ),

                    child: Icon(

                      Icons.inventory_2_outlined,

                    ),

                  ),

                  border:

                      OutlineInputBorder(

                    borderRadius:

                        BorderRadius.circular(

                      16,

                    ),

                    borderSide:

                        BorderSide.none,

                  ),

                ),

              ),

              const SizedBox(height: 30),

              // ==================================================

              // PAGAMENTO

              // ==================================================

              const Text(

                'Forma de pagamento',

                style: TextStyle(

                  fontSize: 20,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 15),

              _PaymentOption(

                selected:

                    payment == 'pix',

                icon:

                    Icons.pix,

                title:

                    'PIX',

                subtitle:

                    'Pagamento instantâneo',

                onTap: () {

                  setState(() {

                    payment = 'pix';

                  });

                },

              ),

              const SizedBox(height: 10),

              _PaymentOption(

                selected:

                    payment == 'dinheiro',

                icon:

                    Icons.payments_outlined,

                title:

                    'Dinheiro',

                subtitle:

                    'Pagar ao entregador',

                onTap: () {

                  setState(() {

                    payment = 'dinheiro';

                  });

                },

              ),

              const SizedBox(height: 30),

              // ==================================================

              // PREÇO

              // ==================================================

              Container(

                width: double.infinity,

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

                ),

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Estimativa da entrega',

                      style: TextStyle(

                        color: Colors.grey,

                        fontSize: 14,

                      ),

                    ),

                    const SizedBox(height: 8),

                    Row(

                      mainAxisAlignment:

                          MainAxisAlignment

                              .spaceBetween,

                      children: [

                        Text(

                          _formatPrice(

                            price,

                          ),

                          style:

                              const TextStyle(

                            fontSize: 26,

                            fontWeight:

                                FontWeight.bold,

                          ),

                        ),

                        Container(

                          padding:

                              const EdgeInsets

                                  .symmetric(

                            horizontal: 12,

                            vertical: 7,

                          ),

                          decoration:

                              BoxDecoration(

                            color:

                                AppColors.primary

                                    .withOpacity(

                              .10,

                            ),

                            borderRadius:

                                BorderRadius

                                    .circular(

                              20,

                            ),

                          ),

                          child: Text(
                            deliveryType == 'bicicleta'
                                ? '🚲 Bicicleta'
                                : deliveryType == 'pedestre'
                                    ? '🚶 A pé'
                                    : '🏍️ Moto',

                            style:

                                TextStyle(

                              color:

                                  AppColors.primary,

                              fontWeight:

                                  FontWeight.bold,

                            ),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 8),

                    Text(

                      '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km estimados',

                      style: const TextStyle(

                        color: Colors.grey,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 30),

              // ==================================================

              // BOTÃO

              // ==================================================

              SizedBox(

                width: double.infinity,

                height: 56,

                child: ElevatedButton(

                  onPressed:

                      _requestDelivery,

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

                        18,

                      ),

                    ),

                  ),

                  child: const Text(

                    'Solicitar entrega',

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

// =================================================================

// CAMPO DE ENDEREÇO

// =================================================================

class _AddressField

    extends StatelessWidget {

  final TextEditingController controller;

  final IconData icon;

  final String hint;

  const _AddressField({

    required this.controller,

    required this.icon,

    required this.hint,

  });

  @override

  Widget build(

    BuildContext context,

  ) {

    return TextField(

      controller: controller,

      decoration:

          InputDecoration(

        hintText: hint,

        prefixIcon:

            Icon(icon),

        filled: true,

        fillColor:

            Colors.white,

        border:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(

            16,

          ),

          borderSide:

              BorderSide.none,

        ),

      ),

    );

  }

}

// =================================================================

// CARD DE TIPO DE ENTREGA

// =================================================================

class _DeliveryTypeCard

    extends StatelessWidget {

  final bool selected;

  final IconData icon;

  final String title;

  final String subtitle;

  final Color color;

  final VoidCallback onTap;

  const _DeliveryTypeCard({

    required this.selected,

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.color,

    required this.onTap,

  });

  @override

  Widget build(

    BuildContext context,

  ) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius:

            BorderRadius.circular(

          20,

        ),

        child: AnimatedContainer(

          duration:

              const Duration(

            milliseconds: 200,

          ),

          padding:

              const EdgeInsets.all(

            18,

          ),

          decoration:

              BoxDecoration(

            color: selected

                ? color.withOpacity(

                    .10,

                  )

                : Colors.white,

            borderRadius:

                BorderRadius.circular(

              20,

            ),

            border: Border.all(

              color: selected

                  ? color

                  : Colors.transparent,

              width: 2,

            ),

          ),

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment

                    .start,

            children: [

              Container(

                width: 48,

                height: 48,

                decoration:

                    BoxDecoration(

                  color:

                      color.withOpacity(

                    .12,

                  ),

                  borderRadius:

                      BorderRadius.circular(

                    15,

                  ),

                ),

                child: Icon(

                  icon,

                  color: color,

                  size: 26,

                ),

              ),

              const SizedBox(

                height: 14,

              ),

              Text(

                title,

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

                subtitle,

                style:

                    const TextStyle(

                  color: Colors.grey,

                  fontSize: 12,

                ),

              ),

              if (selected) ...[

                const SizedBox(

                  height: 10,

                ),

                Icon(

                  Icons.check_circle,

                  color: color,

                  size: 20,

                ),

              ],

            ],

          ),

        ),

      ),

    );

  }

}

// =================================================================

// PAGAMENTO

// =================================================================

class _PaymentOption

    extends StatelessWidget {

  final bool selected;

  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  const _PaymentOption({

    required this.selected,

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.onTap,

  });

  @override

  Widget build(

    BuildContext context,

  ) {

    return Material(

      color: Colors.white,

      borderRadius:

          BorderRadius.circular(

        18,

      ),

      child: InkWell(

        onTap: onTap,

        borderRadius:

            BorderRadius.circular(

          18,

        ),

        child: Container(

          padding:

              const EdgeInsets.all(

            16,

          ),

          decoration:

              BoxDecoration(

            borderRadius:

                BorderRadius.circular(

              18,

            ),

            border: Border.all(

              color: selected

                  ? AppColors.primary

                  : Colors.transparent,

              width: 2,

            ),

          ),

          child: Row(

            children: [

              Icon(

                icon,

                color:

                    AppColors.primary,

                size: 28,

              ),

              const SizedBox(

                width: 14,

              ),

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment

                          .start,

                  children: [

                    Text(

                      title,

                      style:

                          const TextStyle(

                        fontWeight:

                            FontWeight.bold,

                        fontSize: 15,

                      ),

                    ),

                    const SizedBox(

                      height: 3,

                    ),

                    Text(

                      subtitle,

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

              Icon(

                selected

                    ? Icons.radio_button_checked

                    : Icons.radio_button_off,

                color:

                    selected

                        ? AppColors.primary

                        : Colors.grey,

              ),

            ],

          ),

        ),

      ),

    );

  }

}