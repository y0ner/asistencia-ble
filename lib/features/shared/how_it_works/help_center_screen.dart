import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'how_it_works_content.dart';

/// Centro de ayuda: acceso al recorrido, temas, "Bueno saber" y "Si algo
/// falla".
///
/// Pendiente de construir (brief `H1-D`). El constructor ya es definitivo.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, required this.content, this.onOpenPermissions});

  final HowItWorksContent content;

  /// Qué hacer al tocar «Permisos del celular». Por defecto abre
  /// `showHardwareDiagnosticDialog`. Las pruebas pasan uno propio.
  final void Function(BuildContext context)? onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    return UiPage(
      header: UiTopBar(title: HowItWorksContent.helpTitle, onBack: () => Navigator.of(context).pop()),
      body: const SizedBox.shrink(),
    );
  }
}
