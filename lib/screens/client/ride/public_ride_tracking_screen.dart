import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';

class PublicRideTrackingScreen extends StatefulWidget {
  final int rideId;
  const PublicRideTrackingScreen({super.key, required this.rideId});

  @override
  State<PublicRideTrackingScreen> createState() => _PublicRideTrackingScreenState();
}

class _PublicRideTrackingScreenState extends State<PublicRideTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _timer;
  LatLng? _driver;
  LatLng? _destination;
  String status = 'Carregando...';
  String driverName = 'Motorista';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final result = await ApiService.getPublicRideTracking(rideId: widget.rideId);
      if (!mounted || result['success'] != true) return;
      final driver = result['driver'];
      if (driver is Map) {
        final lat = double.tryParse(driver['latitude']?.toString() ?? '');
        final lng = double.tryParse(driver['longitude']?.toString() ?? '');
        if (lat != null && lng != null) _driver = LatLng(lat, lng);
      }
      final rideStatus = result['ride_status']?.toString() ?? 'driver_found';
      status = _label(rideStatus);
      if (driver is Map) driverName = driver['name']?.toString() ?? 'Motorista';
      if (_driver != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try { _mapController.move(_driver!, 15.5); } catch (_) {}
        });
      }
      setState(() {});
    } catch (_) {}
  }

  String _label(String value) {
    switch (value) {
      case 'driver_found': return 'Motorista aceitou a corrida';
      case 'driver_arriving': return 'Motorista a caminho';
      case 'driver_arrived': return 'Motorista chegou';
      case 'in_progress': return 'Corrida em andamento';
      case 'completed': return 'Corrida concluída';
      case 'cancelled': return 'Corrida cancelada';
      default: return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _driver ?? const LatLng(-21.1107, -44.1752);
    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhar MotoGo')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14.5),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.motogo',
                ),
                if (_driver != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _driver!, width: 58, height: 58,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(Icons.two_wheeler, color: Colors.white),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Motorista: $driverName', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text('Corrida #${widget.rideId}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
