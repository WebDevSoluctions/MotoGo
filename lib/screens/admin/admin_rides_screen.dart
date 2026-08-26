import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminRidesScreen extends StatefulWidget {
  const AdminRidesScreen({super.key});
  @override State<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends State<AdminRidesScreen> {
  String status = 'all';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rides = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await ApiService.getAdminRides(status: status);
    if (!mounted) return;
    if (r['success'] == true) {
      final raw = r['rides'];
      rides = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      error = null;
    } else {
      error = r['message']?.toString() ?? 'Erro';
    }
    setState(() => loading = false);
  }

  String _money(dynamic value) {
    final d = double.tryParse(value?.toString() ?? '') ?? 0;
    return 'R\$ ${d.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _label(String value) {
    if (value.isEmpty) return '—';
    final x = value.replaceAll('_', ' ');
    return x[0].toUpperCase() + x.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corridas'),
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      backgroundColor: const Color(0xFFF5F7F6),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['all','pending','searching','driver_found','driver_arriving','driver_arrived','in_progress','completed','cancelled']
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(s)),
                          selected: status == s,
                          onSelected: (_) { setState(() => status = s); _load(); },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : rides.isEmpty
                        ? const Center(child: Text('Nenhuma corrida encontrada.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: rides.length,
                            itemBuilder: (_, i) {
                              final r = rides[i];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  isThreeLine: true,
                                  title: Text('#${r["id"]} • ${r["passenger_name"] ?? 'Passageiro'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${r["origin_address"] ?? ''}\n→ ${r["destination_address"] ?? ''}\n${_label(r["status"]?.toString() ?? '')} • ${r["driver_name"] ?? 'Sem motorista'}'),
                                  trailing: Text(_money(r['total_fare']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text('Corrida #${r["id"]}'),
                                      content: Text('Tipo: ${r["ride_type"]}\nDistância: ${r["distance_km"]} km\nMotorista: ${r["driver_name"] ?? '—'}\nValor: ${_money(r["total_fare"])}'),
                                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
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
}
