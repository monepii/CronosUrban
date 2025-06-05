import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'screens/predefined_routes.dart';
import 'widgets/header.dart';
import 'widgets/route_info.dart';
import 'widgets/map_controls.dart';
import 'dart:math';

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
  List<LatLng> busRoutePoints = []; // Ruta completa del autobús
  List<LatLng> walkingPoints = []; // Ruta caminando hasta el punto más cercano
  LatLng? nearestBusPoint; // Punto más cercano de la ruta del autobús
  LatLng destination = LatLng(19.264208184378365, -99.12763714268449);
  PredefinedRoute? selectedRoute;
  bool _showInfo = true;
  Timer? _locationTimer;
  Timer? _countTimer;
  bool _isCalculatingRoute = false;

  @override
  void initState() {
    super.initState();
    _setupLocationUpdates();
    _setupCountUpdates();
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

  void _setupLocationUpdates() {
    _getLocation(); // Obtener ubicación inicial
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getLocation(); // Actualizar ubicación cada 10 segundos
    });
    _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000,
      distanceFilter: 10,
    );
  }

  void _setupCountUpdates() {
    _fetchCount(); // Obtener conteo inicial
    _countTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchCount(); // Actualizar conteo cada 5 segundos
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countTimer?.cancel();
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
  }

  Future<void> _fetchCount() async {
    try {
      final response = await http.get(Uri.parse('http://172.20.10.10:5000/person_count'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          personCount = data['person_count'];
        });
      }
    } catch (e) {
      print("Error al obtener el contador: $e");
    }
  }

  // Función para calcular la distancia entre dos puntos
  double calculateDistance(LatLng point1, LatLng point2) {
    const double radius = 6371e3; // Radio de la Tierra en metros
    final phi1 = point1.latitude * pi / 180;
    final phi2 = point2.latitude * pi / 180;
    final deltaPhi = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLambda = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c; // Distancia en metros
  }

  Future<void> _updateRouteBasedOnLocation() async {
    if (_currentLocation == null || selectedRoute == null) return;

    _isCalculatingRoute = true;
    try {
      // Encontrar el punto más cercano de la ruta
      LatLng newNearestPoint = selectedRoute!.waypoints[0];
      double minDistance = double.infinity;
      int nearestIndex = 0;

      for (int i = 0; i < selectedRoute!.waypoints.length; i++) {
        final point = selectedRoute!.waypoints[i];
        final distance = calculateDistance(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          point
        );
        if (distance < minDistance) {
          minDistance = distance;
          newNearestPoint = point;
          nearestIndex = i;
        }
      }

      setState(() {
        nearestBusPoint = newNearestPoint;
      });
      
      await _getETA();
    } finally {
      _isCalculatingRoute = false;
    }
  }

  // Función para calcular el tiempo restante basado en la distancia proporcional
  int calculateRemainingTime(LatLng startPoint, List<LatLng> routePoints, String totalTime) {
    // Extraer el rango de tiempo (ej: de "25-60 minutos (según horario)" obtiene "25-60")
    final timeRange = totalTime.split(' ')[0];
    final times = timeRange.split('-');
    final minMinutes = int.parse(times[0]);
    final maxMinutes = int.parse(times[1]);
    // Usar el tiempo promedio del rango
    final averageMinutes = (minMinutes + maxMinutes) ~/ 2;
    
    // Encontrar el índice del punto más cercano en la ruta
    int startIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < routePoints.length; i++) {
      final distance = calculateDistance(startPoint, routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        startIndex = i;
      }
    }

    // Calcular la distancia total de la ruta original
    double totalDistance = 0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      totalDistance += calculateDistance(routePoints[i], routePoints[i + 1]);
    }

    // Calcular la distancia desde el punto más cercano hasta el final
    double remainingDistance = 0;
    for (int i = startIndex; i < routePoints.length - 1; i++) {
      remainingDistance += calculateDistance(routePoints[i], routePoints[i + 1]);
    }

    // Calcular el tiempo proporcional basado en la distancia restante
    return (averageMinutes * remainingDistance / totalDistance).round();
  }

  Future<void> _getETA() async {
    if (_currentLocation == null || selectedRoute == null || nearestBusPoint == null) {
      setState(() => _etaResult = "Ubicación no disponible.");
      return;
    }

    final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    const apiKey = 'AIzaSyDCRW7VzRxVKkwr8z6FdjgBLgT7i8KvAtg';

    try {
      // Calcular tiempo caminando hasta el punto más cercano
      final walkingUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=${nearestBusPoint!.latitude},${nearestBusPoint!.longitude}'
        '&mode=walking'
        '&key=$apiKey'
      );

      final walkingResponse = await http.get(walkingUri);
      if (walkingResponse.statusCode != 200) {
        setState(() => _etaResult = "Error al calcular la ruta a pie.");
        return;
      }

      final walkingData = jsonDecode(walkingResponse.body);
      if (walkingData['routes'].isEmpty) {
        setState(() => _etaResult = "No se encontró ruta a pie.");
        return;
      }

      final walkingDuration = walkingData['routes'][0]['legs'][0]['duration']['text'];
      final newWalkingPoints = PolylinePoints()
          .decodePolyline(walkingData['routes'][0]['overview_polyline']['points'])
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Calcular el tiempo restante desde el punto más cercano hasta el destino
      final remainingTimeMinutes = calculateRemainingTime(nearestBusPoint!, selectedRoute!.waypoints, selectedRoute!.estimatedTime);

      // Formatear el tiempo restante
      final String remainingTimeText;
      if (remainingTimeMinutes >= 60) {
        final hours = remainingTimeMinutes ~/ 60;
        final minutes = remainingTimeMinutes % 60;
        if (minutes > 0) {
          remainingTimeText = "$hours h $minutes min";
        } else {
          remainingTimeText = "$hours h";
        }
      } else {
        remainingTimeText = "$remainingTimeMinutes min";
      }

      setState(() {
        _etaResult = "🚶‍♂️ Tiempo caminando hasta la parada: $walkingDuration\n"
            "🚌 Tiempo en transporte: $remainingTimeText";
        
        // Actualizar la ruta caminando solo si se solicitó explícitamente
        walkingPoints = newWalkingPoints;
      });
    } catch (e) {
      setState(() {
        _etaResult = "Error al calcular la ruta: $e";
        walkingPoints = [];
      });
    }
  }

  Future<void> _openPredefinedRoutes() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PredefinedRoutesScreen()),
    );

    if (result != null && result is PredefinedRoute) {
      setState(() {
        selectedRoute = result;
        destination = result.end;
        // Mantener la ruta completa del autobús
        busRoutePoints = List<LatLng>.from(result.waypoints);
        // Limpiar la ruta caminando hasta que se calcule
        walkingPoints = [];
        nearestBusPoint = null;
      });

      if (_currentLocation != null) {
        await _updateRouteBasedOnLocation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSpots = 20 - personCount;
    final isAlmostFull = availableSpots <= 5;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black87 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation != null
                  ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                  : LatLng(19.264208, -99.127637),
              zoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _showInfo = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (walkingPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: walkingPoints,
                      strokeWidth: 4.0,
                      color: Colors.blue.withOpacity(0.8),
                      isDotted: true,
                    ),
                  ],
                ),
              if (busRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: busRoutePoints,
                      strokeWidth: 5.0,
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                      isDotted: false,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.person_pin_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  if (selectedRoute != null) ...[
                    // Marcador de inicio
                    Marker(
                      point: selectedRoute!.start,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // Marcador de fin
                    Marker(
                      point: selectedRoute!.end,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                  if (nearestBusPoint != null)
                    Marker(
                      point: nearestBusPoint!,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Header(
              showInfo: _showInfo,
              onShowInfoChanged: (value) => setState(() => _showInfo = value),
              onLocationPressed: () {
                _getLocation();
                if (_currentLocation != null) {
                  _mapController.move(
                    LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                    15,
                  );
                }
              },
              selectedRoute: selectedRoute,
              backgroundColor: backgroundColor,
              textColor: textColor,
            ),
          ),
          if (_showInfo)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: RouteInfo(
                selectedRoute: selectedRoute,
                personCount: personCount,
                etaResult: _etaResult,
                onOpenRoutes: _openPredefinedRoutes,
                onUpdateETA: _getETA,
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
            ),
          MapControls(
            mapController: _mapController,
            showInfo: _showInfo,
            currentLocation: _currentLocation,
            busRoutePoints: busRoutePoints,
            walkingPoints: walkingPoints,
          ),
        ],
      ),
    );
  }
}
