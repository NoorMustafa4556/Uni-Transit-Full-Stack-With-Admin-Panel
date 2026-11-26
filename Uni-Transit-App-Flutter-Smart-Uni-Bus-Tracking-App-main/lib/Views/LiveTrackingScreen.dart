import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/ViewModels/BusProvider.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';
import 'package:uni_transit/Widgets/TrackMyTrainSheet.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final liveBuses = ref.watch(busProvider).liveBusData;

    List<Marker> markers = [];
    liveBuses.forEach((busNum, row) {
      final double lat = (row['latitude'] is num) ? (row['latitude'] as num).toDouble() : 0.0;
      final double lng = (row['longitude'] is num) ? (row['longitude'] as num).toDouble() : 0.0;
      if (lat != 0.0 && lng != 0.0) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 100,
            height: 100,
            child: GestureDetector(
              onTap: () {
                TrackMyTrainSheet.show(
                  context,
                  busNumber: busNum,
                  gender: row['gender']?.toString() ?? 'Combined',
                  crowdStatus: row['crowdStatus']?.toString() ?? 'seats_available',
                );
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      busNum,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.orange,
                    size: 36,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(title: "Live Bus Tracking"),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(29.3794, 71.6707), // IUB Baghdad-ul-Jadeed Campus
          initialZoom: 13.5,
          interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.uni_transit',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "live_zoom_in",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom + 1);
            },
            child: const Icon(Icons.add, color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "live_zoom_out",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, currentZoom - 1);
            },
            child: const Icon(Icons.remove, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
