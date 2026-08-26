import 'package:flutter/material.dart';

import '../../../../config/colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';

class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity> {
  List<Map<String, dynamic>> rides = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = int.tryParse((await AuthService.getUserId()) ?? '');
      if (userId == null || userId <= 0) throw Exception('Usuário não identificado.');

      final result = await ApiService.getRideHistory(
        userId: userId,
        page: 1,
        limit: 3,
      );

      final raw = result['rides'];
      final loaded = <Map<String, dynamic>>[];
      if (result['success'] == true && raw is List) {
        for (final item in raw) {
          if (item is Map) loaded.add(Map<String, dynamic>.from(item));
        }
      }

      if (!mounted) return;
      setState(() {
        rides = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _service(String type) {
    switch (type) {
      case 'carro': return 'Carro';
      case 'delivery_moto': return 'Delivery Moto';
      case 'delivery_bicicleta': return 'Bike Express';
      case 'delivery_pedestre': return 'Entrega a Pé';
      default: return 'Mototáxi';
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'carro': return Icons.directions_car;
      case 'delivery_moto': return Icons.two_wheeler;
      case 'delivery_bicicleta': return Icons.pedal_bike;
      case 'delivery_pedestre': return Icons.directions_walk;
      default: return Icons.two_wheeler;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'carro': return Colors.indigo;
      case 'delivery_moto': return Colors.blue;
      case 'delivery_bicicleta': return Colors.deepOrange;
      case 'delivery_pedestre': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'R\$ ${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} • '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ));
    }

    if (rides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          'Nenhuma corrida realizada ainda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: rides.map((ride) {
        final type = ride['ride_type']?.toString() ?? 'mototaxi';
        final color = _color(type);
        final origin = ride['origin'] is Map
            ? ride['origin']['address']?.toString() ?? ''
            : '';
        final destination = ride['destination'] is Map
            ? ride['destination']['address']?.toString() ?? ''
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ActivityCard(
            icon: _icon(type),
            color: color,
            title: _service(type),
            address: destination.isEmpty ? origin : destination,
            price: _money(ride['fare'] is Map ? ride['fare']['total'] : ride['total_fare']),
            date: _date(ride['created_at']),
          ),
        );
      }).toList(),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String address;
  final String price;
  final String date;

  const ActivityCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.address,
    required this.price,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
