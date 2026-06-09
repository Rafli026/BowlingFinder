import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/post.dart';

class MapScreen extends StatefulWidget {
  final Post post;

  const MapScreen({super.key, required this.post});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  LatLng get _venueLatLng =>
      LatLng(widget.post.latitude, widget.post.longitude);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi belum diberikan')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      Marker(
        point: _venueLatLng,
        width: 56,
        height: 56,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 48),
      ),
    ];

    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 48,
          height: 48,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 34),
        ),
      );
    }

    return markers;
  }

  Future<void> _focusMyLocation() async {
    if (_currentPosition == null) {
      await _loadCurrentLocation();
    }
    if (_currentPosition == null) return;

    _mapController.move(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      15,
    );
  }

  void _focusVenue() {
    _mapController.move(_venueLatLng, 15);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.post.name)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _venueLatLng, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bowling',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'focus_venue',
                  onPressed: _focusVenue,
                  tooltip: 'Lokasi arena',
                  child: const Icon(Icons.place),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'focus_me',
                  onPressed: _isLoadingLocation ? null : _focusMyLocation,
                  tooltip: 'Lokasi saya',
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        color: colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.post.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Arena: ${widget.post.latitude.toStringAsFixed(6)}, ${widget.post.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (_currentPosition != null)
                Text(
                  'Saya: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}