import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/colors.dart';

/// Mapa real da localização atual do passageiro.
class MapPlaceholder extends StatefulWidget {
  const MapPlaceholder({super.key});

  @override
  State<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<MapPlaceholder> {
  final MapController _mapController = MapController();
  LatLng? _position;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Ative o GPS para mostrar sua localização.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização não concedida.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _position = LatLng(position.latitude, position.longitude);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _position ?? const LatLng(-21.1107, -44.1752);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _position == null ? 13.5 : 15.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.motogo',
                ),
                if (_position != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _position!,
                        width: 54,
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _loading ? Icons.gps_not_fixed : Icons.gps_fixed,
                      color: _loading ? Colors.orange : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Localizando você...'
                            : (_error ?? 'Sua localização atual'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar localização',
                      onPressed: _loadLocation,
                      icon: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
