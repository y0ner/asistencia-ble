import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_probe.dart';

void main() {
  for (final kind in [
    UiSceneKind.pin,
    UiSceneKind.teclado,
    UiSceneKind.listo,
    UiSceneKind.presente,
    UiSceneKind.amano,
    UiSceneKind.excel,
  ]) {
    testWidgets('el dibujo ${kind.name} se anima y queda completo en reposo', (tester) async {
      await expectSceneAnimates(tester, kind);
    });
  }
}
