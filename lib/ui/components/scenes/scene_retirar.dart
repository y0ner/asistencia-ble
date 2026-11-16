import 'ui_scene_canvas.dart';

/// El profesor retira a un estudiante de la lista de la clase.
///
/// Referencia: `docs/diseno/referencias/como-funciona/retirar.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintSceneRetirar(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(60, 30, 200, 46, 14, fill: p.surface);
  g.circle(84, 53, 12, fill: p.panel);
  g.rrect(104, 49, 70, 8, 4, fill: p.ink);
  g.rrect(60, 87, 200, 46, 14, fill: p.surface, stroke: p.danger, strokeWidth: 2.5);
  g.circle(84, 110, 12, fill: p.panel);
  g.rrect(104, 106, 84, 8, 4, fill: p.ink);
  g.circle(236, 110, 12, fill: p.danger);
  g.path('M230 110 h12', stroke: UiScenePalette.paper);
  g.rrect(60, 144, 200, 46, 14, fill: p.surface);
  g.circle(84, 167, 12, fill: p.panel);
  g.rrect(104, 163, 58, 8, 4, fill: p.ink);
}
