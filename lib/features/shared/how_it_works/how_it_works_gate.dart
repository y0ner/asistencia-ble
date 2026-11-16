import 'package:flutter/material.dart';

import '../../../data/services/first_run_store.dart';
import '../../../ui/ui.dart';
import 'how_it_works_content.dart';
import 'how_it_works_tour_screen.dart';

/// Controla si se debe mostrar el recorrido de "Cómo funciona" por primera vez
/// antes de dar paso al contenido principal de la aplicación.
class HowItWorksGate extends StatefulWidget {
  const HowItWorksGate({
    super.key,
    required this.content,
    required this.store,
    required this.child,
  });

  final HowItWorksContent content;
  final FirstRunStore store;
  final Widget child;

  @override
  State<HowItWorksGate> createState() => _HowItWorksGateState();
}

class _HowItWorksGateState extends State<HowItWorksGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final seen = await widget.store.hasSeenTour();
      if (mounted) {
        setState(() => _seen = seen);
      }
    } catch (error) {
      debugPrint('No se pudo saber si ya vio el recorrido: $error');
      if (mounted) {
        setState(() => _seen = true);
      }
    }
  }

  void _finish() {
    setState(() => _seen = true);
    _saveSeen();
  }

  Future<void> _saveSeen() async {
    try {
      await widget.store.markTourSeen();
    } catch (error) {
      debugPrint('No se pudo guardar que ya vio el recorrido: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen;
    if (seen == null) {
      return ColoredBox(
        color: UiColors.of(context).background,
        child: const SizedBox.expand(),
      );
    }

    if (!seen) {
      return HowItWorksTourScreen(
        content: widget.content,
        steps: widget.content.tour,
        firstRun: true,
        onFinished: _finish,
      );
    }

    return widget.child;
  }
}
