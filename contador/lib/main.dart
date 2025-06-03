import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Datsun',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const PersonCounterMapScreen(),
    );
  }
}

class PersonCounterMapScreen extends StatefulWidget {
  const PersonCounterMapScreen({super.key});

  @override
  State<PersonCounterMapScreen> createState() => _PersonCounterMapScreenState();
}

class _PersonCounterMapScreenState extends State<PersonCounterMapScreen> with SingleTickerProviderStateMixin {
  int personCount = 0;
  String _etaResult = '';
  LocationData? _currentLocation;
  final Location _locationService = Location();
  final MapController _mapController = MapController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<LatLng> routePoints = [];
  final LatLng destination = LatLng(19.264208184378365, -99.12763714268449);

  @override
  void initState() {
    super.initState();
    _fetchCount();
    _getLocation();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _locationService.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _locationService.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    final loc = await _locationService.getLocation();
    setState(() {
      _currentLocation = loc;
    });

    // Centrar el mapa en la ubicación
    _mapController.move(LatLng(loc.latitude!, loc.longitude!), 15);
  }

  Future<void> _fetchCount() async {
    try {
      final response = await http.get(Uri.parse('https://contador-personas.vercel.app/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          personCount = data['person_count'];
        });
      }
    } catch (e) {
      print("Error al obtener el contador: $e");
    }
    Future.delayed(const Duration(seconds: 1), _fetchCount);
  }

  Future<void> _getETA() async {
    if (_currentLocation == null) {
      setState(() => _etaResult = "Ubicación no disponible.");
      return;
    }

    final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    final dest = '${destination.latitude},${destination.longitude}';
    const apiKey = 'AIzaSyDCRW7VzRxVKkwr8z6FdjgBLgT7i8KvAtg';

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&departure_time=now&key=$apiKey',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'].isNotEmpty) {
          final duration = data['routes'][0]['legs'][0]['duration']['text'];
          final points = data['routes'][0]['overview_polyline']['points'];
          final polylinePoints = PolylinePoints();
          final result = polylinePoints.decodePolyline(points);
          setState(() {
            _etaResult = "ETA: $duration";
            routePoints = result
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          });
          final bounds = LatLngBounds.fromPoints(routePoints);
          _mapController.fitBounds(
            bounds,
            options: const FitBoundsOptions(
              padding: EdgeInsets.all(50.0),
            ),
          );
        } else {
          setState(() {
            _etaResult = "No se encontró una ruta.";
            routePoints = [];
          });
        }
      } else {
        setState(() {
          _etaResult = "Error: ${response.statusCode}";
          routePoints = [];
        });
      }
    } catch (e) {
      setState(() {
        _etaResult = "Error al obtener ETA: $e";
        routePoints = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSpots = 20 - personCount;
    final isAlmostFull = availableSpots <= 5;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(19.4326, -99.1332),
                    zoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isDarkMode 
                        ? "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key=501b0973-6c5f-495f-9fb5-6bf036172887"
                        : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                      userAgentPackageName: 'com.tuempresa.tuapp',
                    ),
                    PolylineLayer(
                      polylines: [
                        if (routePoints.isNotEmpty)
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.0,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                            width: 60,
                            height: 60,
                            child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                          ),
                        Marker(
                          point: destination,
                          width: 60,
                          height: 60,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CronusUrban',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                            color: Theme.of(context).colorScheme.primary,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                            letterSpacing: 2.0,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                              onPressed: () {
                                final platform = Theme.of(context).platform;
                                if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cambiar tema'),
                                      content: const Text('El tema se ajusta automáticamente según la configuración de tu dispositivo. Puedes cambiarlo en los ajustes del sistema.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              tooltip: 'Cambiar tema',
                            ),
                            IconButton(
                              icon: const Icon(Icons.gps_fixed),
                              onPressed: _getLocation,
                              tooltip: 'Mi ubicación',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _animation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isAlmostFull ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              personCount.toString(),
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: isAlmostFull ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Personas detectadas',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isAlmostFull ? Colors.orange : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lugares disponibles: $availableSpots',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isAlmostFull ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _getETA,
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Calcular tiempo de llegada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_etaResult.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _etaResult,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          if (_currentLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Información',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Latitud: ${_currentLocation!.latitude?.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),  
                      Text(
                        'Longitud: ${_currentLocation!.longitude?.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_currentLocation!.speed != null)
                        Text(
                          'Velocidad: ${(_currentLocation!.speed! * 3.6).toStringAsFixed(1)} km/h',
                          style: Theme.of(context).textTheme.bodyMedium,
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
