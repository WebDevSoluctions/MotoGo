import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<Map<String, dynamic>> rides = [];
  bool loading = true;
  bool loadingMore = false;
  String? errorMessage;
  int page = 1;
  bool hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    if (refresh) {
      page = 1;
    }

    if (!mounted) return;
    setState(() {
      if (page == 1) loading = true;
      errorMessage = null;
    });

    try {
      final userIdString = await AuthService.getUserId();
      final userId = int.tryParse(userIdString ?? '');

      if (userId == null || userId <= 0) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }

      final result = await ApiService.getRideHistory(
        userId: userId,
        page: page,
        limit: 20,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        throw Exception(
          result['message']?.toString() ??
              'Não foi possível carregar o histórico.',
        );
      }

      final raw = result['rides'];
      final loaded = <Map<String, dynamic>>[];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            loaded.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final pagination = result['pagination'];
      final next = pagination is Map
          ? pagination['has_next_page'] == true
          : false;

      setState(() {
        if (page == 1) {
          rides = loaded;
        } else {
          rides.addAll(loaded);
        }
        hasNextPage = next;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        loadingMore = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasNextPage) return;

    setState(() {
      loadingMore = true;
      page++;
    });

    await _loadHistory();
  }

  String _serviceName(String type) {
    switch (type.toLowerCase()) {
      case 'carro':
        return 'Carro';

      case 'delivery_moto':
        return 'Entrega de moto';

      case 'delivery_bicicleta':
        return 'Entrega de bicicleta';

      case 'delivery_pedestre':
        return 'Entrega a pé';

      case 'delivery':
        return 'Delivery';

      case 'bicicleta':
        return 'Bicicleta';

      default:
        return 'Mototáxi';
    }
  }

  IconData _serviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'carro':
        return Icons.directions_car;

      case 'delivery_moto':
        return Icons.two_wheeler;

      case 'delivery_bicicleta':
      case 'bicicleta':
        return Icons.pedal_bike;

      case 'delivery_pedestre':
        return Icons.directions_walk;

      case 'delivery':
        return Icons.local_shipping_outlined;

      default:
        return Icons.two_wheeler;
    }
  }

  Color _serviceColor(String type) {
    switch (type.toLowerCase()) {
      case 'carro':
        return Colors.indigo;

      case 'delivery_moto':
        return Colors.blue;

      case 'delivery_bicicleta':
      case 'bicicleta':
        return Colors.deepOrange;

      case 'delivery_pedestre':
        return Colors.teal;

      case 'delivery':
        return Colors.blue;

      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      case 'in_progress':
        return 'Em andamento';
      case 'driver_arriving':
        return 'Motorista a caminho';
      case 'driver_arrived':
        return 'Motorista chegou';
      case 'driver_found':
        return 'Motorista encontrado';
      case 'searching':
        return 'Procurando motorista';
      case 'pending':
        return 'Aguardando';
      case 'expired':
        return 'Expirada';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'expired':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    return 'R\$ ${_number(value).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return 'Data não informada';

    try {
      final parsed = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final local = parsed.toLocal();
      return '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}/'
          '${local.year} • '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  String _driverName(Map<String, dynamic> ride) {
    final driver = ride['driver'];
    if (driver is Map) {
      final name = driver['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Motorista não associado';
  }

  String _vehicleText(Map<String, dynamic> ride) {
    final vehicle = ride['vehicle'];
    if (vehicle is Map) {
      final brand = vehicle['brand']?.toString() ?? '';
      final model = vehicle['model']?.toString() ?? '';
      final plate = vehicle['plate']?.toString() ?? '';

      final modelText = '$brand $model'.trim();
      if (plate.isNotEmpty && modelText.isNotEmpty) {
        return '$modelText • $plate';
      }
      if (modelText.isNotEmpty) return modelText;
      if (plate.isNotEmpty) return plate;
    }
    return 'Veículo não informado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Histórico'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: loading ? null : () => _loadHistory(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null && rides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _loadHistory(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (rides.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * .65,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nenhuma corrida ainda',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Quando você realizar uma corrida, ela aparecerá aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          height: 1.4,
                        ),
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

    return RefreshIndicator(
      onRefresh: () => _loadHistory(refresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        itemCount: rides.length + (hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == rides.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: ElevatedButton(
                  onPressed: loadingMore ? null : _loadMore,
                  child: loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Carregar mais'),
                ),
              ),
            );
          }

          final ride = rides[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _rideCard(ride),
          );
        },
      ),
    );
  }

  Widget _rideCard(Map<String, dynamic> ride) {
    final type = ride['ride_type']?.toString() ?? 'mototaxi';
    final color = _serviceColor(type);
    final status = ride['status']?.toString() ?? '';
    final driver = _driverName(ride);
    final vehicle = _vehicleText(ride);
    final origin = ride['origin'] is Map
        ? (ride['origin']['address']?.toString() ?? '')
        : '';
    final destination = ride['destination'] is Map
        ? (ride['destination']['address']?.toString() ?? '')
        : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showDetails(ride),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _serviceIcon(type),
                      color: color,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serviceName(type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _date(ride['created_at']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(ride['fare'] is Map
                        ? ride['fare']['total']
                        : ride['total_fare']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _locationRow(
                color: color,
                iconColor: color,
                text: origin.isEmpty ? 'Origem não informada' : origin,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 7, bottom: 7),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 12,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              _locationRow(
                color: Colors.red,
                iconColor: Colors.red,
                text: destination.isEmpty
                    ? 'Destino não informado'
                    : destination,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15, color: Colors.grey),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      driver,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationRow({
    required Color color,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showDetails(Map<String, dynamic> ride) {
    final type = ride['ride_type']?.toString() ?? 'mototaxi';
    final fare = ride['fare'] is Map ? ride['fare'] : <String, dynamic>{};
    final driver = ride['driver'] is Map ? ride['driver'] : null;
    final vehicle = ride['vehicle'] is Map ? ride['vehicle'] : null;
    final payment = ride['payment'] is Map ? ride['payment'] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      _serviceIcon(type),
                      color: _serviceColor(type),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _serviceName(type),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _money(fare['total'] ?? ride['total_fare']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detail('Corrida', ride["ride_code"]?.toString() ?? '#${ride["id"]}'),
                _detail('Data', _date(ride['created_at'])),
                _detail('Status', _statusLabel(ride['status']?.toString() ?? '')),
                _detail(
                  'Origem',
                  ride['origin'] is Map
                      ? ride['origin']['address']?.toString() ?? '-'
                      : '-',
                ),
                _detail(
                  'Destino',
                  ride['destination'] is Map
                      ? ride['destination']['address']?.toString() ?? '-'
                      : '-',
                ),
                _detail(
                  'Distância',
                  '${_number(ride["distance_km"]).toStringAsFixed(1).replaceAll('.', ',')} km',
                ),
                _detail(
                  'Duração',
                  '${_number(ride["duration_minutes"]).round()} min',
                ),
                _detail(
                  'Motorista',
                  driver?['name']?.toString() ?? 'Não associado',
                ),
                _detail(
                  'Veículo',
                  vehicle == null
                      ? 'Não informado'
                      : '${vehicle["brand"] ?? ''} ${vehicle["model"] ?? ''} • ${vehicle["plate"] ?? ''}',
                ),
                _detail(
                  'Pagamento',
                  payment?['method']?.toString() ?? 'Não informado',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
