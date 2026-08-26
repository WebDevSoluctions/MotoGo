import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

class AdminVehiclesScreen extends StatefulWidget {
  const AdminVehiclesScreen({
    super.key,
  });

  @override
  State<AdminVehiclesScreen> createState() =>
      _AdminVehiclesScreenState();
}

class _AdminVehiclesScreenState
    extends State<AdminVehiclesScreen> {
  // ============================================================
  // CORES
  // ============================================================

  static const Color primary =
      Color(0xFF00C985);

  static const Color background =
      Color(0xFFF5F7F6);

  // ============================================================
  // FILTRO
  // ============================================================

  int _selectedFilter = 0;

  final List<String> _filters = [
    'Pendentes',
    'Aprovados',
    'Rejeitados',
    'Todos',
  ];

  // ============================================================
  // ESTADO
  // ============================================================

  bool _loading = true;

  bool _actionLoading = false;

  String? _error;

  List<Map<String, dynamic>> _vehicles = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadVehicles();
  }

  // ============================================================
  // CARREGAR VEÍCULOS
  // ============================================================
Future<void> _loadVehicles() async {
  if (!mounted) {
    return;
  }

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final result =
        await ApiService.getAdminDashboard();

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error =
            result['message']?.toString() ??
                'Não foi possível carregar os veículos.';
      });

      return;
    }

    // ==========================================================
    // PEGAR AS 3 LISTAS QUE A API JÁ ENVIA
    // ==========================================================

    final List<Map<String, dynamic>> vehicles = [];

    // ----------------------------------------------------------
    // PENDENTES
    // ----------------------------------------------------------

    final dynamic pending =
        result['pending_vehicles_list'];

    if (pending is List) {
      for (final item in pending) {
        if (item is Map) {
          vehicles.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    // ----------------------------------------------------------
    // APROVADOS
    // ----------------------------------------------------------

    final dynamic approved =
        result['approved_vehicles_list'];

    if (approved is List) {
      for (final item in approved) {
        if (item is Map) {
          vehicles.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    // ----------------------------------------------------------
    // REJEITADOS
    // ----------------------------------------------------------

    final dynamic rejected =
        result['rejected_vehicles_list'];

    if (rejected is List) {
      for (final item in rejected) {
        if (item is Map) {
          vehicles.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    // ==========================================================
    // SALVAR
    // ==========================================================

    setState(() {
      _vehicles = vehicles;
      _loading = false;
      _error = null;
    });
  } catch (e) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _error =
          'Não foi possível conectar ao servidor.';
    });
  }
}
  // ============================================================
  // CONVERTER MAP
  // ============================================================

  Map<String, dynamic> _map(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return {};
  }

  // ============================================================
  // CONVERTER ID
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  // ============================================================
  // VALOR SEGURO
  // ============================================================

  String _value(
    dynamic value, {
    String fallback = 'Não informado',
  }) {
    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    if (text.isEmpty ||
        text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  // ============================================================
  // AÇÃO DO VEÍCULO
  // ============================================================

  Future<void> _vehicleAction({
    required int vehicleId,
    required String action,
  }) async {
    if (_actionLoading) {
      return;
    }

    final bool approve =
        action == 'approve';

    // ==========================================================
    // CONFIRMAÇÃO
    // ==========================================================

    final bool? confirmed =
        await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text(
            approve
                ? 'Aprovar veículo?'
                : 'Rejeitar veículo?',
          ),

          content: Text(
            approve
                ? 'Deseja realmente aprovar este veículo?'
                : 'Deseja realmente rejeitar este veículo?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },

              child: const Text(
                'Cancelar',
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    approve
                        ? primary
                        : Colors.red,
              ),

              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },

              child: Text(
                approve
                    ? 'Aprovar'
                    : 'Rejeitar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    // ==========================================================
    // ENVIAR PARA API
    // ==========================================================

    if (!mounted) {
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final result =
          await ApiService.adminVehicleAction(
        vehicleId: vehicleId,
        action: action,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        _showMessage(
          result['message']?.toString() ??
              (approve
                  ? 'Veículo aprovado com sucesso.'
                  : 'Veículo rejeitado com sucesso.'),
          success: true,
        );

        await _loadVehicles();
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Não foi possível realizar a ação.',
          success: false,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Erro ao comunicar com o servidor.',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FILTRAR VEÍCULOS
  // ============================================================

  List<Map<String, dynamic>>
      _filteredVehicles() {
    switch (_selectedFilter) {
      // --------------------------------------------------------
      // PENDENTES
      // --------------------------------------------------------

      case 0:
        return _vehicles.where((vehicle) {
          return _status(vehicle) ==
              'pending';
        }).toList();

      // --------------------------------------------------------
      // APROVADOS
      // --------------------------------------------------------

      case 1:
        return _vehicles.where((vehicle) {
          return _status(vehicle) ==
              'approved';
        }).toList();

      // --------------------------------------------------------
      // REJEITADOS
      // --------------------------------------------------------

      case 2:
        return _vehicles.where((vehicle) {
          return _status(vehicle) ==
              'rejected';
        }).toList();

      // --------------------------------------------------------
      // TODOS
      // --------------------------------------------------------

      default:
        return List<Map<String, dynamic>>.from(
          _vehicles,
        );
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _status(
    Map<String, dynamic> vehicle,
  ) {
    return vehicle['status']?.toString()
            .toLowerCase() ??
        vehicle['verification_status']
            ?.toString()
            .toLowerCase() ??
        'pending';
  }

  // ============================================================
  // NOME DO STATUS
  // ============================================================

  String _statusText(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return 'Aprovado';

      case 'rejected':
        return 'Rejeitado';

      default:
        return 'Pendente';
    }
  }

  // ============================================================
  // COR DO STATUS
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      default:
        return const Color(
          0xFFB77900,
        );
    }
  }

  // ============================================================
  // ÍCONE DO TIPO
  // ============================================================

  IconData _vehicleIcon(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'carro':
        return Icons.directions_car;

      case 'bicicleta':
        return Icons.pedal_bike;

      case 'moto':
      default:
        return Icons.two_wheeler;
    }
  }

  // ============================================================
  // NOME DO TIPO
  // ============================================================

  String _vehicleTypeName(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'carro':
        return 'Carro';

      case 'bicicleta':
        return 'Bicicleta';

      case 'moto':
      default:
        return 'Moto';
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
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: background,

        elevation: 0,

        surfaceTintColor:
            Colors.transparent,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),

          onPressed: () {
            Navigator.of(context).pop();
          },
        ),

        title: const Text(
          'Veículos',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Atualizar',

            onPressed:
                _loading
                    ? null
                    : _loadVehicles,

            icon: _loading
                ? const SizedBox(
                    width: 19,
                    height: 19,

                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                  ),
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          _buildHeader(),

          Expanded(
            child:
                RefreshIndicator(
              color: primary,

              onRefresh:
                  _loadVehicles,

              child:
                  _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      color: Colors.white,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Gestão de veículos',

            style: TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Analise os veículos e aprove novos cadastros.',

            style: TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 14,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // ======================================================
          // FILTROS
          // ======================================================

          SizedBox(
            height: 42,

            child: ListView.builder(
              scrollDirection:
                  Axis.horizontal,

              itemCount:
                  _filters.length,

              itemBuilder:
                  (context, index) {
                final bool selected =
                    _selectedFilter ==
                        index;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 8,
                  ),

                  child:
                      GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter =
                            index;
                      });
                    },

                    child:
                        Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 17,
                      ),

                      decoration:
                          BoxDecoration(
                        color: selected
                            ? primary
                            : Colors.grey
                                .shade100,

                        borderRadius:
                            BorderRadius
                                .circular(
                          22,
                        ),
                      ),

                      alignment:
                          Alignment.center,

                      child: Text(
                        _filters[index],

                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.black87,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading &&
        _vehicles.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        children: const [
          SizedBox(
            height: 170,
          ),

          Center(
            child:
                CircularProgressIndicator(
              color: primary,
            ),
          ),

          SizedBox(
            height: 15,
          ),

          Center(
            child: Text(
              'Carregando veículos...',
            ),
          ),
        ],
      );
    }

    if (_error != null &&
        _vehicles.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          20,
        ),

        children: [
          const SizedBox(
            height: 100,
          ),

          _buildError(),
        ],
      );
    }

    final List<Map<String, dynamic>>
        filtered =
        _filteredVehicles();

    if (filtered.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    .45,
          ),

          _buildEmpty(),
        ],
      );
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.all(
        16,
      ),

      itemCount:
          filtered.length,

      itemBuilder:
          (context, index) {
        return Padding(
          padding:
              const EdgeInsets.only(
            bottom: 14,
          ),

          child:
              _buildVehicleCard(
            filtered[index],
          ),
        );
      },
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildVehicleCard(
    Map<String, dynamic> vehicle,
  ) {
    final int vehicleId =
        _toInt(
      vehicle['id'],
    );

    final String status =
        _status(vehicle);

    final String type =
        _value(
      vehicle['vehicle_type'],
      fallback: 'moto',
    );

    final String brand =
        _value(
      vehicle['brand'],
      fallback: '',
    );

    final String model =
        _value(
      vehicle['model'],
      fallback: '',
    );

    final String year =
        _value(
      vehicle['year'],
      fallback: 'Não informado',
    );

    final String color =
        _value(
      vehicle['color'],
    );

    final String plate =
        _value(
      vehicle['plate'],
      fallback: 'Sem placa',
    );

    final String driverName =
        _value(
      vehicle['driver_name'],
      fallback:
          'Motorista não informado',
    );

    final String driverPhone =
        _value(
      vehicle['driver_phone'],
      fallback: '',
    );

    String vehicleName =
        '$brand $model'.trim();

    if (vehicleName.isEmpty) {
      vehicleName =
          'Veículo não informado';
    }

    final Color statusColor =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .035,
            ),

            blurRadius: 12,

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
          // ======================================================
          // CABEÇALHO
          // ======================================================

          Row(
            children: [
              Container(
                width: 58,
                height: 58,

                decoration:
                    BoxDecoration(
                  color:
                      primary.withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: Icon(
                  _vehicleIcon(type),

                  color: primary,

                  size: 29,
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
                      vehicleName,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      driverName,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        color:
                            Colors.grey.shade700,

                        fontSize: 13,

                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    if (driverPhone
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        driverPhone,

                        style: TextStyle(
                          color:
                              Colors.grey.shade500,

                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              // ==================================================
              // STATUS
              // ==================================================

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      statusColor
                          .withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: Text(
                  _statusText(status),

                  style: TextStyle(
                    color:
                        statusColor,

                    fontSize: 11,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ======================================================
          // DADOS
          // ======================================================

          Container(
            padding:
                const EdgeInsets.all(
              15,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF8FAF9,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: Column(
              children: [
                _infoRow(
                  icon:
                      Icons.category_outlined,

                  title: 'Tipo',

                  value:
                      _vehicleTypeName(
                    type,
                  ),
                ),

                _infoRow(
                  icon:
                      Icons.palette_outlined,

                  title: 'Cor',

                  value: color,
                ),

                _infoRow(
                  icon: Icons
                      .confirmation_number_outlined,

                  title: 'Placa',

                  value: plate,
                ),

                _infoRow(
                  icon:
                      Icons.calendar_today_outlined,

                  title: 'Ano',

                  value: year,
                ),
              ],
            ),
          ),

          // ======================================================
          // AÇÕES
          //
          // SOMENTE PENDENTES
          // ======================================================

          if (status == 'pending') ...[
            const SizedBox(
              height: 18,
            ),

            Row(
              children: [
                // ==================================================
                // REJEITAR
                // ==================================================

                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _actionLoading ||
                                vehicleId <= 0
                            ? null
                            : () {
                                _vehicleAction(
                                  vehicleId:
                                      vehicleId,
                                  action:
                                      'reject',
                                );
                              },

                    icon:
                        const Icon(
                      Icons.close,
                      size: 18,
                    ),

                    label:
                        const Text(
                      'Rejeitar',
                    ),

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

                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 13,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                // ==================================================
                // APROVAR
                // ==================================================

                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _actionLoading ||
                                vehicleId <= 0
                            ? null
                            : () {
                                _vehicleAction(
                                  vehicleId:
                                      vehicleId,
                                  action:
                                      'approve',
                                );
                              },

                    icon:
                        const Icon(
                      Icons.check,
                      size: 18,
                    ),

                    label:
                        const Text(
                      'Aprovar',
                    ),

                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          primary,

                      foregroundColor:
                          Colors.white,

                      elevation: 0,

                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 13,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // LINHA DE INFORMAÇÃO
  // ============================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),

      child: Row(
        children: [
          Icon(
            icon,

            size: 18,

            color: primary,
          ),

          const SizedBox(
            width: 10,
          ),

          SizedBox(
            width: 70,

            child: Text(
              title,

              style: TextStyle(
                color:
                    Colors.grey.shade600,

                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,

              textAlign:
                  TextAlign.right,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                fontSize: 12,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VAZIO
  // ============================================================

  Widget _buildEmpty() {
    String title;
    String subtitle;

    switch (_selectedFilter) {
      case 1:
        title = 'Nenhum veículo aprovado.';
        subtitle =
            'Ainda não existem veículos aprovados.';

        break;

      case 2:
        title = 'Nenhum veículo rejeitado.';
        subtitle =
            'Ainda não existem veículos rejeitados.';

        break;

      case 3:
        title = 'Nenhum veículo encontrado.';
        subtitle =
            'Não existem veículos cadastrados.';

        break;

      default:
        title = 'Tudo em dia!';
        subtitle =
            'Não existem veículos aguardando aprovação.';
    }

    return Padding(
      padding:
          const EdgeInsets.all(
        25,
      ),

      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,

            decoration:
                BoxDecoration(
              color:
                  primary.withOpacity(
                .10,
              ),

              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              _selectedFilter == 2
                  ? Icons
                      .block_outlined
                  : Icons
                      .verified_outlined,

              color: primary,

              size: 35,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            title,

            style:
                const TextStyle(
              fontSize: 18,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            subtitle,

            textAlign:
                TextAlign.center,

            style: TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 13,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          OutlinedButton.icon(
            onPressed:
                _loadVehicles,

            icon:
                const Icon(
              Icons.refresh,
            ),

            label:
                const Text(
              'Atualizar',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget _buildError() {
    return Container(
      padding:
          const EdgeInsets.all(
        25,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,

            color: Colors.red,

            size: 42,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Não foi possível carregar os veículos.',

            textAlign:
                TextAlign.center,

            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            _error ??
                'Erro desconhecido.',

            textAlign:
                TextAlign.center,

            style: TextStyle(
              color:
                  Colors.grey.shade600,

              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          ElevatedButton.icon(
            onPressed:
                _loadVehicles,

            icon:
                const Icon(
              Icons.refresh,
            ),

            label:
                const Text(
              'Tentar novamente',
            ),

            style:
                ElevatedButton
                    .styleFrom(
              backgroundColor:
                  primary,

              foregroundColor:
                  Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(
    String message, {
    required bool success,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              success
                  ? Colors.black87
                  : Colors.red,

          content:
              Text(message),

          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}