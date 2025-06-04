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
  List<LatLng> routePoints = [];
  LatLng destination = LatLng(19.264208184378365, -99.12763714268449);
  PredefinedRoute? selectedRoute;
  bool _showInfo = true;

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
    Future.delayed(const Duration(seconds: 1), _fetchCount);
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

  // Función para encontrar el punto más cercano de la ruta
  LatLng findNearestPoint() {
    if (_currentLocation == null || selectedRoute == null) {
      return selectedRoute!.start;
    }

    final currentPoint = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    LatLng nearestPoint = selectedRoute!.start;
    double minDistance = calculateDistance(currentPoint, selectedRoute!.start);

    // Revisar todas las paradas de la ruta
    for (var stop in selectedRoute!.stopCoordinates) {
      final distance = calculateDistance(currentPoint, stop);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = stop;
      }
    }

    return nearestPoint;
  }

  Future<void> _getETA() async {
    if (_currentLocation == null || selectedRoute == null) {
      setState(() => _etaResult = "Ubicación no disponible.");
      return;
    }

    final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    const apiKey = 'AIzaSyDCRW7VzRxVKkwr8z6FdjgBLgT7i8KvAtg';

    try {
      // Encontrar el punto más cercano de la ruta
      LatLng nearestPoint = selectedRoute!.waypoints[0];
      double minDistance = double.infinity;
      
      for (var point in selectedRoute!.waypoints) {
        final distance = calculateDistance(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          point
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestPoint = point;
        }
      }

      // Calcular tiempo caminando hasta el punto más cercano
      final walkingUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=${nearestPoint.latitude},${nearestPoint.longitude}'
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
      final walkingPoints = PolylinePoints()
          .decodePolyline(walkingData['routes'][0]['overview_polyline']['points'])
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Calcular el tiempo restante desde el punto más cercano hasta el destino
      final remainingTimeMinutes = calculateRemainingTime(nearestPoint, selectedRoute!.waypoints, selectedRoute!.estimatedTime);

      setState(() {
        _etaResult = "Tiempo caminando hasta la ruta: $walkingDuration\n"
            "Tiempo restante hasta destino: $remainingTimeMinutes minutos";
        
        // Combinar las rutas: ruta a pie + ruta del transporte
        routePoints = [
          ...walkingPoints,
          ...selectedRoute!.waypoints,
        ];

        // Ajustar el mapa para mostrar toda la ruta
        if (routePoints.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints([
            ...routePoints,
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            selectedRoute!.end,
          ]);
          
          _mapController.fitBounds(
            bounds,
            options: const FitBoundsOptions(
              padding: EdgeInsets.all(50.0),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _etaResult = "Error al calcular la ruta: $e";
        routePoints = [];
      });
    }
  }

  // Función para calcular el tiempo restante basado en la distancia proporcional
  int calculateRemainingTime(LatLng nearestPoint, List<LatLng> waypoints, String totalTime) {
    // Convertir el tiempo total estimado a minutos
    final totalMinutes = int.parse(totalTime.split(' ')[0]);
    
    // Encontrar el índice del punto más cercano
    int nearestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < waypoints.length; i++) {
      final distance = calculateDistance(nearestPoint, waypoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    // Calcular la distancia total de la ruta
    double totalDistance = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += calculateDistance(waypoints[i], waypoints[i + 1]);
    }

    // Calcular la distancia restante desde el punto más cercano
    double remainingDistance = 0;
    for (int i = nearestIndex; i < waypoints.length - 1; i++) {
      remainingDistance += calculateDistance(waypoints[i], waypoints[i + 1]);
    }

    // Calcular el tiempo restante proporcional
    return (totalMinutes * remainingDistance / totalDistance).round();
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
        // Usar los waypoints de la ruta directamente
        routePoints = List<LatLng>.from(result.waypoints);
      });

      // Ajustar el mapa para mostrar toda la ruta
      if (routePoints.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints([
          ...routePoints,
          if (_currentLocation != null)
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        ]);
        
        _mapController.fitBounds(
          bounds,
          options: const FitBoundsOptions(
            padding: EdgeInsets.all(50.0),
          ),
        );
      }

      _getETA();
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
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentLocation != null
                        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                        : LatLng(19.264208, -99.127637),
                    zoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          // Ruta completa (sólida)
                          Polyline(
                            points: routePoints,
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
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        if (selectedRoute != null) ...[
                          // Marcador de inicio de ruta
                          Marker(
                            point: selectedRoute!.start,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.trip_origin,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Marcadores para cada parada
                          ...selectedRoute!.stopCoordinates.map((coord) => Marker(
                            point: coord,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.circle,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          )),
                          // Marcador de destino
                          Marker(
                            point: selectedRoute!.end,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  color: backgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'CronusUrban',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: textColor,
                              letterSpacing: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _showInfo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: textColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showInfo = !_showInfo;
                                });
                              },
                              tooltip: _showInfo ? 'Ocultar información' : 'Mostrar información',
                            ),
                            if (_showInfo) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                  color: textColor,
                                ),
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
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.gps_fixed, color: textColor),
                                onPressed: _getLocation,
                                tooltip: 'Mi ubicación',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showInfo) ...[
                  Container(
                    color: backgroundColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openPredefinedRoutes,
                          icon: const Icon(Icons.route),
                          label: const Text('Ver Rutas Disponibles'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (selectedRoute != null) ...[
                          Text(
                            selectedRoute!.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tiempo estimado: ${selectedRoute!.estimatedTime}',
                            style: TextStyle(color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Próxima salida: ${selectedRoute!.schedule}',
                            style: TextStyle(color: textColor),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_currentLocation != null && _showInfo)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: textColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Información',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_currentLocation!.speed != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speed, color: Theme.of(context).primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Velocidad: ${(_currentLocation!.speed! * 3.6).toStringAsFixed(1)} km/h',
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (selectedRoute != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isAlmostFull ? Colors.orange : Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people,
                                  color: isAlmostFull ? Colors.orange : Colors.green,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  personCount.toString(),
                                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    color: isAlmostFull ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Personas detectadas',
                              style: TextStyle(
                                color: isAlmostFull ? Colors.orange : Colors.green,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                              decoration: BoxDecoration(
                                color: (isAlmostFull ? Colors.orange : Colors.green).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Lugares disponibles: $availableSpots',
                                style: TextStyle(
                                  color: isAlmostFull ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_etaResult.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _etaResult.split('\n')[0],
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_bus,
                                      color: Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _etaResult.split('\n')[1],
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          // Botones de zoom
          Positioned(
            right: 16,
            bottom: _showInfo ? 300 : 16, // Ajusta la posición según si el panel de información está visible
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final currentZoom = _mapController.zoom;
                      _mapController.move(_mapController.center, currentZoom + 1);
                    },
                    tooltip: 'Acercar',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      final currentZoom = _mapController.zoom;
                      _mapController.move(_mapController.center, currentZoom - 1);
                    },
                    tooltip: 'Alejar',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
