import 'ui_scene_canvas.dart';

/// Un estudiante escanea con su celular el código QR que muestra el profesor.
///
/// Referencia: `docs/diseno/referencias/como-funciona/escanear.svg`.
/// Animación: la línea de escaneo sube y baja, la línea punteada corre y las
/// esquinas de enfoque laten.
void paintSceneEscanear(UiSceneCanvas g, double t) {
  final p = g.palette;
  final scanDy = UiSceneAnim.mix(-22, 22, UiSceneAnim.wave(t, phase: 0.35));
  final cornersOpacity = UiSceneAnim.mix(0.5, 1, UiSceneAnim.wave(t, phase: 0.6));

  g.rrect(34, 52, 70, 116, 14, fill: p.teacher);
  g.rrect(46, 76, 46, 46, 8, fill: UiScenePalette.paper);
  g.rrect(52, 82, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(74, 82, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(52, 104, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(74, 104, 6, 6, 2, fill: UiScenePalette.paperInk);
  g.rrect(52, 138, 34, 7, 3.5, fill: p.onTeacher, opacity: 0.55);
  g.path('M114 110 h48', stroke: p.accent, dash: [2, 8], dashOffset: -20 * t);
  g.rrect(176, 18, 112, 184, 22, fill: p.surface, stroke: p.ink);
  g.rrect(190, 40, 84, 96, 12, fill: p.panel);
  g.rrect(208, 64, 48, 48, 8, fill: UiScenePalette.paper);
  g.rrect(214, 70, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(238, 70, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(214, 94, 12, 12, 3, fill: UiScenePalette.paperInk);
  g.rrect(238, 94, 6, 6, 2, fill: UiScenePalette.paperInk);
  g.path(
    'M200 68 v-12 h12 M264 68 v-12 h-12 M200 108 v12 h12 M264 108 v12 h-12',
    stroke: p.accent,
    strokeWidth: 3.5,
    opacity: cornersOpacity,
  );
  g.group(
    dy: scanDy,
    draw: () {
      g.path('M204 88 h56', stroke: p.accent);
    },
  );
  g.rrect(198, 152, 68, 8, 4, fill: p.ink);
  g.rrect(210, 168, 44, 7, 3.5, fill: p.muted, opacity: 0.6);
}
