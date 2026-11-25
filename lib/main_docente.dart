import 'package:flutter/material.dart';

import 'app/app_flavor.dart';
import 'app/asistencia_app.dart';
import 'app/demo_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await seedDemoIfRequested();
  runApp(const AsistenciaApp(flavor: AppFlavor.docente));
}
