import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class MapControls extends StatelessWidget {
  final MapController mapController;
  final bool showInfo;
  final LocationData? currentLocation;
  final List<LatLng> busRoutePoints;
  final List<LatLng> walkingPoints;

  const MapControls({
    Key? key,
    required this.mapController,
    required this.showInfo,
    required this.currentLocation,
    required this.busRoutePoints,
    required this.walkingPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: showInfo ? 300 : 16,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _ZoomButton(
              icon: Icons.add,
              onTap: () {
                final currentZoom = mapController.zoom;
                mapController.move(mapController.center, currentZoom + 1);
              },
              isTop: true,
            ),
            Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
            _CenterButton(
              mapController: mapController,
              currentLocation: currentLocation,
              busRoutePoints: busRoutePoints,
              walkingPoints: walkingPoints,
            ),
            Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
            _ZoomButton(
              icon: Icons.remove,
              onTap: () {
                final currentZoom = mapController.zoom;
                mapController.move(mapController.center, currentZoom - 1);
              },
              isTop: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isTop ? 8 : 0),
          bottom: Radius.circular(isTop ? 0 : 8),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final MapController mapController;
  final LocationData? currentLocation;
  final List<LatLng> busRoutePoints;
  final List<LatLng> walkingPoints;

  const _CenterButton({
    required this.mapController,
    required this.currentLocation,
    required this.busRoutePoints,
    required this.walkingPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (currentLocation != null && busRoutePoints.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints([
              ...busRoutePoints,
              ...walkingPoints,
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
            ]);
            mapController.fitBounds(
              bounds,
              options: const FitBoundsOptions(
                padding: EdgeInsets.all(50.0),
              ),
            );
          } else if (currentLocation != null) {
            mapController.move(
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
              15,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.center_focus_strong,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
} 