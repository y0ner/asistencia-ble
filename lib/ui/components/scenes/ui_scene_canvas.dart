import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../tokens/ui_colors.dart';
import '../../tokens/ui_text.dart';

/// Colores de los dibujos de "Cómo funciona".
///
/// Regla que no se rompe: el celular **relleno** ([teacher]) es siempre el del
/// profesor y el celular **con borde** ([surface] + [ink]) es el del
/// estudiante. [accent] (ocre) marca lo que se mueve.
@immutable
class UiScenePalette {
  const UiScenePalette({
    required this.panel,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.teacher,
    required this.onTeacher,
    required this.accent,
    required this.danger,
  });

  factory UiScenePalette.of(BuildContext context) {
    return UiScenePalette.fromColors(
      UiColors.of(context),
      dark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Para pintar fuera de un árbol de widgets (pruebas).
  factory UiScenePalette.fromColors(UiColors c, {required bool dark}) {
    return UiScenePalette(
      panel: c.tint,
      surface: dark ? c.background : c.surface,
      ink: c.ink,
      muted: c.muted,
      line: c.line,
      teacher: c.primary,
      onTeacher: c.onPrimary,
      accent: c.manualDot,
      danger: c.absentDot,
    );
  }

  /// Fondo del dibujo.
  final Color panel;

  /// Relleno del celular del estudiante y de las tarjetas.
  final Color surface;

  /// Bordes y barras de texto principales.
  final Color ink;

  /// Barras de texto secundarias.
  final Color muted;
  final Color line;

  /// Celular del profesor.
  final Color teacher;

  /// Lo que va encima del celular del profesor.
  final Color onTeacher;

  /// Ocre: lo que se mueve o hay que mirar.
  final Color accent;

  /// Coral: rechazar, quitar, desvincular.
  final Color danger;

  /// Papel blanco fijo (QR, casillas del PIN, filas sobre el celular del
  /// profesor). No cambia con el tema.
  static const Color paper = Color(0xFFFFFFFF);

  /// Tinta fija sobre [paper] o sobre [accent].
  static const Color paperInk = Color(0xFF10262B);

  /// Turquesa suave fijo sobre [paper] (avatares en filas blancas).
  static const Color paperTint = Color(0xFFDDEEF0);

  /// Turquesa fijo sobre [paper] (vistos en filas blancas).
  static const Color paperTeal = Color(0xFF1F7A87);

  /// Gris fijo sobre [paper].
  static const Color paperMuted = Color(0xFF51666B);

  @override
  bool operator ==(Object other) =>
      other is UiScenePalette &&
      other.panel == panel &&
      other.surface == surface &&
      other.ink == ink &&
      other.muted == muted &&
      other.line == line &&
      other.teacher == teacher &&
      other.onTeacher == onTeacher &&
      other.accent == accent &&
      other.danger == danger;

  @override
  int get hashCode => Object.hash(panel, surface, ink, muted, line, teacher, onTeacher, accent, danger);
}

/// Curvas de tiempo para animar un dibujo. `t` va de 0 a 1 y se repite.
abstract final class UiSceneAnim {
  /// Vaivén suave: 0 → 1 → 0 una vez por ciclo. [phase] lo desplaza (0 a 1).
  static double wave(double t, {double phase = 0}) => 0.5 - 0.5 * math.cos(2 * math.pi * (t + phase));

  /// 0 antes de [start], 1 después de [end] y una subida suave en medio.
  /// Sirve para que algo "aparezca y se quede".
  static double appear(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    final x = (t - start) / (end - start);
    return x * x * (3 - 2 * x);
  }

  /// Golpe corto: 0 → 1 → 0 centrado en [at]. Sirve para un toque o un latido.
  static double bump(double t, double at, {double width = 0.16}) {
    final d = (t - at).abs();
    if (d >= width / 2) return 0;
    return 0.5 + 0.5 * math.cos(2 * math.pi * d / width);
  }

  /// Índice (0 a [count] - 1) del tramo del ciclo en que está [t].
  static int step(double t, int count) => (t * count).floor().clamp(0, count - 1);

  /// Interpolación lineal.
  static double mix(double a, double b, double x) => a + (b - a) * x;
}

/// Lienzo de 320 × 220 para pintar un dibujo con las mismas coordenadas de su
/// referencia SVG (`docs/diseno/referencias/como-funciona/`).
class UiSceneCanvas {
  UiSceneCanvas(this.canvas, this.palette, {this.studentView = false});

  final Canvas canvas;
  final UiScenePalette palette;

  /// `true` en la app del estudiante: cambia a quién se le dice "Tú".
  final bool studentView;

  /// Ancho y alto del lienzo lógico.
  static const Size size = Size(320, 220);

  /// Rectángulo redondeado (`<rect x y width height rx>`).
  void rrect(
    double x,
    double y,
    double w,
    double h,
    double r, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 3,
    double opacity = 1,
    List<double>? dash,
  }) {
    final shape = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
    _draw(shape, fill: fill, stroke: stroke, strokeWidth: strokeWidth, opacity: opacity, dash: dash);
  }

  /// Círculo (`<circle cx cy r>`).
  void circle(
    double cx,
    double cy,
    double r, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 3,
    double opacity = 1,
    List<double>? dash,
  }) {
    if (r <= 0) return;
    final shape = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    _draw(shape, fill: fill, stroke: stroke, strokeWidth: strokeWidth, opacity: opacity, dash: dash);
  }

