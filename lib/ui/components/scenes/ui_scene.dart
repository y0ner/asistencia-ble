import 'package:flutter/material.dart';

import '../../tokens/ui_metrics.dart';
import 'scene_acercar.dart';
import 'scene_amano.dart';
import 'scene_aprobar.dart';
import 'scene_cambio.dart';
import 'scene_codigo.dart';
import 'scene_escanear.dart';
import 'scene_excel.dart';
import 'scene_listo.dart';
import 'scene_pin.dart';
import 'scene_presente.dart';
import 'scene_qr.dart';
import 'scene_retirar.dart';
import 'scene_teclado.dart';
import 'ui_scene_canvas.dart';

export 'ui_scene_canvas.dart' show UiSceneAnim, UiSceneCanvas, UiScenePalette;

/// Dibujos de "Cómo funciona". Cada uno tiene su referencia en
/// `docs/diseno/referencias/como-funciona/<nombre>.svg`.
enum UiSceneKind {
  /// El profesor muestra el QR de la clase.
  qr,

  /// El estudiante escanea el QR.
  escanear,

  /// El estudiante escribe su código estudiantil.
  codigo,

  /// El profesor aprueba a quien no está en la lista.
  aprobar,

  /// El profesor dicta el PIN.
  pin,

  /// El estudiante escribe el PIN.
  teclado,

  /// El estudiante acerca su celular al del profesor.
  acercar,

  /// El celular del estudiante muestra "¡Presente!".
  listo,

  /// La lista del profesor se marca sola.
  presente,

  /// El profesor marca a alguien a mano.
  amano,

  /// El profesor cierra, firma y envía el Excel.
  excel,

  /// Un estudiante cambia de celular.
  cambio,

  /// El profesor retira o elimina a un estudiante.
  retirar,
}

/// Función que pinta un dibujo en un lienzo de 320 × 220. `t` va de 0 a 1.
typedef UiScenePaint = void Function(UiSceneCanvas g, double t);

/// Función que pinta el dibujo [kind].
UiScenePaint uiScenePaintOf(UiSceneKind kind) {
  return switch (kind) {
    UiSceneKind.qr => paintSceneQr,
    UiSceneKind.escanear => paintSceneEscanear,
    UiSceneKind.codigo => paintSceneCodigo,
    UiSceneKind.aprobar => paintSceneAprobar,
    UiSceneKind.pin => paintScenePin,
    UiSceneKind.teclado => paintSceneTeclado,
    UiSceneKind.acercar => paintSceneAcercar,
    UiSceneKind.listo => paintSceneListo,
    UiSceneKind.presente => paintScenePresente,
    UiSceneKind.amano => paintSceneAmano,
    UiSceneKind.excel => paintSceneExcel,
    UiSceneKind.cambio => paintSceneCambio,
    UiSceneKind.retirar => paintSceneRetirar,
  };
}

String _labelOf(UiSceneKind kind) {
  return switch (kind) {
    UiSceneKind.qr => 'El celular del profesor muestra un código QR y los estudiantes lo escanean',
    UiSceneKind.escanear => 'Un estudiante escanea con su celular el código QR que muestra el profesor',
    UiSceneKind.codigo => 'Un estudiante escribe su código estudiantil en su celular',
    UiSceneKind.aprobar => 'El profesor ve una solicitud por aprobar y decide aceptarla o rechazarla',
    UiSceneKind.pin => 'El celular del profesor muestra un PIN de dos números y el profesor lo dice en voz alta',
    UiSceneKind.teclado => 'El profesor dicta el PIN y el estudiante lo escribe en su celular',
    UiSceneKind.acercar => 'Dos celulares cerca uno del otro, con ondas de señal entre ellos',
    UiSceneKind.listo => 'El celular del estudiante muestra que quedó presente',
    UiSceneKind.presente => 'La lista del profesor se va marcando sola a medida que llegan los estudiantes',
    UiSceneKind.amano => 'El profesor marca a un estudiante a mano tocando su nombre en la lista',
    UiSceneKind.excel => 'Una hoja de asistencia firmada lista para enviar',
    UiSceneKind.cambio => 'Un estudiante cambia su celular anterior por uno nuevo',
    UiSceneKind.retirar => 'El profesor retira a un estudiante de la lista de la clase',
  };
}

/// Dibujo animado de un paso de "Cómo funciona".
///
/// Ocupa todo el ancho disponible con proporción 320 : 220. Con "reducir
/// movimiento" activado (o `animate: false`) se queda quieto en [restT].
class UiScene extends StatefulWidget {
  const UiScene({super.key, required this.kind, this.studentView = false, this.animate = true});

  final UiSceneKind kind;

  /// `true` en la app del estudiante.
  final bool studentView;
  final bool animate;

  /// Momento del ciclo en que se dibuja cuando no hay animación. En ese
  /// momento el dibujo debe verse completo, igual a su referencia.
  static const double restT = 0.9;

  /// Duración de un ciclo.
  static const Duration cycle = Duration(milliseconds: 3600);

  @override
  State<UiScene> createState() => _UiSceneState();
}

class _UiSceneState extends State<UiScene> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: UiScene.cycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UiScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = UiScenePalette.of(context);
    return Semantics(
      image: true,
      label: _labelOf(widget.kind),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: UiSceneCanvas.size.width / UiSceneCanvas.size.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.lg),
            child: ColoredBox(
              color: palette.panel,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _ScenePainter(
                      kind: widget.kind,
                      t: _controller.isAnimating ? _controller.value : UiScene.restT,
                      palette: palette,
                      studentView: widget.studentView,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter({required this.kind, required this.t, required this.palette, required this.studentView});

  final UiSceneKind kind;
  final double t;
  final UiScenePalette palette;
  final bool studentView;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / UiSceneCanvas.size.width, size.height / UiSceneCanvas.size.height);
    uiScenePaintOf(kind)(UiSceneCanvas(canvas, palette, studentView: studentView), t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.kind != kind || old.t != t || old.palette != palette || old.studentView != studentView;
}
