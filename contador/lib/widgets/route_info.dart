import 'package:flutter/material.dart';
import '../screens/predefined_routes.dart';

class RouteInfo extends StatelessWidget {
  final PredefinedRoute? selectedRoute;
  final int personCount;
  final String etaResult;
  final VoidCallback onOpenRoutes;
  final VoidCallback onUpdateETA;
  final Color backgroundColor;
  final Color textColor;

  const RouteInfo({
    Key? key,
    required this.selectedRoute,
    required this.personCount,
    required this.etaResult,
    required this.onOpenRoutes,
    required this.onUpdateETA,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final availableSpots = 20 - personCount;
    final isAlmostFull = availableSpots <= 5;

    if (selectedRoute == null) {
      return ElevatedButton.icon(
        onPressed: onOpenRoutes,
        icon: const Icon(Icons.route),
        label: const Text('Ver Rutas Disponibles'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CounterBadge(
                icon: Icons.people,
                text: '$personCount personas',
                isAlmostFull: isAlmostFull,
              ),
              _CounterBadge(
                icon: Icons.event_seat,
                text: '$availableSpots disponibles',
                isAlmostFull: isAlmostFull,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (etaResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: etaResult
                    .split('\n')
                    .map((text) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                text.contains('🚶‍♂️')
                                    ? Icons.directions_walk
                                    : Icons.directions_bus,
                                color: Theme.of(context).primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text.replaceAll('🚶‍♂️ ', '').replaceAll('🚌 ', ''),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenRoutes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cambiar Ruta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onUpdateETA,
                  icon: const Icon(Icons.update),
                  label: const Text('Actualizar Tiempo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isAlmostFull;

  const _CounterBadge({
    required this.icon,
    required this.text,
    required this.isAlmostFull,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: (isAlmostFull ? Colors.orange : Colors.green).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isAlmostFull ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isAlmostFull ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
} 