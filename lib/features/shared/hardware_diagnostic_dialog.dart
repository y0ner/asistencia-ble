import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/android_sdk.dart';
import '../../ui/ui.dart';

/// Indica si el dispositivo Android ejecuta API 31 (Android 12) o superior.
///
/// Desde Android 12 los permisos BLE no exigen ubicación.
Future<bool> isAndroid12OrHigher() async {
  final sdk = await androidSdkInt();
  return sdk != null && sdk >= 31;
}

/// Despliega el modal de diagnóstico de hardware en Android o Linux Desktop.
Future<void> showHardwareDiagnosticDialog(
  BuildContext context, {
  bool needsCamera = true,
}) async {
  if (Platform.isAndroid) {
    await showDialog<void>(
      context: context,
      builder: (_) => HardwareDiagnosticDialog(needsCamera: needsCamera),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => const DesktopHardwareDiagnosticDialog(),
    );
  }
}

class _DiagnosticRow {
  const _DiagnosticRow({required this.title, this.permission});

  final String title;
  final Permission? permission;
}

/// Modal de diagnóstico de hardware en Android usando `permission_handler`.
class HardwareDiagnosticDialog extends StatefulWidget {
  const HardwareDiagnosticDialog({
    super.key,
    this.isAndroid12OrHigherOverride,
    this.permissionChecker,
    this.sdkInt,
    this.needsCamera = true,
    this.locationServiceChecker,
  });

  /// Permite fijar el valor de versión de Android para pruebas unitarias y de widgets.
  final bool? isAndroid12OrHigherOverride;

  /// Permite inyectar directamente la versión del SDK de Android.
  final int? sdkInt;

  /// Indica si la app requiere cámara (falso para Docente, verdadero para Estudiante).
  final bool needsCamera;

  /// Función opcional para consultar el estado de los permisos (por defecto la plataforma vía permission_handler).
  final Future<PermissionStatus> Function(Permission permission)?
      permissionChecker;

  /// Función opcional para consultar el estado del servicio de ubicación del sistema.
  final Future<ServiceStatus> Function()? locationServiceChecker;

  @override
  State<HardwareDiagnosticDialog> createState() =>
      _HardwareDiagnosticDialogState();
}

class _HardwareDiagnosticDialogState extends State<HardwareDiagnosticDialog> {
  bool _isLoading = true;
  Map<String, PermissionStatus> _statuses = <String, PermissionStatus>{};
  List<_DiagnosticRow> _rows = <_DiagnosticRow>[];

  @override
  void initState() {
    super.initState();
    _initAndCheckPermissions();
  }

  Future<PermissionStatus> _checkPermission(Permission permission) async {
    if (widget.permissionChecker != null) {
      return widget.permissionChecker!(permission);
    }
    return permission.status;
  }

  Future<PermissionStatus> _checkLocationService() async {
    try {
      final status = widget.locationServiceChecker != null
          ? await widget.locationServiceChecker!()
          : await Permission.location.serviceStatus;
      return status == ServiceStatus.enabled
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } catch (e) {
      debugPrint('Error al verificar servicio de ubicación: $e');
      return PermissionStatus.denied;
    }
  }

  /// Filas del diagnóstico según la versión de Android: los permisos de
  /// Bluetooth cercano solo existen desde Android 12 (SDK 31); antes, el
  /// escaneo depende del permiso y del servicio de ubicación.
  List<_DiagnosticRow> _rowsFor(int sdk) {
    return <_DiagnosticRow>[
      if (sdk >= 31) ...const <_DiagnosticRow>[
        _DiagnosticRow(
          title: 'Buscar celulares cercanos',
          permission: Permission.bluetoothScan,
        ),
        _DiagnosticRow(
          title: 'Avisar a celulares cercanos',
          permission: Permission.bluetoothAdvertise,
        ),
        _DiagnosticRow(
          title: 'Conectar con celulares cercanos',
          permission: Permission.bluetoothConnect,
        ),
      ] else ...const <_DiagnosticRow>[
        _DiagnosticRow(
          title: 'Ubicación',
          permission: Permission.locationWhenInUse,
        ),
        _DiagnosticRow(title: 'Ubicación del celular encendida'),
      ],
      if (widget.needsCamera)
        const _DiagnosticRow(
          title: 'Cámara (para leer el código de la clase)',
          permission: Permission.camera,
        ),
    ];
  }

