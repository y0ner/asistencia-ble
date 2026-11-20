import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/android_sdk.dart';

typedef PermissionStatusReader = Future<PermissionStatus> Function(Permission permission);
typedef PermissionsRequester = Future<Map<Permission, PermissionStatus>> Function(List<Permission> permissions);
typedef SdkVersionReader = FutureOr<int?> Function();
typedef LocationServiceStatusReader = Future<ServiceStatus> Function();

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
  const AppPermissionsStatus({
    required this.items,
    required this.granted,
    required this.permanentlyDenied,
    this.isLocationServiceEnabled = true,
    this.locationServiceMessage,
  });

  final List<AppPermissionItem> items;

  /// Ítems ya concedidos.
  final Set<AppPermissionItem> granted;

  /// Ítems que Android ya no deja pedir: hay que ir a Ajustes.
  final Set<AppPermissionItem> permanentlyDenied;

  /// Indica si la ubicación del sistema está encendida (en Android 11 o anterior).
  final bool isLocationServiceEnabled;

  /// Mensaje para el usuario si la ubicación del sistema está apagada.
  final String? locationServiceMessage;

  bool get allGranted =>
      granted.length == items.length && isLocationServiceEnabled;

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
    LocationServiceStatusReader? locationServiceStatusReader,
  })  : _statusReader = statusReader ?? ((Permission p) => p.status),
        _requester = requester ?? ((List<Permission> list) => list.request()),
        _sdkVersion = sdkVersion ?? androidSdkInt,
        _locationServiceStatusReader = locationServiceStatusReader ??
            (() => Permission.location.serviceStatus);

  final bool needsCamera;
  final PermissionStatusReader _statusReader;
  final PermissionsRequester _requester;
  final SdkVersionReader _sdkVersion;
  final LocationServiceStatusReader _locationServiceStatusReader;

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

    final sdk = await _sdkVersion() ?? 31;
    var isLocEnabled = true;
    String? locMessage;

    if (sdk <= 30) {
      try {
        final locStatus = await _locationServiceStatusReader();
        isLocEnabled = locStatus == ServiceStatus.enabled;
      } catch (error) {
        debugPrint('Error al verificar el servicio de ubicación: $error');
        isLocEnabled = false;
      }
      if (!isLocEnabled) {
        locMessage =
            'Activa la ubicación del celular. En Android 11 o anterior el Bluetooth '
            'la necesita para encontrar otros celulares; la app no guarda tu ubicación.';
      }
    }

    return AppPermissionsStatus(
      items: items,
      granted: granted,
      permanentlyDenied: blocked,
      isLocationServiceEnabled: isLocEnabled,
      locationServiceMessage: locMessage,
    );
  }

  Future<bool> openSettings() => openAppSettings();
}
