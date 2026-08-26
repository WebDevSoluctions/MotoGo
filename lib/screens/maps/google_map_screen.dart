import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {

  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;

  Position? _currentPosition;

  bool loading = true;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    loadLocation();
  }

  Future<void> loadLocation() async {

    try {

      final position =
          await _locationService.getCurrentLocation();

      _currentPosition = position;

      _markers.add(

        Marker(

          markerId: const MarkerId("me"),

          position: LatLng(
            position.latitude,
            position.longitude,
          ),

          infoWindow: const InfoWindow(
            title: "Minha localização",
          ),

        ),

      );

      setState(() {

        loading = false;

      });

    } catch (e) {

      setState(() {

        loading = false;

      });

    }

  }

  @override
  Widget build(BuildContext context) {

    if (loading) {

      return const Scaffold(

        body: Center(

          child: CircularProgressIndicator(),

        ),

      );

    }

    if (_currentPosition == null) {

      return Scaffold(

        appBar: AppBar(
          title: const Text("Google Maps"),
        ),

        body: const Center(

          child: Text(

            "Não foi possível obter sua localização.",

          ),

        ),

      );

    }

    return Scaffold(

      appBar: AppBar(

        title: const Text("MotoGo Map"),

      ),

      body: GoogleMap(

        initialCameraPosition: CameraPosition(

          target: LatLng(

            _currentPosition!.latitude,

            _currentPosition!.longitude,

          ),

          zoom: 16,

        ),

        myLocationEnabled: true,

        myLocationButtonEnabled: true,

        zoomControlsEnabled: false,

        compassEnabled: true,

        markers: _markers,

        onMapCreated: (controller) {

          _mapController = controller;

        },

      ),

      floatingActionButton: FloatingActionButton(

        onPressed: () {

          if (_currentPosition == null) return;

          _mapController?.animateCamera(

            CameraUpdate.newLatLng(

              LatLng(

                _currentPosition!.latitude,

                _currentPosition!.longitude,

              ),

            ),

          );

        },

        child: const Icon(Icons.my_location),

      ),

    );

  }

}