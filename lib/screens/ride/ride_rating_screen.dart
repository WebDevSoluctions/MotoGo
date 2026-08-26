import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class RideRatingScreen extends StatefulWidget {
  final String rideType;

  final String driverName;

  final String vehicle;

  final String plate;

  final double ridePrice;

  final int? rideId;

  const RideRatingScreen({
    super.key,
    this.rideType = 'mototaxi',
    this.driverName = 'Motorista',
    this.vehicle = 'Veículo',
    this.plate = '---',
    this.ridePrice = 0.0,
    this.rideId,
  });

  @override
  State<RideRatingScreen> createState() =>
      _RideRatingScreenState();
}

class _RideRatingScreenState
    extends State<RideRatingScreen> {
  int selectedRating = 0;

  final TextEditingController commentController =
      TextEditingController();

  bool sending = false;

  // ============================================================
  // TIPO DE SERVIÇO
  // ============================================================

  bool get isCar {
    return widget.rideType == 'carro';
  }

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

      default:
        return 'Mototáxi';
    }
  }

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
  // ENVIAR AVALIAÇÃO
  // ============================================================

  Future<void> _sendRating() async {
    if (selectedRating == 0) {
      _showMessage('Escolha uma nota antes de continuar.');
      return;
    }

    if (widget.rideId == null) {
      _showMessage('Esta tela não recebeu o ID da corrida.');
      return;
    }

    final userId = int.tryParse((await AuthService.getUserId()) ?? '');
    if (userId == null || userId <= 0) {
      _showMessage('Usuário não identificado. Faça login novamente.');
      return;
    }

    setState(() => sending = true);

    final result = await ApiService.rateRide(
      rideId: widget.rideId!,
      userId: userId,
      rating: selectedRating,
      comment: commentController.text,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => sending = false);
      _showMessage(result['message']?.toString() ?? 'Não foi possível registrar a avaliação.');
      return;
    }

    setState(() => sending = false);
    _showSuccessDialog();
  }

  // ============================================================
  // SUCESSO
  // ============================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),

          contentPadding:
              const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            12,
          ),

          content: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Container(
                width: 70,
                height: 70,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.green
                          .withOpacity(.10),
                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons.check_circle,
                  color:
                      Colors.green,
                  size: 42,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Obrigado!',
                style:
                    TextStyle(
                  fontSize: 23,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sua avaliação foi registrada com sucesso.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),

          actionsPadding:
              const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            15,
          ),

          actions: [
            SizedBox(
              width: double.infinity,

              child:
                  ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  Navigator.popUntil(
                    context,
                    (route) =>
                        route.isFirst,
                  );
                },

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      serviceColor,

                  foregroundColor:
                      Colors.white,

                  elevation: 0,

                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 14,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),

                child:
                    const Text(
                  'Voltar para o início',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ESTRELA
  // ============================================================

  Widget _buildStar(int index) {
    final bool selected =
        index <= selectedRating;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRating = index;
        });
      },

      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 5,
        ),

        child: Icon(
          selected
              ? Icons.star
              : Icons.star_border,

          size: 44,

          color:
              selected
                  ? Colors.amber
                  : Colors.grey.shade400,
        ),
      ),
    );
  }

  // ============================================================
  // TEXTO DA NOTA
  // ============================================================

  String get ratingText {
    switch (selectedRating) {
      case 1:
        return 'Muito ruim';

      case 2:
        return 'Ruim';

      case 3:
        return 'Regular';

      case 4:
        return 'Muito bom';

      case 5:
        return 'Excelente!';

      default:
        return 'Toque nas estrelas para avaliar';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar: AppBar(
        title:
            const Text(
          'Avaliar corrida',
        ),

        centerTitle: true,

        automaticallyImplyLeading:
            false,
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding:
              const EdgeInsets.all(20),

          child:
              Column(
            children: [
              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // ÍCONE
              // ==================================================

              Container(
                width: 80,
                height: 80,

                decoration:
                    BoxDecoration(
                  color:
                      serviceColor
                          .withOpacity(
                    .10,
                  ),

                  shape:
                      BoxShape.circle,
                ),

                child:
                    Icon(
                  serviceIcon,
                  color:
                      serviceColor,
                  size: 42,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // TÍTULO
              // ==================================================

              const Text(
                'Como foi sua corrida?',
                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Avalie sua experiência com $serviceName.',
                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // MOTORISTA
              // ==================================================

              Container(
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
                    22,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black
                              .withOpacity(
                        .04,
                      ),
                      blurRadius:
                          15,
                      offset:
                          const Offset(
                        0,
                        5,
                      ),
                    ),
                  ],
                ),

                child:
                    Column(
                  children: [
                    Container(
                      width: 65,
                      height: 65,

                      decoration:
                          BoxDecoration(
                        color:
                            serviceColor
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
                            serviceColor,
                        size: 34,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      widget.driverName,

                      style:
                          const TextStyle(
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      widget.vehicle,

                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize:
                            13,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Placa ${widget.plate}',

                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize:
                            12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // ESTRELAS
              // ==================================================

              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 22,
                  horizontal: 10,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white,

                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                ),

                child:
                    Column(
                  children: [
                    const Text(
                      'Sua avaliação',

                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                      children: [
                        _buildStar(1),
                        _buildStar(2),
                        _buildStar(3),
                        _buildStar(4),
                        _buildStar(5),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds:
                            200,
                      ),

                      child:
                          Text(
                        ratingText,

                        key:
                            ValueKey(
                          ratingText,
                        ),

                        style:
                            TextStyle(
                          color:
                              selectedRating >
                                      0
                                  ? serviceColor
                                  : Colors.grey,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // COMENTÁRIO
              // ==================================================

              Container(
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
                    TextField(
                  controller:
                      commentController,

                  maxLines:
                      4,

                  maxLength:
                      300,

                  textInputAction:
                      TextInputAction
                          .newline,

                  decoration:
                      InputDecoration(
                    hintText:
                        'Deixe um comentário sobre sua experiência (opcional)',

                    prefixIcon:
                        const Padding(
                      padding:
                          EdgeInsets.only(
                        left: 16,
                        right: 10,
                        top: 15,
                      ),

                      child:
                          Icon(
                        Icons
                            .chat_bubble_outline,
                        color:
                            Colors.grey,
                      ),
                    ),

                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),

                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),

                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            serviceColor,
                      ),
                    ),

                    filled:
                        true,

                    fillColor:
                        Colors.white,

                    contentPadding:
                        const EdgeInsets.all(
                      18,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // VALOR
              // ==================================================

              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(
                  16,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      serviceColor
                          .withOpacity(
                    .07,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),

                child:
                    Row(
                  children: [
                    Icon(
                      Icons
                          .payments_outlined,
                      color:
                          serviceColor,
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    const Expanded(
                      child:
                          Text(
                        'Valor da corrida',
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ),

                    Text(
                      'R\$ ${widget.ridePrice.toStringAsFixed(2).replaceAll('.', ',')}',

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

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // ENVIAR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,

                height:
                    56,

                child:
                    ElevatedButton(
                  onPressed:
                      sending
                          ? null
                          : _sendRating,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        serviceColor,

                    foregroundColor:
                        Colors.white,

                    disabledBackgroundColor:
                        Colors.grey
                            .shade300,

                    elevation:
                        0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),

                  child:
                      sending
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Enviar avaliação',
                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // PULAR
              // ==================================================

              TextButton(
                onPressed:
                    sending
                        ? null
                        : () {
                            Navigator.popUntil(
                              context,
                              (route) =>
                                  route.isFirst,
                            );
                          },

                child:
                    const Text(
                  'Avaliar depois',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    commentController.dispose();

    super.dispose();
  }
}