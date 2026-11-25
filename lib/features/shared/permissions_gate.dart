import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/services/app_permissions_service.dart';
import '../../ui/ui.dart';

/// Pantalla que pide todos los permisos al abrir la app y no deja seguir
/// hasta que estén concedidos. Fuera de Android muestra [child] directamente.
class PermissionsGate extends StatefulWidget {
  const PermissionsGate({super.key, required this.service, required this.child, this.enabled});

  final AppPermissionsService service;
  final Widget child;

  /// Por defecto, solo en Android.
  final bool? enabled;

  @override
  State<PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<PermissionsGate> with WidgetsBindingObserver {
  AppPermissionsStatus? _status;
  bool _busy = false;
  bool _askedOnce = false;
  bool _hasError = false;

  bool get _enabled => widget.enabled ?? Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      WidgetsBinding.instance.addObserver(this);
      _check();
    }
  }

  @override
  void dispose() {
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes, revisar de nuevo.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    setState(() => _hasError = false);
    try {
      final status = await widget.service.check();
      if (mounted) {
        setState(() {
          _status = status;
          _hasError = false;
        });
      }
    } catch (error) {
      debugPrint('No se pudieron revisar los permisos: $error');
      if (mounted) {
        setState(() {
          _status = null;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _requestAll() async {
    setState(() => _busy = true);
    try {
      final status = await widget.service.requestAll();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      debugPrint('No se pudieron pedir los permisos: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _askedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final status = _status;
    if (status != null && status.allGranted) return widget.child;

    final c = UiColors.of(context);
    if (_hasError) {
      return UiPage(
        header: const UiBrandHeader(),
        bottom: UiButton(label: 'Reintentar', onPressed: _check),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: Text(
              'No pudimos revisar los permisos.',
              textAlign: TextAlign.center,
              style: UiText.bodyStrong.copyWith(color: c.ink),
            ),
          ),
        ),
      );
    }

    final needsSettings = status?.needsSettings ?? false;
    final onlyLocationServiceOff = status != null &&
        !status.isLocationServiceEnabled &&
        status.granted.length == status.items.length;

    return UiPage(
      header: const UiBrandHeader(),
      bottom: status == null
          ? null
          : needsSettings
              ? UiButton(label: 'Abrir ajustes', icon: Icons.settings_outlined, onPressed: widget.service.openSettings)
              : onlyLocationServiceOff
                  ? UiButton(label: 'Revisar de nuevo', onPressed: _busy ? null : _check)
                  : UiButton(label: 'Dar permisos', onPressed: _busy ? null : _requestAll, loading: _busy),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: UiSpace.xl),
              children: [
                const UiPageHeading(overline: 'Antes de empezar', title: 'La app necesita estos permisos'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UiListGroup(
                        children: [
                          for (final item in status.items)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(UiRadius.sm)),
                                    child: Icon(_iconFor(item), color: c.tintText, size: 22),
                                  ),
                                  const SizedBox(width: UiSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: UiSpace.sm,
                                          runSpacing: UiSpace.xs,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(item.title, style: UiText.bodyStrong.copyWith(color: c.ink)),
                                            _statusPill(status, item),
                                          ],
                                        ),
                                        const SizedBox(height: UiSpace.xs),
                                        Text(item.reason, style: UiText.label.copyWith(color: c.muted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: UiSpace.lg),
                      if (needsSettings)
                        UiBanner(
                          tone: UiBannerTone.warning,
                          title: 'Android ya no deja pedirlos desde aquí',
                          message: 'Abre los ajustes de la app, entra a «Permisos» y activa los que faltan. Al volver, la app sigue sola.',
                        )
                      else if (!status.isLocationServiceEnabled)
                        UiBanner(
                          tone: UiBannerTone.warning,
                          title: 'Ubicación desactivada',
                          message: status.locationServiceMessage ??
                              'Activa la ubicación del celular. En Android 11 o anterior el Bluetooth la necesita para encontrar otros celulares; la app no guarda tu ubicación.',
                        )
                      else if (_askedOnce)
                        const UiBanner(
                          tone: UiBannerTone.info,
                          message: 'Sin estos permisos la app no puede tomar asistencia. Toca «Dar permisos» y acéptalos.',
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statusPill(AppPermissionsStatus status, AppPermissionItem item) {
    if (status.granted.contains(item)) return const UiPill(label: 'Listo', icon: Icons.check_rounded);
    if (status.permanentlyDenied.contains(item)) {
      return const UiPill(label: 'Bloqueado', icon: Icons.block_rounded, tone: UiTone.absent);
    }
    return const UiPill(label: 'Falta', icon: Icons.warning_amber_rounded, tone: UiTone.manual);
  }

  IconData _iconFor(AppPermissionItem item) {
    if (item.title == 'Cámara') return Icons.photo_camera_outlined;
    if (item.title == 'Ubicación') return Icons.location_on_outlined;
    return Icons.bluetooth_rounded;
  }
}
