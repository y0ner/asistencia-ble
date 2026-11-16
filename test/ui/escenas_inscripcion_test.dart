import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_probe.dart';

void main() {
  for (final kind in [
    UiSceneKind.qr,
    UiSceneKind.escanear,
    UiSceneKind.codigo,
    UiSceneKind.aprobar,
    UiSceneKind.cambio,
    UiSceneKind.retirar,
  ]) {
    testWidgets('el dibujo ${kind.name} se anima y queda completo en reposo', (tester) async {
      await expectSceneAnimates(tester, kind);
    });
  }
}
