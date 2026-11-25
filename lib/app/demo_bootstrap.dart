import 'package:flutter/foundation.dart';

import '../data/services/demo_seed_service.dart';

/// `true` cuando la app se compila con `--dart-define=DEMO_SEED=true`
/// (`DEMO_SEED=true ./run.sh apk`).
const bool kDemoSeed = bool.fromEnvironment('DEMO_SEED');

/// Carga la clase de demostración (12 estudiantes ficticios, 4 sesiones
/// cerradas y la credencial del estudiante del bit 0) antes de abrir la app.
///
/// Solo actúa en compilaciones con [kDemoSeed]; sirve para capturas de
/// pantalla y presentaciones. Si la clase ya existe no duplica nada ni borra
/// los datos del celular.
Future<void> seedDemoIfRequested() async {
  if (!kDemoSeed) {
    return;
  }
  try {
    await DemoSeedService().seedDefenseDemonstrationData();
  } on Object catch (error, stackTrace) {
    // La demostración es opcional: si falla, la app abre igual y queda el registro.
    debugPrint('No se pudo cargar la clase de demostración: $error\n$stackTrace');
  }
}
