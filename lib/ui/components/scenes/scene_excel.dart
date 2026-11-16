import 'ui_scene_canvas.dart';

/// Una hoja de asistencia firmada lista para enviar.
///
/// Referencia: `docs/diseno/referencias/como-funciona/excel.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintSceneExcel(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(78, 22, 132, 176, 16, fill: p.surface, stroke: p.ink);
  g.rrect(94, 40, 100, 18, 6, fill: p.teacher);
  g.rrect(94, 66, 52, 8, 4, fill: p.ink);
  g.rrect(94, 84, 60, 8, 4, fill: p.ink);
  g.rrect(94, 102, 44, 8, 4, fill: p.ink);
  g.rrect(94, 120, 56, 8, 4, fill: p.ink);
  g.circle(172, 70, 5, fill: p.teacher);
  g.circle(188, 70, 5, fill: p.teacher);
  g.circle(172, 88, 5, fill: p.teacher);
  g.circle(188, 88, 5, stroke: p.danger, strokeWidth: 2);
  g.circle(172, 106, 5, fill: p.teacher);
  g.circle(188, 106, 5, fill: p.teacher);
  g.circle(172, 124, 5, stroke: p.danger, strokeWidth: 2);
  g.circle(188, 124, 5, fill: p.teacher);
  g.path('M94 146 h100', stroke: p.line, strokeWidth: 2);
  g.circle(110, 172, 14, fill: p.teacher);
  g.path('M103 172 l5 5 l9 -10', stroke: p.onTeacher, strokeWidth: 3.2);
  g.rrect(134, 162, 56, 8, 4, fill: p.ink);
  g.rrect(134, 176, 36, 7, 3.5, fill: p.muted, opacity: 0.6);
  g.circle(238, 60, 28, fill: p.accent);
  g.path('M227 71 l22 -22 M233 49 h16 v16', stroke: UiScenePalette.paperInk, strokeWidth: 4);
}