  /// Trazo con la misma sintaxis del atributo `d` de un `<path>` SVG.
  ///
  /// [progress] (0 a 1) dibuja solo el comienzo del trazo: sirve para que un
  /// visto "se escriba". [dashOffset] desplaza el punteado para que "corra".
  void path(
    String d, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 3,
    double opacity = 1,
    List<double>? dash,
    double dashOffset = 0,
    double progress = 1,
  }) {
    var shape = parseSvgPath(d);
    if (progress < 1) shape = _trim(shape, progress.clamp(0, 1));
    _draw(
      shape,
      fill: fill,
      stroke: stroke,
      strokeWidth: strokeWidth,
      opacity: opacity,
      dash: dash,
      dashOffset: dashOffset,
    );
  }

  /// Texto centrado en [x] con la línea base en [baselineY]
  /// (`<text text-anchor="middle">`).
  void text(
    String value,
    double x,
    double baselineY, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w800,
    double opacity = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: UiText.family,
          fontSize: size,
          fontWeight: weight,
          color: _fade(color, opacity),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.paint(canvas, Offset(x - painter.width / 2, baselineY - baseline));
    painter.dispose();
  }

  /// Dibuja un grupo desplazado, escalado alrededor de [pivot] o atenuado.
  void group({
    double dx = 0,
    double dy = 0,
    double scale = 1,
    Offset pivot = Offset.zero,
    double opacity = 1,
    required VoidCallback draw,
  }) {
    if (opacity <= 0) return;
    if (opacity < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0, 1)),
      );
    } else {
      canvas.save();
    }
    canvas.translate(dx, dy);
    if (scale != 1) {
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(scale);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    draw();
    canvas.restore();
  }

  void _draw(
    Path shape, {
    Color? fill,
    Color? stroke,
    required double strokeWidth,
    required double opacity,
    List<double>? dash,
    double dashOffset = 0,
  }) {
    if (opacity <= 0) return;
    if (fill != null) {
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.fill
          ..color = _fade(fill, opacity),
      );
    }
    if (stroke != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _fade(stroke, opacity);
      canvas.drawPath(dash == null ? shape : _dashed(shape, dash, dashOffset), paint);
    }
  }

  static Color _fade(Color color, double opacity) =>
      opacity >= 1 ? color : color.withValues(alpha: color.a * opacity.clamp(0, 1));

  static Path _trim(Path source, double fraction) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return out;
  }

  static Path _dashed(Path source, List<double> pattern, double offset) {
    assert(pattern.isNotEmpty && pattern.every((v) => v > 0), 'El punteado necesita valores positivos.');
    final out = Path();
    final total = pattern.fold<double>(0, (a, b) => a + b) * (pattern.length.isOdd ? 2 : 1);
    for (final metric in source.computeMetrics()) {
      var distance = -(offset % total);
      var index = 0;
      var on = true;
      while (distance < metric.length) {
        final length = pattern[index % pattern.length];
        if (on) {
          final start = math.max(0.0, distance);
          final end = math.min(metric.length, distance + length);
          if (end > start) out.addPath(metric.extractPath(start, end), Offset.zero);
        }
        distance += length;
        index++;
        on = !on;
      }
    }
    return out;
  }
}

final RegExp _svgNumber = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');

/// Convierte el atributo `d` de un `<path>` SVG en un [Path].
///
/// Admite M, L, H, V, C, Q, A y Z, en mayúscula (absoluto) y minúscula
/// (relativo), y la repetición implícita de un comando.
Path parseSvgPath(String d) {
  final path = Path();
  var i = 0;
  var cmd = '';
  var current = Offset.zero;
  var start = Offset.zero;

  void skip() {
    while (i < d.length && (d[i] == ' ' || d[i] == ',' || d[i] == '\n' || d[i] == '\t')) {
      i++;
    }
  }

  double number() {
    skip();
    final match = _svgNumber.matchAsPrefix(d, i);
    if (match == null) {
      throw FormatException('Trazo SVG inválido cerca de la posición $i', d);
    }
    i = match.end;
    return double.parse(match.group(0)!);
  }

  bool moreNumbers() {
    skip();
    return i < d.length && _svgNumber.matchAsPrefix(d, i) != null;
  }

  skip();
  while (i < d.length) {
    final ch = d[i];
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      cmd = ch;
      i++;
    } else if (cmd.isEmpty) {
      throw FormatException('El trazo SVG debe empezar con un comando', d);
    }
    final relative = cmd == cmd.toLowerCase();
    Offset point(double x, double y) => relative ? current + Offset(x, y) : Offset(x, y);

    switch (cmd.toUpperCase()) {
      case 'M':
        current = point(number(), number());
        start = current;
        path.moveTo(current.dx, current.dy);
        // Los pares siguientes son líneas.
        cmd = relative ? 'l' : 'L';
      case 'L':
        current = point(number(), number());
        path.lineTo(current.dx, current.dy);
      case 'H':
        final x = number();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        final y = number();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
      case 'C':
        final c1 = point(number(), number());
        final c2 = point(number(), number());
        final end = point(number(), number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        current = end;
      case 'Q':
        final c1 = point(number(), number());
        final end = point(number(), number());
        path.quadraticBezierTo(c1.dx, c1.dy, end.dx, end.dy);
        current = end;
      case 'A':
        final rx = number();
        final ry = number();
        final rotation = number();
        final largeArc = number() != 0;
        final sweep = number() != 0;
        final end = point(number(), number());
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        current = end;
      case 'Z':
        path.close();
        current = start;
      default:
        throw FormatException('Comando SVG no admitido: $cmd', d);
    }
    skip();
    if (i < d.length && !moreNumbers() && !RegExp(r'[A-Za-z]').hasMatch(d[i])) {
      throw FormatException('Trazo SVG inválido cerca de la posición $i', d);
    }
  }
  return path;
}

/// Medida de un trazo, útil en pruebas.
double svgPathLength(String d) =>
    parseSvgPath(d).computeMetrics().fold<double>(0, (a, ui.PathMetric m) => a + m.length);
