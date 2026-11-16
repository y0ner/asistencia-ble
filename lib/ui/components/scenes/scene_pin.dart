import 'ui_scene_canvas.dart';

/// El celular del profesor muestra un PIN de dos números y el profesor lo dice en voz alta.
///
/// Referencia: `docs/diseno/referencias/como-funciona/pin.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintScenePin(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(48, 24, 112, 172, 20, fill: p.teacher);
  g.rrect(80, 48, 48, 8, 4, fill: p.onTeacher, opacity: 0.55);
  g.rrect(64, 72, 36, 52, 10, fill: UiScenePalette.paper);
  g.rrect(108, 72, 36, 52, 10, fill: UiScenePalette.paper);
  g.text('4', 82, 109, size: 32, color: UiScenePalette.paperInk);
  g.text('7', 126, 109, size: 32, color: UiScenePalette.paperInk);
  g.rrect(72, 146, 64, 8, 4, fill: p.onTeacher, opacity: 0.3);
  g.rrect(84, 162, 40, 8, 4, fill: p.onTeacher, opacity: 0.3);
  g.path('M192 62 h72 a16 16 0 0 1 16 16 v36 a16 16 0 0 1 -16 16 h-44 l-18 16 v-16 h-10 a16 16 0 0 1 -16 -16 v-36 a16 16 0 0 1 16 -16 z', fill: p.surface, stroke: p.ink);
  g.text('4 7', 228, 108, size: 30, color: p.ink);
  g.path('M176 160 q8 8 0 16 M188 152 q16 16 0 32', stroke: p.accent, strokeWidth: 3.5);
}
