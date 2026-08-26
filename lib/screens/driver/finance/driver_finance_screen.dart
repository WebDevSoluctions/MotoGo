import '../../../config/api_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../config/colors.dart';
import '../../../services/api_service.dart';

class DriverFinanceScreen extends StatefulWidget {
  final int driverId;

  const DriverFinanceScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverFinanceScreen> createState() =>
      _DriverFinanceScreenState();
}

class _DriverFinanceScreenState extends State<DriverFinanceScreen> {
  static const String baseUrl = ApiConfig.baseUrl;

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? currentInvoice;

  List<Map<String, dynamic>> commissions = [];
  List<Map<String, dynamic>> invoices = [];

  double pendingAmount = 0.0;
  int pendingRides = 0;
  String? pendingDueAt;

  // ============================================================
  // RESUMO FINANCEIRO
  // ============================================================

  int totalInvoices = 0;
  int totalRides = 0;

  double totalGross = 0.0;
  double totalCommission = 0.0;
  double totalDriver = 0.0;
  double totalPaid = 0.0;
  double totalOpen = 0.0;

  bool hasOverdue = false;
  Map<String, dynamic>? overdueInvoice;

  // ============================================================
  // COMPROVANTE
  // ============================================================

  List<int>? selectedProofBytes;
  String? selectedProofName;

  bool isSubmittingPayment = false;
  bool hasPendingPayment = false;
  Timer? _financeTimer;
  Map<String, dynamic>? _paymentInvoice;

