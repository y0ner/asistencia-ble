import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'how_it_works_content.dart';

/// Recorrido paso a paso de "Cómo funciona": un dibujo, quién lo hace y qué
/// se hace en cada paso.
///
/// Pendiente de construir (brief `H1-C`). El constructor ya es definitivo.
class HowItWorksTourScreen extends StatefulWidget {
  const HowItWorksTourScreen({
    super.key,
    required this.content,
    required this.steps,
    this.title = HowItWorksContent.screenTitle,
    this.firstRun = false,
    this.onFinished,
  });

  final HowItWorksContent content;

  /// Pasos a mostrar: el recorrido completo o los de un tema.
  final List<HowStep> steps;
  final String title;

  /// `true` cuando se muestra sola la primera vez que se abre la app: ofrece
  /// «Saltar» y no tiene botón de volver.
  final bool firstRun;

  /// Se llama al tocar «Entendido» o «Saltar». Si es nulo, la pantalla se
  /// cierra con `Navigator.pop`.
  final VoidCallback? onFinished;

  @override
  State<HowItWorksTourScreen> createState() => _HowItWorksTourScreenState();
}

class _HowItWorksTourScreenState extends State<HowItWorksTourScreen> {
  @override
  Widget build(BuildContext context) {
    return UiPage(
      header: UiTopBar(title: widget.title, onBack: widget.firstRun ? null : () => Navigator.of(context).pop()),
      body: const SizedBox.shrink(),
    );
  }
}
