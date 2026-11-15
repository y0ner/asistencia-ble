import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/android_sdk.dart';

typedef PermissionStatusReader = Future<PermissionStatus> Function(Permission permission);
typedef PermissionsRequester = Future<Map<Permission, PermissionStatus>> Function(List<Permission> permissions);
typedef SdkVersionReader = FutureOr<int?> Function();

/// Un permiso que la app necesita y por qué, en palabras normales.
class AppPermissionItem {
  const AppPermissionItem({required this.permissions, required this.title, required this.reason});

  /// Permisos de Android que cubre (los de Bluetooth van juntos: Android los
  /// muestra como uno solo, "Dispositivos cercanos").
  final List<Permission> permissions;
  final String title;
  final String reason;
}

/// Estado de los permisos al abrir la app.
class AppPermissionsStatus {
  const AppPermissionsStatus({required this.items, required this.granted, required this.permanentlyDenied});

  final List<AppPermissionItem> items;

  /// Ítems ya concedidos.
  final Set<AppPermissionItem> granted;

  /// Ítems que Android ya no deja pedir: hay que ir a Ajustes.
  final Set<AppPermissionItem> permanentlyDenied;

  bool get allGranted => granted.length == items.length;

  bool get needsSettings => permanentlyDenied.isNotEmpty;
}

/// Permisos que cada app pide de una vez al abrirse.
///
/// - Docente: dispositivos cercanos (Bluetooth).
/// - Estudiante: dispositivos cercanos y cámara (para leer el código de la clase).
/// - Android 11 o anterior: ubicación en lugar de dispositivos cercanos.
class AppPermissionsService {
  AppPermissionsService({
    required this.needsCamera,
    PermissionStatusReader? statusReader,
    PermissionsRequester? requester,
    SdkVersionReader? sdkVersion,
  })  : _statusReader = statusReader ?? ((Permission p) => p.status),
        _requester = requester ?? ((List<Permission> list) => list.request()),
        _sdkVersion = sdkVersion ?? androidSdkInt;

  final bool needsCamera;
  final PermissionStatusReader _statusReader;
  final PermissionsRequester _requester;
  final SdkVersionReader _sdkVersion;

  Future<List<AppPermissionItem>> requiredItems() async {
    final sdk = await _sdkVersion() ?? 31;
    return <AppPermissionItem>[
      if (sdk >= 31)
        const AppPermissionItem(
          permissions: <Permission>[Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect],
          title: 'Dispositivos cercanos',
          reason: 'Para que los celulares del profesor y del estudiante se encuentren en el salón.',
        )
      else
        const AppPermissionItem(
          permissions: <Permission>[Permission.locationWhenInUse],
          title: 'Ubicación',
          reason: 'En tu versión de Android, el Bluetooth la necesita para encontrar celulares cercanos. La app no guarda tu ubicación.',
        ),
      if (needsCamera)
        const AppPermissionItem(
          permissions: <Permission>[Permission.camera],
          title: 'Cámara',
          reason: 'Para leer el código QR de la clase cuando te unes.',
        ),
    ];
  }

  /// Revisa sin pedir nada.
  Future<AppPermissionsStatus> check() async => _evaluate(await requiredItems(), const <Permission, PermissionStatus>{});

  /// Pide de una vez todo lo que falta y se pueda pedir.
  Future<AppPermissionsStatus> requestAll() async {
    final items = await requiredItems();
    final current = await _evaluate(items, const <Permission, PermissionStatus>{});
    final toRequest = <Permission>[
      for (final item in items)
        if (!current.granted.contains(item) && !current.permanentlyDenied.contains(item)) ...item.permissions,
    ];
    if (toRequest.isEmpty) return current;
    final results = await _requester(toRequest);
    return _evaluate(items, results);
  }

  Future<AppPermissionsStatus> _evaluate(List<AppPermissionItem> items, Map<Permission, PermissionStatus> known) async {
    final granted = <AppPermissionItem>{};
    final blocked = <AppPermissionItem>{};
    for (final item in items) {
      var allOk = true;
      var anyBlocked = false;
      for (final permission in item.permissions) {
        final status = known[permission] ?? await _statusReader(permission);
        if (!status.isGranted) allOk = false;
        if (status.isPermanentlyDenied || status.isRestricted) anyBlocked = true;
      }
      if (allOk) {
        granted.add(item);
      } else if (anyBlocked) {
        blocked.add(item);
      }
    }
    return AppPermissionsStatus(items: items, granted: granted, permanentlyDenied: blocked);
  }

  Future<bool> openSettings() => openAppSettings();
}
