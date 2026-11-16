import 'ui_scene_canvas.dart';

/// El celular del profesor muestra un código QR y dos estudiantes lo escanean.
///
/// Referencia: `docs/diseno/referencias/como-funciona/qr.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintSceneQr(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(58, 24, 104, 172, 20, fill: p.teacher);
  g.rrect(76, 62, 68, 68, 10, fill: UiScenePalette.paper);
  g.rrect(84, 70, 18, 18, 4, fill: UiScenePalette.paperInk);
  g.rrect(118, 70, 18, 18, 4, fill: UiScenePalette.paperInk);
  g.rrect(84, 104, 18, 18, 4, fill: UiScenePalette.paperInk);
  g.rrect(108, 94, 8, 8, 2, fill: UiScenePalette.paperInk);
  g.rrect(120, 106, 8, 8, 2, fill: UiScenePalette.paperInk);
  g.rrect(130, 116, 6, 6, 2, fill: UiScenePalette.paperInk);
  g.rrect(108, 114, 6, 8, 2, fill: UiScenePalette.paperInk);
  g.rrect(88, 146, 44, 8, 4, fill: p.onTeacher, opacity: 0.55);
  g.path('M176 86 L206 74', stroke: p.accent, dash: [2, 8]);
  g.path('M176 134 L206 146', stroke: p.accent, dash: [2, 8]);
  g.rrect(214, 34, 50, 82, 12, fill: p.surface, stroke: p.ink);
  g.path('M228 62 v-8 h8 M250 62 v-8 h-8 M228 86 v8 h8 M250 86 v8 h-8', stroke: p.accent);
  g.rrect(232, 112, 50, 82, 12, fill: p.surface, stroke: p.ink);
  g.path('M246 140 v-8 h8 M268 140 v-8 h-8 M246 164 v8 h8 M268 164 v8 h-8', stroke: p.accent);
}
