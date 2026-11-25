import 'ui_scene_canvas.dart';

/// La lista del profesor se va marcando sola a medida que llegan los estudiantes.
///
/// Referencia: `docs/diseno/referencias/como-funciona/presente.svg`.
/// Animación: el arco se llena, el visto central se escribe y las filas se van marcando.
void paintScenePresente(UiSceneCanvas g, double t) {
  final p = g.palette;
  final row1Check = UiSceneAnim.appear(t, 0.10, 0.20);
  final row2Check = UiSceneAnim.appear(t, 0.35, 0.45);

  // Anillo de progreso y visto central.
  g.circle(78, 110, 44, stroke: p.surface, strokeWidth: 12);
  g.path(
    'M78 66 a44 44 0 1 1 -41.8 30.4',
    stroke: p.teacher,
    strokeWidth: 12,
    progress: UiSceneAnim.appear(t, 0.1, 0.6),
  );
  g.path(
    'M62 111 l11 11 l21 -23',
    stroke: p.teacher,
    strokeWidth: 6,
    progress: UiSceneAnim.appear(t, 0.55, 0.75),
  );

  // Fila 1 (se marca primero).
  g.rrect(150, 30, 144, 46, 14, fill: p.surface);
  g.circle(174, 53, 12, fill: p.panel);
  g.rrect(194, 49, 52, 8, 4, fill: p.ink);
  g.circle(272, 53, 10, fill: p.teacher, opacity: row1Check);
  g.path('M267 53 l4 4 l6 -7', stroke: p.onTeacher, strokeWidth: 2.8, opacity: row1Check);

  // Fila 2 (se marca después).
  g.rrect(150, 87, 144, 46, 14, fill: p.surface);
  g.circle(174, 110, 12, fill: p.panel);
  g.rrect(194, 106, 64, 8, 4, fill: p.ink);
  g.circle(272, 110, 10, fill: p.teacher, opacity: row2Check);
  g.path('M267 110 l4 4 l6 -7', stroke: p.onTeacher, strokeWidth: 2.8, opacity: row2Check);

  // Fila 3 (sigue pendiente).
  g.rrect(150, 144, 144, 46, 14, fill: p.surface);
  g.circle(174, 167, 12, fill: p.panel);
  g.rrect(194, 163, 44, 8, 4, fill: p.muted, opacity: 0.6);
  g.circle(272, 167, 9, stroke: p.muted, strokeWidth: 2.5, dash: [3, 4]);
}
