import 'ui_scene_canvas.dart';

/// Un estudiante cambia su celular anterior por uno nuevo.
///
/// Referencia: `docs/diseno/referencias/como-funciona/cambio.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintSceneCambio(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(44, 40, 84, 140, 18, stroke: p.muted, dash: [7, 7]);
  g.circle(86, 98, 16, stroke: p.danger);
  g.path('M75 109 l22 -22', stroke: p.danger);
  g.rrect(64, 134, 44, 7, 3.5, fill: p.muted, opacity: 0.6);
  g.path('M142 110 h34 M164 97 l13 13 l-13 13', stroke: p.accent, strokeWidth: 4);
  g.rrect(192, 40, 84, 140, 18, fill: p.surface, stroke: p.ink);
  g.circle(234, 98, 18, fill: p.teacher);
  g.path('M226 98 l6 6 l11 -12', stroke: p.onTeacher, strokeWidth: 4);
  g.rrect(210, 132, 48, 8, 4, fill: p.ink);
  g.rrect(218, 148, 32, 7, 3.5, fill: p.muted, opacity: 0.6);
}
