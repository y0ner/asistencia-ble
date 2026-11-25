import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pinta el dibujo [kind] en el momento [t] (0 a 1) y devuelve sus píxeles
/// RGBA de 320 × 220.
Future<Uint8List> sceneFrame(
  WidgetTester tester,
  UiSceneKind kind,
  double t, {
  bool dark = false,
  bool studentView = false,
}) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final palette = UiScenePalette.fromColors(dark ? UiColors.dark : UiColors.light, dark: dark);
    uiScenePaintOf(kind)(UiSceneCanvas(canvas, palette, studentView: studentView), t);
    final image = await recorder.endRecording().toImage(320, 220);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Cantidad de píxeles pintados (no transparentes).
int paintedPixels(Uint8List rgba) {
  var count = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) count++;
  }
  return count;
}

/// Cantidad de píxeles que cambian entre dos cuadros.
int changedPixels(Uint8List a, Uint8List b) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) count++;
  }
  return count;
}

/// Comprueba que el dibujo [kind] cumple las reglas de un dibujo animado:
///
/// 1. Se pinta sin errores en todo el ciclo, en claro y en oscuro.
/// 2. Se mueve: hay cuadros distintos a lo largo del ciclo.
/// 3. En reposo ([UiScene.restT]) está completo: tiene al menos tantos
///    píxeles pintados como [minRestPixels].
/// 4. No se sale del lienzo ni lo tapa entero.
Future<void> expectSceneAnimates(WidgetTester tester, UiSceneKind kind, {int minRestPixels = 6000}) async {
  for (final dark in [false, true]) {
    final frames = <Uint8List>[];
    for (var i = 0; i <= 20; i++) {
      frames.add(await sceneFrame(tester, kind, i / 20, dark: dark));
    }
    final rest = await sceneFrame(tester, kind, UiScene.restT, dark: dark);
    final moving = [
      for (var i = 1; i < frames.length; i++) changedPixels(frames[i - 1], frames[i]),
    ].where((changed) => changed > 20).length;
    expect(moving, greaterThanOrEqualTo(6), reason: '${kind.name}: casi no se mueve (oscuro: $dark)');
    expect(paintedPixels(rest), greaterThanOrEqualTo(minRestPixels), reason: '${kind.name}: en reposo está incompleto');
    for (final frame in frames) {
      expect(paintedPixels(frame), lessThan(320 * 220 * 0.8), reason: '${kind.name}: tapa casi todo el lienzo');
    }
  }
}
