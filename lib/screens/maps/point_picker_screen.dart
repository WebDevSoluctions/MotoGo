import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PointPickerScreen extends StatefulWidget {
  final LatLng initialPoint;
  final String title;

  const PointPickerScreen({
    super.key,
    required this.initialPoint,
    required this.title,
  });

  @override
  State<PointPickerScreen> createState() => _PointPickerScreenState();
}

class _PointPickerScreenState extends State<PointPickerScreen> {
  late LatLng _point;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: 17,
              onTap: (_, point) => setState(() => _point = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.motogo',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 52,
                    height: 52,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 48),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Text('Toque exatamente no local desejado', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _point),
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar este ponto'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