  static const String pixKey =
      'motogocompany2026@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadFinance();
    _financeTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !isLoading) _loadFinance();
    });
  }

  @override
  void dispose() {
    _financeTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // CARREGAR FINANCEIRO
  // ============================================================

  Future<void> _loadFinance() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final Uri url = Uri.parse(
        '$baseUrl/drivers/finance.php'
        '?driver_id=${widget.driverId}'
        '&_ts=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erro HTTP ${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Resposta inválida da API.',
        );
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Não foi possível carregar o financeiro.',
        );
      }

      // ========================================================
      // FATURA ATUAL
      // ========================================================

      final dynamic invoiceData =
          decoded['current_invoice'];

      // ========================================================
      // COMISSÕES
      // ========================================================

      final dynamic commissionData =
          decoded['commissions'];

      // ========================================================
      // FATURAS
      // ========================================================

      final dynamic invoiceList =
          decoded['invoices'];

      // ========================================================
      // PENDENTES
      // ========================================================

      final dynamic pendingData =
          decoded['pending'];

      // ========================================================
      // SUMMARY
      // ========================================================

      final dynamic summaryData =
          decoded['summary'];

      final Map<String, dynamic> summary =
          summaryData is Map
              ? Map<String, dynamic>.from(
                  summaryData,
                )
              : {};

      // ========================================================
      // CONVERTER FATURA
      // ========================================================

      final Map<String, dynamic>? parsedCurrentInvoice =
          invoiceData is Map
              ? Map<String, dynamic>.from(
                  invoiceData,
                )
              : null;

      // ========================================================
      // CONVERTER COMISSÕES
      // ========================================================

      final List<Map<String, dynamic>> parsedCommissions =
          _toMapList(commissionData);

      // ========================================================
      // CONVERTER FATURAS
      // ========================================================

      final List<Map<String, dynamic>> parsedInvoices =
          _toMapList(invoiceList);

      // ========================================================
      // PENDENTES
      // ========================================================

      final double parsedPendingAmount =
          _toDouble(
        pendingData is Map
            ? pendingData['total_amount']
            : 0,
      );

      final int parsedPendingRides =
          _toInt(
        pendingData is Map
            ? pendingData['total_rides']
            : 0,
      );

      final String? parsedPendingDueAt =
          pendingData is Map && pendingData['due_at'] != null
              ? pendingData['due_at'].toString()
              : null;

      // ========================================================
      // RESUMO
      // ========================================================

      final int parsedTotalInvoices =
          _toInt(
        summary['total_invoices'],
      );

      final int parsedTotalRides =
          _toInt(
        summary['total_rides'],
      );

      final double parsedTotalGross =
          _toDouble(
        summary['total_gross'],
      );

      final double parsedTotalCommission =
          _toDouble(
        summary['total_commission'],
      );

      final double parsedTotalDriver =
          _toDouble(
        summary['total_driver'],
      );

      final double parsedTotalPaid =
          _toDouble(
        summary['total_paid'],
      );

      final double parsedTotalOpen =
          _toDouble(
        summary['total_open'],
      );

      // ========================================================
      // DETECTAR FATURA VENCIDA COM SEGURANÇA
      // ========================================================
      //
      // O backend já envia has_overdue/overdue_invoice.
      // Aqui também verificamos a lista de faturas e a data real
      // de vencimento para evitar que a tela mostre "Tudo certo"
      // quando a fatura já passou do vencimento.
      //
      bool isInvoiceOverdue(Map<String, dynamic> invoice) {
        final String status =
            invoice['status']?.toString().toLowerCase() ?? '';

        if (status == 'overdue') {
          return true;
        }

        if (status == 'paid' || status == 'cancelled') {
          return false;
        }

        final dynamic dueValue =
            invoice['due_at'] ?? invoice['due_date'];

        if (dueValue == null) {
          return false;
        }

        final String rawDue =
            dueValue.toString().trim();

        if (rawDue.isEmpty) {
          return false;
        }

        try {
          final DateTime due = DateTime.parse(
            rawDue.contains('T')
                ? rawDue
                : rawDue.replaceFirst(' ', 'T'),
          );

          return DateTime.now().isAfter(due);
        } catch (_) {
          return false;
        }
      }

      Map<String, dynamic>? detectedOverdueInvoice;

      // Primeiro usa a fatura vencida enviada pelo backend.
      if (summary['overdue_invoice'] is Map) {
        detectedOverdueInvoice =
            Map<String, dynamic>.from(
          summary['overdue_invoice'],
        );
      }

      // Se o backend não enviou, procura na lista.
      if (detectedOverdueInvoice == null) {
        for (final invoice in parsedInvoices) {
          if (isInvoiceOverdue(invoice)) {
            detectedOverdueInvoice =
                Map<String, dynamic>.from(invoice);

            // Para a interface, uma fatura cuja data já passou
            // deve ser tratada como vencida.
            detectedOverdueInvoice['status'] = 'overdue';
            break;
          }
        }
      }

      // Se a fatura atual já estiver vencida pela data, também
      // garantimos que ela seja tratada como overdue na tela.
      Map<String, dynamic>? effectiveCurrentInvoice =
          parsedCurrentInvoice;

      if (effectiveCurrentInvoice != null &&
          isInvoiceOverdue(effectiveCurrentInvoice)) {
        effectiveCurrentInvoice =
            Map<String, dynamic>.from(
          effectiveCurrentInvoice,
        );

        effectiveCurrentInvoice['status'] = 'overdue';

        detectedOverdueInvoice ??=
            Map<String, dynamic>.from(
          effectiveCurrentInvoice,
        );
      }

      // Se existe uma fatura vencida, ela deve ser a fatura
      // principal exibida ao motorista.
      if (detectedOverdueInvoice != null) {
        effectiveCurrentInvoice =
            Map<String, dynamic>.from(
          detectedOverdueInvoice,
        );

        effectiveCurrentInvoice['status'] = 'overdue';
      }

      final bool parsedHasOverdue =
          summary['has_overdue'] == true ||
          detectedOverdueInvoice != null;

      final Map<String, dynamic>?
          parsedOverdueInvoice =
          detectedOverdueInvoice;

      if (!mounted) return;

      setState(() {
        currentInvoice =
            effectiveCurrentInvoice;

        commissions =
            parsedCommissions;

        invoices =
            parsedInvoices;

        pendingAmount =
            parsedPendingAmount;

        pendingRides =
            parsedPendingRides;
        pendingDueAt =
            parsedPendingDueAt;

        totalInvoices =
            parsedTotalInvoices;

        totalRides =
            parsedTotalRides;

        totalGross =
            parsedTotalGross;

        totalCommission =
            parsedTotalCommission;

        totalDriver =
            parsedTotalDriver;

        totalPaid =
            parsedTotalPaid;

        totalOpen =
            parsedTotalOpen;

        hasOverdue =
            parsedHasOverdue;

        overdueInvoice =
            parsedOverdueInvoice;

        isLoading = false;

        hasPendingPayment =
            currentInvoice?['status']
                    ?.toString() ==
                'pending';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        errorMessage = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // CONVERSÕES
  // ============================================================

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .where((item) => item is Map)
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();
  }


  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  // ============================================================
  // PAGAMENTO
  // ============================================================

  bool _canPayInvoice(String status) {
    final normalized =
        status.trim().toLowerCase();

    return normalized == 'open' ||
        normalized == 'overdue';
  }

  // ============================================================
  // COPIAR PIX
  // ============================================================

  Future<void> _copyPix() async {
    await Clipboard.setData(
      const ClipboardData(
        text: pixKey,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Chave PIX copiada.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SELECIONAR COMPROVANTE
  // ============================================================

  Future<void> _pickProof() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
        ],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final picked =
          result.files.single;

      final String extension =
          picked.extension
                  ?.toLowerCase() ??
              '';

      if (![
        'jpg',
        'jpeg',
        'png',
      ].contains(extension)) {
        _showPaymentMessage(
          'Envie somente JPG ou PNG.',
          error: true,
        );
        return;
      }

      if (picked.bytes == null ||
          picked.bytes!.isEmpty) {
        _showPaymentMessage(
          'Não foi possível ler o comprovante.',
          error: true,
        );
        return;
      }

      final int size =
          picked.bytes!.length;

      if (size > 5 * 1024 * 1024) {
        _showPaymentMessage(
          'O comprovante deve ter no máximo 5 MB.',
          error: true,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedProofBytes =
            List<int>.from(
          picked.bytes!,
        );

        selectedProofName =
            picked.name;
      });

      _showPaymentMessage(
        'Comprovante selecionado com sucesso.',
      );
    } catch (e) {
      _showPaymentMessage(
        'Não foi possível selecionar o comprovante.',
        error: true,
      );
    }
  }

  // ============================================================
  // ENVIAR PAGAMENTO
  // ============================================================

  Future<void> _submitPayment() async {
    final Map<String, dynamic>? invoiceForPayment =
        _paymentInvoice ?? currentInvoice;

    if (invoiceForPayment == null ||
        selectedProofBytes == null ||
        selectedProofBytes!.isEmpty ||
        selectedProofName == null) {
      _showPaymentMessage(
        'Selecione o comprovante antes de enviar.',
        error: true,
      );
      return;
    }

    final int invoiceId =
        _toInt(
      invoiceForPayment['id'],
    );

    if (invoiceId <= 0) {
      _showPaymentMessage(
        'Não foi possível identificar a fatura.',
        error: true,
      );
      return;
    }

    if (hasPendingPayment ||
        invoiceForPayment['status']
                ?.toString() ==
            'pending') {
      _showPaymentMessage(
        'Já existe um pagamento desta fatura em análise.',
        error: true,
      );
      return;
    }

    setState(() {
      isSubmittingPayment = true;
    });

    try {
      final result =
          await ApiService.submitPayment(
        driverId: widget.driverId,
        invoiceId: invoiceId,
        proofBytes:
            selectedProofBytes!,
        fileName:
            selectedProofName!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          isSubmittingPayment = false;

          hasPendingPayment = true;

          selectedProofBytes = null;
          selectedProofName = null;
          _paymentInvoice = null;
        });

        await _loadFinance();

        if (!mounted) return;

        _showPaymentMessage(
          result['message']?.toString() ??
              'Comprovante enviado. Pagamento em análise.',
        );
      } else {
        setState(() {
          isSubmittingPayment = false;
        });

        _showPaymentMessage(
          result['message']?.toString() ??
              'Não foi possível enviar o comprovante.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSubmittingPayment = false;
      });

      _showPaymentMessage(
        'Erro ao enviar o comprovante.',
        error: true,
      );
    }
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showPaymentMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            error
                ? Colors.red.shade700
                : Colors.green.shade700,
      ),
    );
  }

  // ============================================================
  // DIALOG PAGAMENTO
  // ============================================================

  Future<void> _showPaymentDialog({
    Map<String, dynamic>? invoice,
  }) async {
    final Map<String, dynamic>? selectedInvoice =
        invoice ?? currentInvoice;

    if (selectedInvoice == null) {
      return;
    }

    setState(() {
      _paymentInvoice = Map<String, dynamic>.from(selectedInvoice);
      selectedProofBytes = null;
      selectedProofName = null;
      hasPendingPayment =
          selectedInvoice['status']?.toString() == 'pending';
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            modalContext,
            setModalState,
          ) {
            return SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24,
                ),
                decoration:
                    const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child:
                    SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      const Text(
                        'Pagar fatura',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Faça o PIX e envie o comprovante.',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

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
                              AppColors.primary
                                  .withOpacity(.06),
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valor da fatura',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              _money(
                                (_paymentInvoice ?? selectedInvoice)['amount'],
                              ),
                              style:
                                  const TextStyle(
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'PIX',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          15,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                          border:
                              Border.all(
                            color:
                                Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                pixKey,
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  _copyPix,
                              icon:
                                  const Icon(
                                Icons
                                    .copy_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      const Text(
                        'Comprovante',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        onTap: () async {
                          await _pickProof();

                          setModalState(
                            () {},
                          );
                        },
                        child: Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.grey.shade50,
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                            border:
                                Border.all(
                              color:
                                  selectedProofBytes !=
                                          null
                                      ? AppColors
                                          .primary
                                      : Colors
                                          .grey
                                          .shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedProofBytes !=
                                        null
                                    ? Icons
                                        .check_circle_outline
                                    : Icons
                                        .cloud_upload_outlined,
                                color:
                                    selectedProofBytes !=
                                            null
                                        ? Colors.green
                                        : AppColors
                                            .primary,
                                size: 28,
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child: Text(
                                  selectedProofName ??
                                      'Selecionar JPG ou PNG',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    color:
                                        selectedProofBytes !=
                                                null
                                            ? Colors
                                                .black
                                            : Colors
                                                .grey
                                                .shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'JPG ou PNG • máximo 5 MB',
                        style: TextStyle(
                          color:
                              Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 52,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              isSubmittingPayment
                                  ? null
                                  : () async {
                                      await _submitPayment();

                                      if (!mounted) {
                                        return;
                                      }

                                      if (hasPendingPayment &&
                                          sheetContext
                                              .mounted) {
                                        Navigator.of(
                                          sheetContext,
                                        ).pop();
                                      }

                                      setModalState(
                                        () {},
                                      );
                                    },
                          icon:
                              isSubmittingPayment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .send_rounded,
                                    ),
                          label: Text(
                            isSubmittingPayment
                                ? 'Enviando...'
                                : 'Enviar comprovante',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        isSubmittingPayment = false;
      });
    }
  }

  // ============================================================
  // AÇÃO DA FATURA
  // ============================================================

  Widget _buildPaymentAction(
    String status,
  ) {
    if (status == 'paid') {
      return Container(
        width: double.infinity,
        margin:
            const EdgeInsets.only(top: 18),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              Colors.green.withOpacity(.08),
          borderRadius:
              BorderRadius.circular(15),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pagamento confirmado.',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (hasPendingPayment ||
        status == 'pending') {
      return Container(
        width: double.infinity,
        margin:
            const EdgeInsets.only(top: 18),
        padding:
            const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              Colors.orange.withOpacity(.08),
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color:
                Colors.orange.withOpacity(.18),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: Colors.orange,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pagamento em análise',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Aguarde a confirmação da MotoGo.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!_canPayInvoice(status)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(top: 18),
      child: ElevatedButton.icon(
        onPressed:
            isSubmittingPayment
                ? null
                : _showPaymentDialog,
        icon: const Icon(
          Icons.pix_rounded,
        ),
        label: const Text(
          'Pagar fatura',
        ),
        style:
            ElevatedButton.styleFrom(
          minimumSize:
              const Size.fromHeight(52),
          backgroundColor:
              status == 'overdue' ? Colors.red : null,
          foregroundColor:
              status == 'overdue' ? Colors.white : null,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DINHEIRO
  // ============================================================

  String _money(dynamic value) {
    final double amount =
        _toDouble(value);

    return 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _statusLabel(
    String? status,
  ) {
    switch (status) {
      case 'paid':
        return 'Paga';

      case 'open':
        return 'Em aberto';

      case 'pending':
        return 'Em análise';

      case 'overdue':
        return 'Vencida';

      case 'cancelled':
        return 'Cancelada';

      default:
        return status ?? 'Desconhecido';
    }
  }

  Color _statusColor(
    String? status,
  ) {
    switch (status) {
      case 'paid':
        return Colors.green;

      case 'overdue':
        return Colors.red;

      case 'cancelled':
        return Colors.grey;

      case 'pending':
        return Colors.orange;

      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // DATA
  // ============================================================

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final String raw =
        value.toString();

    if (raw.isEmpty) {
      return '-';
    }

    final String dateOnly =
        raw.split(' ').first;

    final List<String> parts =
        dateOnly.split('-');

    if (parts.length != 3) {
      return raw;
    }

    return '${parts[2]}/${parts[1]}/${parts[0]}';
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
        elevation: 0,
        backgroundColor:
            AppColors.background,
        foregroundColor:
            Colors.black,
        title: const Text(
          'Meus ganhos',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFinance,
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(25),
        children: [
          const SizedBox(
            height: 80,
          ),

          Icon(
            Icons.error_outline,
            size: 55,
            color:
                Colors.red.shade400,
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'Não foi possível carregar o financeiro.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            errorMessage!,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          ElevatedButton(
            onPressed:
                _loadFinance,
            child:
                const Text(
              'Tentar novamente',
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        30,
      ),
      children: [
        // ======================================================
        // ALERTA DE VENCIMENTO
        // ======================================================

        if (hasOverdue) ...[
          _buildOverdueAlert(),

          const SizedBox(
            height: 16,
          ),
        ],

        // ======================================================
        // RESUMO
        // ======================================================

        _buildSummaryCard(),

        const SizedBox(
          height: 18,
        ),

        // ======================================================
        // FATURA ATUAL
        // ======================================================

        _buildCurrentInvoice(),

        const SizedBox(
          height: 18,
        ),

        // ======================================================
        // PENDENTES
        // ======================================================

        _buildPendingCard(),

        const SizedBox(
          height: 25,
        ),

        // ======================================================
        // HISTÓRICO
        // ======================================================

        const Text(
          'Histórico financeiro',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          'Todas as suas faturas e corridas',
          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        if (invoices.isEmpty)
          _buildEmptyInvoices()
        else
          ...invoices.map(
            _buildInvoiceHistoryCard,
          ),
      ],
    );
  }

  // ============================================================
  // ALERTA DE FATURA VENCIDA
  // ============================================================

  Widget _buildOverdueAlert() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Colors.red.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.red.withOpacity(.20),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  Colors.red.withOpacity(.12),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
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
                const Text(
                  'Fatura vencida',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Você precisa regularizar sua fatura para voltar a receber corridas.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),

                if (overdueInvoice != null) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Vencimento: ${_formatDateTime(overdueInvoice!['due_at'] ?? overdueInvoice!['due_date'])}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(
                      overdueInvoice!['amount'],
                    ),
                    style:
                        const TextStyle(
                      color: Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESUMO FINANCEIRO
  // ============================================================

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary
                          .withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons
                      .account_balance_wallet_outlined,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo financeiro',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Visão geral dos seus ganhos',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _summaryItem(
                  Icons
                      .two_wheeler_outlined,
                  'Corridas',
                  '$totalRides',
                ),
              ),

              Expanded(
                child:
                    _summaryItem(
                  Icons
                      .receipt_long_outlined,
                  'Faturas',
                  '$totalInvoices',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _summaryMoneyItem(
                  'Total bruto',
                  totalGross,
                ),
              ),

              Expanded(
                child:
                    _summaryMoneyItem(
                  'Comissão 10%',
                  totalCommission,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color:
                  Colors.green.withOpacity(.07),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .account_balance_wallet_rounded,
                  color: Colors.green,
                ),

                const SizedBox(
                  width: 10,
                ),

                const Expanded(
                  child: Text(
                    'Você recebeu',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),

                Text(
                  _money(totalDriver),
                  style:
                      const TextStyle(
                    color: Colors.green,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _smallMoneyInfo(
                  'Total pago',
                  totalPaid,
                  Colors.green,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                    _smallMoneyInfo(
                  'Em aberto',
                  totalOpen,
                  totalOpen > 0
                      ? Colors.orange
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color:
              AppColors.primary,
        ),
        const SizedBox(
          width: 8,
        ),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryMoneyItem(
    String title,
    double value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color:
                Colors.grey.shade600,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          _money(value),
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _smallMoneyInfo(
    String title,
    double value,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.06),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            _money(value),
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FATURA ATUAL
  // ============================================================

  Widget _buildCurrentInvoice() {
    if (currentInvoice == null) {
      return Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(22),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .account_balance_wallet_outlined,
              size: 48,
              color:
                  AppColors.primary,
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Nenhuma fatura encontrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, dynamic>
        invoice =
        currentInvoice!;

    final String status =
        invoice['status']
                ?.toString() ??
            'open';

    final List<Map<String, dynamic>> currentCommissions =
        invoice['commissions'] is List
            ? _toMapList(invoice['commissions'])
            : commissions;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
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
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
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
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons
                      .receipt_long_outlined,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatura atual',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Comissões das corridas',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              _statusBadge(status),
            ],
          ),

          const SizedBox(
            height: 22,
          ),

          const Text(
            'Valor da fatura',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            _money(
              invoice['amount'],
            ),
            style:
                const TextStyle(
              fontSize: 32,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          // Botão de pagamento imediatamente abaixo do valor da fatura.
          _buildPaymentAction(
            status,
          ),

          const SizedBox(
            height: 20,
          ),

          _infoRow(
            Icons
                .calendar_today_outlined,
            'Período',
            '${_formatDate(invoice["period_start"])} → ${_formatDate(invoice["period_end"])}',
          ),

          const SizedBox(
            height: 12,
          ),

          _infoRow(
            Icons
                .event_available_outlined,
            'Vencimento',
            _formatDateTime(
              invoice['due_at'] ?? invoice['due_date'],
            ),
          ),

          if (currentCommissions
              .isNotEmpty) ...[
            const SizedBox(
              height: 20,
            ),

            const Divider(),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'Corridas desta fatura',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            ...currentCommissions.map(
              _buildDetailedCommission,
            ),
          ],

        ],
      ),
    );
  }

  // ============================================================
  // COMISSÃO DETALHADA
  // ============================================================

  Widget _buildDetailedCommission(
    Map<String, dynamic> commission,
  ) {
    final String rideId =
        commission['ride_id']
                ?.toString() ??
            '-';

    final double gross =
        _toDouble(
      commission['gross_amount'],
    );

  final double commissionAmount =
    _toDouble(
  commission['commission_amount'],
);
    final double driver =
        _toDouble(
      commission['driver_amount'],
    );

    final double percent =
        _toDouble(
      commission['commission_percent'],
    );

    final String status =
        commission['status']
                ?.toString() ??
            '';

    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(15),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primary
                          .withOpacity(.08),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  Icons
                      .two_wheeler_outlined,
                  color:
                      AppColors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corrida #$rideId',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Comissão MotoGo ${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              _miniStatus(
                status,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          _financeRow(
            'Valor da corrida',
            _money(gross),
          ),

          const SizedBox(
            height: 6,
          ),

          _financeRow(
            'Comissão MotoGo',
            _money(commissionAmount),
            valueColor:
                Colors.orange,
          ),

          const SizedBox(
            height: 6,
          ),

          _financeRow(
            'Motorista recebe',
            _money(driver),
            valueColor:
                Colors.green,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _financeRow(
    String title,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                valueColor ??
                    Colors.black,
            fontWeight:
                bold
                    ? FontWeight.bold
                    : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _miniStatus(
    String status,
  ) {
    final Color color =
        status == 'confirmed'
            ? Colors.green
            : status == 'cancelled'
                ? Colors.red
                : Colors.orange;

    final String label =
        status == 'confirmed'
            ? 'Confirmada'
            : status == 'cancelled'
                ? 'Cancelada'
                : 'Pendente';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
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
        label,
        style: TextStyle(
          color: color,
          fontWeight:
              FontWeight.bold,
          fontSize: 9,
        ),
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
          size: 19,
          color:
              Colors.grey.shade600,
        ),

        const SizedBox(
          width: 10,
        ),

        Text(
          '$title:',
          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(
          width: 5,
        ),

        Expanded(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BADGE
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    final Color color =
        _statusColor(status);

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
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // COMISSÕES PENDENTES
  // ============================================================

  Widget _buildPendingCard() {
    if (pendingAmount <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color:
            Colors.orange.withOpacity(.08),
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color:
              Colors.orange.withOpacity(.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color:
                  Colors.orange
                      .withOpacity(.12),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: Colors.orange,
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
                const Text(
                  'Comissões aguardando faturamento',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '$pendingRides corrida(s)',
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (pendingDueAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Previsão de vencimento: ${_formatDateTime(pendingDueAt)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Text(
            _money(pendingAmount),
            style:
                const TextStyle(
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
  // HISTÓRICO DE FATURA
  // ============================================================

  Widget _buildInvoiceHistoryCard(
    Map<String, dynamic> invoice,
  ) {
    final String status =
        invoice['status']
                ?.toString() ??
            'open';

    final List<Map<String, dynamic>> invoiceCommissions =
        invoice['commissions'] is List
            ? _toMapList(invoice['commissions'])
            : <Map<String, dynamic>>[];

    final int commissionCount =
        _toInt(
      invoice['commission_count'],
    );

    final double totalGross =
        _toDouble(
      invoice['total_gross'],
    );

    final double totalInvoiceCommission =
        _toDouble(
      invoice['total_commission'],
    );

    final double totalInvoiceDriver =
        _toDouble(
      invoice['total_driver'],
    );

    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 5,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          17,
          0,
          17,
          17,
        ),
        shape:
            const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(
            Radius.circular(18),
          ),
        ),
        collapsedShape:
            const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(
            Radius.circular(18),
          ),
        ),
        leading: Container(
          width: 43,
          height: 43,
          decoration:
              BoxDecoration(
            color:
                AppColors.primary
                    .withOpacity(.08),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            Icons.receipt_long_outlined,
            color:
                AppColors.primary,
          ),
        ),
        title: Text(
          'Fatura #${invoice["id"] ?? '-'}',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            '${_formatDate(invoice["period_start"])} → ${_formatDate(invoice["period_end"])}',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Text(
              _money(
                invoice['amount'],
              ),
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            _statusBadge(status),
          ],
        ),
        children: [
          _infoRow(
            Icons.event_available_outlined,
            'Vencimento',
            _formatDateTime(
              invoice['due_at'] ?? invoice['due_date'],
            ),
          ),

          if (invoice['paid_at'] != null) ...[
            const SizedBox(
              height: 10,
            ),
            _infoRow(
              Icons.check_circle_outline,
              'Pago em',
              _formatDateTime(
                invoice['paid_at'],
              ),
            ),
          ],

          const SizedBox(
            height: 16,
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  Colors.grey.shade50,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Column(
              children: [
                _financeRow(
                  'Corridas',
                  '$commissionCount',
                ),

                const SizedBox(
                  height: 7,
                ),

                _financeRow(
                  'Valor bruto',
                  _money(totalGross),
                ),

                const SizedBox(
                  height: 7,
                ),

                _financeRow(
                  'Comissão MotoGo',
                  _money(
                    totalInvoiceCommission,
                  ),
                  valueColor:
                      Colors.orange,
                ),

                const SizedBox(
                  height: 7,
                ),

                _financeRow(
                  'Motorista',
                  _money(
                    totalInvoiceDriver,
                  ),
                  valueColor:
                      Colors.green,
                  bold: true,
                ),
              ],
            ),
          ),

          if (invoiceCommissions
              .isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),

            const Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Corridas desta fatura',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            ...invoiceCommissions.map(
              _buildDetailedCommission,
            ),
          ],

          if (invoiceCommissions.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 12,
              ),
              child: Text(
                'Nenhuma corrida vinculada a esta fatura.',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),

          if (_canPayInvoice(status))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSubmittingPayment
                      ? null
                      : () => _showPaymentDialog(invoice: invoice),
                  icon: const Icon(Icons.pix_rounded),
                  label: Text(
                    status == 'overdue'
                        ? 'Pagar fatura vencida'
                        : 'Pagar esta fatura',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: status == 'overdue'
                        ? Colors.red
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA + HORA
  // ============================================================

  String _formatDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final String raw =
        value.toString();

    if (raw.contains(' ')) {
      final parts =
          raw.split(' ');

      final date =
          _formatDate(parts[0]);

      final time =
          parts.length > 1
              ? parts[1]
              : '';

      return '$date ${time.substring(
        0,
        time.length >= 5 ? 5 : time.length,
      )}';
    }

    return _formatDate(raw);
  }

  // ============================================================
  // VAZIO
  // ============================================================

  Widget _buildEmptyInvoices() {
    return Container(
      padding:
          const EdgeInsets.all(25),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .receipt_long_outlined,
            size: 45,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Nenhuma fatura encontrada',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Suas faturas aparecerão aqui.',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}