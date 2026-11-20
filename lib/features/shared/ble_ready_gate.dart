import 'package:flutter/material.dart';

import '../../data/services/ble_permission_service.dart';
import '../../ui/ui.dart';

/// Verifica permisos y Bluetooth antes de mostrar una pantalla que lo usa.
///
/// Mientras falta algo, muestra qué falta y un botón para resolverlo; cuando
/// todo está listo construye [builder]. Llama a [onReady] una sola vez.
class BleReadyGate extends StatefulWidget {
  const BleReadyGate({
    super.key,
    required this.permissionService,
    required this.title,
    required this.purpose,
    required this.onBack,
    required this.builder,
    this.subtitle,
    this.onReady,
  });

  final BlePermissionService permissionService;

  /// Título de la barra mientras se muestra el aviso.
  final String title;
  final String? subtitle;

  /// Para qué se necesita, en infinitivo: "inscribir a tus estudiantes".
  final String purpose;
  final VoidCallback onBack;
  final WidgetBuilder builder;
  final VoidCallback? onReady;

  @override
  State<BleReadyGate> createState() => _BleReadyGateState();
}

class _BleReadyGateState extends State<BleReadyGate> {
  BlePermissionResult? _result;
  bool _checking = true;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    BlePermissionResult? result;
    try {
      result = await widget.permissionService.ensureReady();
    } catch (error) {
      debugPrint('No se pudo verificar el Bluetooth: $error');
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });
    if ((result?.isReady ?? false) && !_notified) {
      _notified = true;
      widget.onReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null && result.isReady) {
      return widget.builder(context);
    }
    final c = UiColors.of(context);
    final Widget body;
    if (_checking) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final advice = blePermissionAdvice(result, widget.purpose);
      final bluetoothOff = advice.isBluetoothOff;
      final locationOff = advice.isLocationOff;
      final needsSettings = advice.requiresSettings;
      final title = advice.title;
      final message = advice.message;

      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UiSpace.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(UiRadius.xxl)),
                child: Icon(
                  bluetoothOff
                      ? Icons.bluetooth_disabled_rounded
                      : locationOff
                          ? Icons.location_off_rounded
                          : Icons.lock_outline_rounded,
                  size: 40,
                  color: c.tintText,
                ),
              ),
              const SizedBox(height: UiSpace.xl),
              Text(title, textAlign: TextAlign.center, style: UiText.h2.copyWith(color: c.ink)),
              const SizedBox(height: UiSpace.sm),
              Text(message, textAlign: TextAlign.center, style: UiText.body.copyWith(color: c.muted)),
              const SizedBox(height: UiSpace.xl),
              if (bluetoothOff)
                UiButton(
                  label: 'Encender Bluetooth',
                  onPressed: () async {
                    try {
                      await widget.permissionService.turnOnBluetooth();
                    } catch (error) {
                      debugPrint('No se pudo encender el Bluetooth: $error');
                    }
                    await _check();
                  },
                )
              else if (locationOff)
                UiButton(
                  label: 'Revisar de nuevo',
                  onPressed: _check,
                )
              else if (needsSettings)
                UiButton(label: 'Abrir ajustes', onPressed: () => widget.permissionService.openAppSettings()),
              if (!locationOff) ...[
                const SizedBox(height: UiSpace.sm),
                UiButton(label: 'Volver a intentar', variant: UiButtonVariant.outline, onPressed: _check),
              ],
            ],
          ),
        ),
      );
    }
    return UiPage(
      header: UiTopBar(title: widget.title, subtitle: widget.subtitle, onBack: widget.onBack),
      body: body,
    );
  }
}
