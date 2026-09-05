import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../../../config/api_config.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() =>
      _AdminDriversScreenState();
}

class _AdminDriversScreenState
    extends State<AdminDriversScreen> {
  // ============================================================
  // CORES
  // ============================================================

  static const Color primary =
      Color(0xFF00C985);

  static const Color background =
      Color(0xFFF5F7F6);

  // ============================================================
  // FILTROS
  // ============================================================

  int selectedFilter = 0;

  final List<String> filters = [
    'Pendentes',
    'Aprovados',
    'Rejeitados',
    'Todos',
  ];

  // ============================================================
  // DADOS
  // ============================================================

  List<Map<String, dynamic>> drivers = [];

  bool loading = true;
  bool actionLoading = false;

  String? errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // ============================================================
  // CARREGAR MOTORISTAS
  // ============================================================

  Future<void> _loadDrivers() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result =
          await ApiService.getAdminDrivers();

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() {
          loading = false;
          errorMessage =
              result['message']?.toString() ??
                  'Não foi possível carregar os motoristas.';
        });

        return;
      }

      // ========================================================
      // AGORA USAMOS TODOS OS MOTORISTAS
      // ========================================================

      final dynamic rawDrivers =
          result['drivers'];

      final List<Map<String, dynamic>>
          loadedDrivers = [];

      if (rawDrivers is List) {
        for (final item in rawDrivers) {
          if (item is Map) {
            loadedDrivers.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      // ========================================================
      // SALVAR
      // ========================================================

      setState(() {
        drivers = loadedDrivers;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Não foi possível conectar à API.';
      });
    }
  }

  // ============================================================
  // CONVERTER PARA INT
  // ============================================================

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Motoristas',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          // ======================================================
          // CABEÇALHO
          // ======================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              18,
            ),

            color: Colors.white,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Gestão de motoristas',

                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Analise os cadastros e aprove novos motoristas.',

                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // FILTROS
                // ==================================================

                SizedBox(
                  height: 42,

                  child: ListView.builder(
                    scrollDirection:
                        Axis.horizontal,

                    itemCount:
                        filters.length,

                    itemBuilder:
                        (context, index) {
                      final bool selected =
                          selectedFilter ==
                              index;

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          right: 8,
                        ),

                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilter =
                                  index;
                            });
                          },

                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 17,
                            ),

                            decoration:
                                BoxDecoration(
                              color: selected
                                  ? primary
                                  : Colors
                                      .grey
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
                              filters[index],

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
          ),

          // ======================================================
          // LISTA
          // ======================================================

          Expanded(
            child: _buildDriversList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA DE MOTORISTAS
  // ============================================================

  Widget _buildDriversList() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primary,
        ),
      );
    }

    // ==========================================================
    // ERRO
    // ==========================================================

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Icon(
                Icons.error_outline,
                size: 52,
                color: Colors.red.shade400,
              ),

              const SizedBox(height: 14),

              Text(
                errorMessage!,
                textAlign: TextAlign.center,

                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: _loadDrivers,

                icon: const Icon(
                  Icons.refresh,
                ),

                label: const Text(
                  'Tentar novamente',
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================================
    // FILTRAR
    // ==========================================================

    final List<Map<String, dynamic>>
        filteredDrivers =
        drivers.where((driver) {
      final String status =
          driver['verification_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      switch (selectedFilter) {
        // ------------------------------------------------------
        // PENDENTES
        // ------------------------------------------------------

        case 0:
          return status == 'pending';

        // ------------------------------------------------------
        // APROVADOS
        // ------------------------------------------------------

        case 1:
          return status == 'approved';

        // ------------------------------------------------------
        // REJEITADOS
        // ------------------------------------------------------

        case 2:
          return status == 'rejected';

        // ------------------------------------------------------
        // TODOS
        // ------------------------------------------------------

        default:
          return true;
      }
    }).toList();

    // ==========================================================
    // VAZIO
    // ==========================================================

    if (filteredDrivers.isEmpty) {
      return RefreshIndicator(
        color: primary,

        onRefresh: _loadDrivers,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          children: [
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      .55,

              child: Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [
                    Icon(
                      Icons
                          .directions_car_outlined,

                      size: 55,

                      color:
                          Colors.grey.shade400,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Text(
                      'Nenhum motorista encontrado.',

                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      'Puxe para atualizar.',

                      style: TextStyle(
                        color:
                            Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // LISTA
    // ==========================================================

    return RefreshIndicator(
      color: primary,

      onRefresh: _loadDrivers,

      child: ListView.builder(
        padding:
            const EdgeInsets.all(16),

        itemCount:
            filteredDrivers.length,

        itemBuilder:
            (context, index) {
          final driver =
              filteredDrivers[index];

          return _driverCard(
            driver,
          );
        },
      ),
    );
  }

  // ============================================================
  // CARD MOTORISTA
  // ============================================================

  Widget _driverCard(
    Map<String, dynamic> driver,
  ) {
    final String status =
        driver['verification_status']
                ?.toString()
                .toLowerCase() ??
            'pending';

    final String name =
        _displayValue(
      driver['name'],
      'Nome não informado',
    );

    final String phone =
        _displayValue(
      driver['phone'],
      'Telefone não informado',
    );

    // ==========================================================
    // VEÍCULO
    // ==========================================================

    final String vehicleType =
        _displayValue(
      driver['vehicle_type'],
      'Não informado',
    );

    final String brand =
        _displayValue(
      driver['brand'],
      '',
    );

    final String model =
        _displayValue(
      driver['model'],
      '',
    );

    final String color =
        _displayValue(
      driver['color'],
      'Não informado',
    );

    final String year =
        _displayValue(
      driver['year'],
      'Não informado',
    );

    final String plate =
        _displayValue(
      driver['plate'],
      'Sem placa',
    );

    // ==========================================================
    // NOME DO VEÍCULO
    // ==========================================================

    String vehicleName;

    if (brand.isEmpty &&
        model.isEmpty) {
      vehicleName = 'Veículo não informado';
    } else if (model.isEmpty) {
      vehicleName = brand;
    } else if (brand.isEmpty) {
      vehicleName = model;
    } else {
      vehicleName =
          '$brand $model';
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .04,
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

      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // MOTORISTA
            // ==================================================

            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,

                  decoration:
                      BoxDecoration(
                    color:
                        primary.withOpacity(
                      .12,
                    ),

                    shape:
                        BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.person,
                    color: primary,
                    size: 28,
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
                        name,

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
                        height: 3,
                      ),

                      Text(
                        phone,

                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                _statusBadge(
                  status,
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            const Divider(
              height: 1,
            ),

            const SizedBox(
              height: 17,
            ),

            // ==================================================
            // VEÍCULO
            // ==================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade100,

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child: Icon(
                    _vehicleIcon(
                      vehicleType,
                    ),

                    color: primary,
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
                      Text(
                        vehicleName,

                        maxLines: 1,

                        overflow:
                            TextOverflow.ellipsis,

                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        '${_vehicleTypeName(vehicleType)} • $color • $year',

                        maxLines: 2,

                        overflow:
                            TextOverflow.ellipsis,

                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 8,
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
                    plate,

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

            // ==================================================
            // DOCUMENTOS
            // ==================================================

            _buildDocumentsSection(driver),

            // ==================================================
            // AÇÕES
            // Só aparecem para PENDENTE.
            // ==================================================

            if (status == 'pending') ...[
              const SizedBox(
                height: 18,
              ),

              Row(
                children: [
                  // ============================================
                  // REJEITAR
                  // ============================================

                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          actionLoading
                              ? null
                              : () {
                                  _rejectDriver(
                                    driver,
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
                    width: 10,
                  ),

                  // ==========================================
                  // APROVAR
                  // ==========================================

                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          actionLoading
                              ? null
                              : () {
                                  _approveDriver(
                                    driver,
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
      ),
    );
  }

  // ============================================================
  // DOCUMENTOS
  // ============================================================

  Widget _buildDocumentsSection(
    Map<String, dynamic> driver,
  ) {
    final dynamic rawDocuments = driver['documents'];
    final List<Map<String, dynamic>> documents = [];

    if (rawDocuments is List) {
      for (final item in rawDocuments) {
        if (item is Map) {
          documents.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    final legacy = <String, String>{
      'document_photo': 'Documento de identificação',
      'cnh_photo': 'CNH',
      'selfie_photo': 'Selfie',
    };

    for (final entry in legacy.entries) {
      final value = driver[entry.key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        final alreadyExists = documents.any(
          (doc) => doc['file_path']?.toString() == value,
        );
        if (!alreadyExists) {
          documents.add({
            'document_type': entry.key,
            'original_name': entry.value,
            'file_path': value,
          });
        }
      }
    }

    final vehicleType = driver['vehicle_type']?.toString().toLowerCase() ?? '';
    final isBike = vehicleType == 'bicicleta';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'Documentos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            Text(
              isBike
                  ? 'Bicicleta: não é necessário enviar CNH ou documento de veículo.'
                  : 'Nenhum documento foi enviado ainda.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            )
          else
            ...documents.map(_buildDocumentRow),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(
    Map<String, dynamic> document,
  ) {
    final type = document['document_type']?.toString() ?? 'documento';
    final originalName = document['original_name']?.toString();
    final path = document['file_path']?.toString() ?? '';
    final documentId = int.tryParse(document['id']?.toString() ?? '');
    final viewUrl = document['view_url']?.toString() ?? '';

    String title;
    switch (type.toLowerCase()) {
      case 'cnh':
      case 'cnh_photo':
        title = 'CNH';
        break;
      case 'vehicle_document':
      case 'crlv':
        title = 'Documento do veículo (CRLV)';
        break;
      case 'identity':
      case 'document':
      case 'document_photo':
        title = 'Documento de identificação';
        break;
      case 'proof_of_address':
        title = 'Comprovante de endereço';
        break;
      case 'selfie':
      case 'selfie_photo':
        title = 'Selfie';
        break;
      default:
        title = type.isEmpty ? 'Documento' : type;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (originalName != null && originalName.isNotEmpty)
                  Text(
                    originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: (viewUrl.isEmpty && path.isEmpty && documentId == null)
                ? null
                : () => _openDocument(
                    documentId != null
                        ? '${ApiConfig.baseUrl}/admin/driver_document.php?id=$documentId'
                        : viewUrl.isNotEmpty
                            ? viewUrl
                            : path,
                  ),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            label: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(String filePath) async {
    String value = filePath.trim();
    if (value.isEmpty) return;

    Uri uri;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      value = value.replaceFirst('/api/admin/admin/driver_document.php', '/api/admin/driver_document.php');
      uri = Uri.parse(value);
    } else {
      final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      final normalized = value.startsWith('/') ? value : '/$value';
      uri = Uri.parse('$base$normalized');
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o documento.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o documento.')),
      );
    }
  }

  // ============================================================
  // VALOR SEGURO
  // ============================================================

  String _displayValue(
    dynamic value,
    String fallback,
  ) {
    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    if (text.isEmpty ||
        text.toLowerCase() ==
            'null') {
      return fallback;
    }

    return text;
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Aprovado';
        break;

      case 'rejected':
        color = Colors.red;
        text = 'Rejeitado';
        break;

      default:
        color = Colors.orange;
        text = 'Pendente';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(.10),

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // ÍCONE DO VEÍCULO
  // ============================================================

  IconData _vehicleIcon(
    dynamic type,
  ) {
    switch (
        type?.toString().toLowerCase()) {
      case 'carro':
        return Icons.directions_car;

      case 'bicicleta':
        return Icons.pedal_bike;

      default:
        return Icons.two_wheeler;
    }
  }

  // ============================================================
  // NOME DO TIPO
  // ============================================================

  String _vehicleTypeName(
    dynamic type,
  ) {
    switch (
        type?.toString().toLowerCase()) {
      case 'carro':
        return 'Carro';

      case 'bicicleta':
        return 'Bicicleta';

      default:
        return 'Moto';
    }
  }

  // ============================================================
  // APROVAR MOTORISTA
  // ============================================================

  Future<void> _approveDriver(
    Map<String, dynamic> driver,
  ) async {
    if (actionLoading) {
      return;
    }

    final int driverId =
        _toInt(driver['id']) ?? 0;

    if (driverId <= 0) {
      _showMessage(
        'ID do motorista inválido.',
      );

      return;
    }

    setState(() {
      actionLoading = true;
    });

    try {
      final result =
          await ApiService.adminDriverAction(
        driverId: driverId,
        action: 'approve',
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        _showMessage(
          result['message']?.toString() ??
              'Motorista aprovado com sucesso.',
        );

        await _loadDrivers();
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Não foi possível aprovar o motorista.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Erro ao comunicar com o servidor.',
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  // ============================================================
  // REJEITAR MOTORISTA
  // ============================================================

  Future<void> _rejectDriver(
    Map<String, dynamic> driver,
  ) async {
    if (actionLoading) {
      return;
    }

    final int driverId =
        _toInt(driver['id']) ?? 0;

    if (driverId <= 0) {
      _showMessage(
        'ID do motorista inválido.',
      );

      return;
    }

    final TextEditingController reasonController =
        TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reprovar motorista'),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Motivo da reprovação',
              hintText: 'Informe o motivo para o motorista.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(reasonController.text.trim()),
              child: const Text('Reprovar'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      actionLoading = true;
    });

    try {
      final result =
          await ApiService.adminDriverAction(
        driverId: driverId,
        action: 'reject',
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        _showMessage(
          result['message']?.toString() ??
              'Motorista rejeitado com sucesso.',
        );

        await _loadDrivers();
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Não foi possível rejeitar o motorista.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Erro ao comunicar com o servidor.',
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),

          behavior:
              SnackBarBehavior.floating,

          backgroundColor:
              Colors.black87,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
      );
  }
}