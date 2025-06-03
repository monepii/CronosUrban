import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

void main() {
  runApp(const CronosUrbanApp());
}

class CronosUrbanApp extends StatelessWidget {
  const CronosUrbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CronosUrban',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFF00ACC1),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const CronosUrbanHomePage(),
    );
  }
}

class CronosUrbanHomePage extends StatefulWidget {
  const CronosUrbanHomePage({super.key});

  @override
  State<CronosUrbanHomePage> createState() => _CronosUrbanHomePageState();
}

class _CronosUrbanHomePageState extends State<CronosUrbanHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const MapPage(),
    const RoutesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CronosUrban'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.route),
            label: 'Rutas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location _location = Location();
  LocationData? _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      _location.onLocationChanged.listen((LocationData locationData) {
        if (mounted) {
          setState(() {
            _currentLocation = locationData;
          });
        }
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        zoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cronosurban.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        RouteCard(
          routeName: 'Ruta 1',
          startPoint: 'Punto A',
          endPoint: 'Punto B',
          estimatedTime: '30 min',
          onTap: () {
            // Implementar navegación a detalles de ruta
          },
        ),
        RouteCard(
          routeName: 'Ruta 2',
          startPoint: 'Punto C',
          endPoint: 'Punto D',
          estimatedTime: '45 min',
          onTap: () {
            // Implementar navegación a detalles de ruta
          },
        ),
      ],
    );
  }
}

class RouteCard extends StatelessWidget {
  final String routeName;
  final String startPoint;
  final String endPoint;
  final String estimatedTime;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.routeName,
    required this.startPoint,
    required this.endPoint,
    required this.estimatedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(routeName),
        subtitle: Text('$startPoint → $endPoint\nTiempo estimado: $estimatedTime'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Usuario',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial de viajes'),
            onTap: () {
              // Implementar navegación al historial
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Rutas favoritas'),
            onTap: () {
              // Implementar navegación a favoritos
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              // Implementar navegación a configuración
            },
          ),
        ],
      ),
    );
  }
}
