import 'ui_scene_canvas.dart';

/// Un estudiante escribe su código estudiantil en su celular.
///
/// Referencia: `docs/diseno/referencias/como-funciona/codigo.svg`.
/// Por ahora es un dibujo quieto: falta animarlo con `t`.
void paintSceneCodigo(UiSceneCanvas g, double t) {
  final p = g.palette;
  g.rrect(104, 18, 112, 184, 22, fill: p.surface, stroke: p.ink);
  g.rrect(120, 42, 52, 7, 3.5, fill: p.muted, opacity: 0.6);
  g.rrect(120, 58, 80, 30, 9, fill: p.panel, stroke: p.teacher, strokeWidth: 2.5);
  g.circle(131, 73, 3, fill: p.ink);
  g.circle(141, 73, 3, fill: p.ink);
  g.circle(151, 73, 3, fill: p.ink);
  g.circle(161, 73, 3, fill: p.ink);
  g.circle(171, 73, 3, fill: p.ink);
  g.rrect(180, 65, 2.5, 16, 1, fill: p.teacher);
  g.rrect(120, 102, 22, 18, 6, fill: p.panel);
  g.rrect(149, 102, 22, 18, 6, fill: p.panel);
  g.rrect(178, 102, 22, 18, 6, fill: p.panel);
  g.rrect(120, 126, 22, 18, 6, fill: p.panel);
  g.rrect(149, 126, 22, 18, 6, fill: p.accent);
  g.rrect(178, 126, 22, 18, 6, fill: p.panel);
  g.rrect(120, 150, 22, 18, 6, fill: p.panel);
  g.rrect(149, 150, 22, 18, 6, fill: p.panel);
  g.rrect(178, 150, 22, 18, 6, fill: p.panel);
  g.rrect(149, 174, 22, 18, 6, fill: p.panel);
  g.rrect(30, 76, 56, 40, 10, fill: p.surface, stroke: p.line, strokeWidth: 2);
  g.circle(46, 90, 6, fill: p.teacher);
  g.rrect(58, 86, 20, 6, 3, fill: p.muted, opacity: 0.6);
  g.rrect(38, 102, 40, 6, 3, fill: p.ink);
  g.path('M88 96 h12', stroke: p.accent, dash: [2, 7]);
}
