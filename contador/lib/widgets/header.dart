import 'package:flutter/material.dart';
import '../screens/predefined_routes.dart';

class Header extends StatelessWidget {
  final bool showInfo;
  final Function(bool) onShowInfoChanged;
  final VoidCallback onLocationPressed;
  final PredefinedRoute? selectedRoute;
  final Color backgroundColor;
  final Color textColor;

  const Header({
    Key? key,
    required this.showInfo,
    required this.onShowInfoChanged,
    required this.onLocationPressed,
    required this.selectedRoute,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor,
            backgroundColor.withOpacity(0.9),
            backgroundColor.withOpacity(0),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CronusUrban',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      showInfo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: textColor,
                    ),
                    onPressed: () => onShowInfoChanged(!showInfo),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.my_location,
                      color: textColor,
                    ),
                    onPressed: onLocationPressed,
                  ),
                ],
              ),
            ],
          ),
          if (showInfo && selectedRoute != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedRoute!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Próxima salida: ${selectedRoute!.schedule}',
                      style: TextStyle(color: textColor.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 