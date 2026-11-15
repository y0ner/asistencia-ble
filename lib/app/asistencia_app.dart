import 'package:flutter/material.dart';

import '../data/services/app_permissions_service.dart';
import '../features/shared/permissions_gate.dart';
import '../ui/ui_theme.dart';
import 'app_flavor.dart';

/// Raíz institucional de la aplicación con soporte para sabores de rol (Docente y Estudiante).
class AsistenciaApp extends StatelessWidget {
  const AsistenciaApp({
    super.key,
    required this.flavor,
  });

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: flavor.title,
      debugShowCheckedModeBanner: false,
      theme: UiTheme.light(),
      darkTheme: UiTheme.dark(),
      themeMode: ThemeMode.system,
      home: PermissionsGate(
        service: AppPermissionsService(needsCamera: flavor == AppFlavor.estudiante),
        child: flavor.homeScreen,
      ),
    );
  }
}