  Future<void> _initAndCheckPermissions() async {
    setState(() => _isLoading = true);

    final override = widget.isAndroid12OrHigherOverride;
    final sdk = widget.sdkInt ??
        (override == null ? null : (override ? 31 : 30)) ??
        await androidSdkInt() ??
        31;
    final rows = _rowsFor(sdk);

    _rows = rows;
    await _evaluateAllStatuses();
  }

  Future<void> _evaluateAllStatuses() async {
    final results = <String, PermissionStatus>{};
    for (final row in _rows) {
      if (row.permission != null) {
        try {
          results[row.title] = await _checkPermission(row.permission!);
        } catch (e) {
          debugPrint('Error al verificar permiso ${row.permission}: $e');
          results[row.title] = PermissionStatus.denied;
        }
      } else {
        results[row.title] = await _checkLocationService();
      }
    }

    if (mounted) {
      setState(() {
        _statuses = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    final toRequest = _rows
        .where((r) => r.permission != null && _statuses[r.title] != PermissionStatus.granted)
        .map((r) => r.permission!)
        .toList();

    if (toRequest.isNotEmpty) {
      try {
        await toRequest.request();
      } catch (e) {
        debugPrint('Error al solicitar permisos: $e');
      }
    }

    await _evaluateAllStatuses();
  }

  Widget _buildStatusChip(PermissionStatus? status) {
    if (status == null) return const SizedBox.shrink();
    if (status.isGranted) {
      return const UiPill(label: 'Permitido', icon: Icons.check_rounded);
    }
    if (status.isPermanentlyDenied) {
      return const UiPill(label: 'Bloqueado', icon: Icons.block_rounded, tone: UiTone.absent);
    }
    return const UiPill(label: 'Falta', icon: Icons.warning_amber_rounded, tone: UiTone.manual);
  }

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    final allGranted = !_isLoading &&
        _rows.every((r) => _statuses[r.title]?.isGranted ?? false);
    final anyBlocked = _statuses.values.any((s) => s.isPermanentlyDenied);

    return AlertDialog(
      title: const Text('Permisos del celular'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'La app usa el Bluetooth para tomar asistencia de cerca y la cámara para unirte a una clase.',
              style: UiText.label.copyWith(color: c.muted),
            ),
            const SizedBox(height: UiSpace.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(UiSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              UiListGroup(
                children: <Widget>[
                  for (final row in _rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UiSpace.md, vertical: UiSpace.md),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(row.title, style: UiText.bodyStrong.copyWith(color: c.ink)),
                          ),
                          const SizedBox(width: UiSpace.sm),
                          _buildStatusChip(_statuses[row.title]),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: UiSpace.md),
            if (allGranted)
              const UiBanner(tone: UiBannerTone.info, message: 'Todo listo: la app tiene los permisos que necesita.')
            else ...<Widget>[
              UiButton(
                label: anyBlocked ? 'Abrir ajustes' : 'Dar permisos',
                compact: true,
                onPressed: _isLoading
                    ? null
                    : anyBlocked
                        ? () => openAppSettings()
                        : _requestPermissions,
              ),
              const SizedBox(height: UiSpace.sm),
              UiButton(
                label: 'Volver a revisar',
                variant: UiButtonVariant.outline,
                compact: true,
                onPressed: _isLoading ? null : _initAndCheckPermissions,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Modal de diagnóstico en entornos no Android (Linux Desktop / Pruebas FFI).
class DesktopHardwareDiagnosticDialog extends StatelessWidget {
  const DesktopHardwareDiagnosticDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    return AlertDialog(
      title: const Text('Permisos del celular'),
      content: Text(
        'Estás usando la app en un computador. El Bluetooth y la cámara solo funcionan en un celular Android: ahí este panel revisa y pide los permisos.',
        style: UiText.body.copyWith(color: c.muted),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
