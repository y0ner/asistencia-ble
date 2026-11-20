import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph
    show openAppSettings;

import '../../core/platform/android_sdk.dart';

/// Tipos funcionales para inyección de dependencias en [BlePermissionService].
typedef AndroidSdkVersionProvider = FutureOr<int> Function();
typedef PermissionStatusChecker =
    Future<PermissionStatus> Function(Permission permission);
typedef PermissionRequester =
    Future<Map<Permission, PermissionStatus>> Function(
      List<Permission> permissions,
    );
typedef BluetoothAdapterStateProvider =
    Stream<BluetoothAdapterState> Function();
typedef BluetoothTurnOnAction = Future<void> Function();
typedef OpenAppSettingsAction = Future<bool> Function();
typedef LocationServiceStatusChecker = Future<ServiceStatus> Function();

/// Diagnóstico de permisos y disponibilidad del adaptador BLE.
class BlePermissionResult {
  const BlePermissionResult({
    required this.isReady,
    required this.missingPermissions,
    required this.permanentlyDeniedPermissions,
    required this.isBluetoothTurnedOn,
    this.isLocationServiceEnabled = true,
    this.sdkVersion,
    this.failureMessage,
  });

  /// `true` si todos los permisos requeridos están otorgados y el Bluetooth está encendido.
  final bool isReady;

  /// Permisos que no están concedidos.
  final List<Permission> missingPermissions;

  /// Permisos denegados permanentemente (requieren abrir ajustes).
  final List<Permission> permanentlyDeniedPermissions;

  /// Indica si el adaptador Bluetooth está encendido.
  final bool isBluetoothTurnedOn;

  /// Indica si el servicio de ubicación del celular está encendido (en Android 11 o anterior).
  final bool isLocationServiceEnabled;

  /// Versión del SDK de Android evaluada.
  final int? sdkVersion;

  /// Mensaje explicativo en español de qué falta para que el hardware esté listo.
  final String? failureMessage;

  /// Indica si al menos un permiso requiere abrir la configuración del sistema.
  bool get requiresAppSettings => permanentlyDeniedPermissions.isNotEmpty;

  /// Indica si no faltan permisos pero el adaptador Bluetooth está apagado (bloqueando la operación).
  bool get isBluetoothOffBlocking =>
      missingPermissions.isEmpty && !isBluetoothTurnedOn;

  /// Indica si no faltan permisos pero la ubicación del sistema está apagada en Android 11 o anterior (bloqueando la operación).
  bool get isLocationServiceOffBlocking =>
      missingPermissions.isEmpty && isAndroid11OrLower && !isLocationServiceEnabled;

  /// Indica si el único problema pendiente es encender el adaptador Bluetooth.
  bool get onlyBluetoothOff =>
      missingPermissions.isEmpty && !isBluetoothTurnedOn && isLocationServiceEnabled;

  /// Indica si el único problema pendiente es encender la ubicación del sistema.
  bool get onlyLocationServiceOff =>
      missingPermissions.isEmpty && isBluetoothTurnedOn && !isLocationServiceEnabled;

  /// Indica si se evaluó en Android 11 o anterior.
  bool get isAndroid11OrLower => (sdkVersion ?? 31) <= 30;
}

/// Servicio encargado de solicitar y validar permisos de Bluetooth y estado del adaptador.
///
/// Soporta:
/// - Android 12 o superior (API >= 31): `bluetoothScan`, `bluetoothAdvertise`, `bluetoothConnect`.
/// - Android 11 o inferior (API <= 30): `locationWhenInUse`.
/// - Verificación del adaptador Bluetooth encendido mediante [FlutterBluePlus].
class BlePermissionService {
  BlePermissionService({
    AndroidSdkVersionProvider? androidSdkVersionProvider,
    PermissionStatusChecker? permissionStatusChecker,
    PermissionRequester? permissionRequester,
    BluetoothAdapterStateProvider? bluetoothAdapterStateProvider,
    BluetoothTurnOnAction? bluetoothTurnOnAction,
    OpenAppSettingsAction? openAppSettingsAction,
    LocationServiceStatusChecker? locationServiceStatusChecker,
  }) : _androidSdkVersionProvider =
           androidSdkVersionProvider ?? _defaultAndroidSdkVersion,
       _permissionStatusChecker =
           permissionStatusChecker ?? _defaultCheckStatus,
       _permissionRequester = permissionRequester ?? _defaultRequestPermissions,
       _bluetoothAdapterStateProvider =
           bluetoothAdapterStateProvider ?? _defaultAdapterStateStream,
       _bluetoothTurnOnAction =
           bluetoothTurnOnAction ?? _defaultTurnOnBluetooth,
       _openAppSettingsAction =
           openAppSettingsAction ?? _defaultOpenAppSettings,
       _locationServiceStatusChecker =
           locationServiceStatusChecker ?? _defaultLocationServiceStatus;

  final AndroidSdkVersionProvider _androidSdkVersionProvider;
  final PermissionStatusChecker _permissionStatusChecker;
  final PermissionRequester _permissionRequester;
  final BluetoothAdapterStateProvider _bluetoothAdapterStateProvider;
  final BluetoothTurnOnAction _bluetoothTurnOnAction;
  final OpenAppSettingsAction _openAppSettingsAction;
  final LocationServiceStatusChecker _locationServiceStatusChecker;

  /// Evalúa los permisos requeridos según la versión de Android y el estado del Bluetooth.
  ///
  /// Si [requestIfNotGranted] es `true`, solicita los permisos faltantes antes de reportar el resultado.
  Future<BlePermissionResult> ensureReady({
    bool requestIfNotGranted = true,
  }) async {
    final sdkVersion = await _androidSdkVersionProvider();
    final requiredPermissions = sdkVersion >= 31
        ? const <Permission>[
            Permission.bluetoothScan,
            Permission.bluetoothAdvertise,
            Permission.bluetoothConnect,
          ]
        : const <Permission>[
            Permission.locationWhenInUse,
          ];

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in requiredPermissions) {
      statuses[permission] = await _permissionStatusChecker(permission);
    }

    var missing = requiredPermissions
        .where((Permission p) => statuses[p] != PermissionStatus.granted)
        .toList(growable: false);

    if (missing.isNotEmpty && requestIfNotGranted) {
      final toRequest = missing
          .where(
            (Permission p) =>
                statuses[p] != PermissionStatus.permanentlyDenied,
          )
          .toList(growable: false);

      if (toRequest.isNotEmpty) {
        final requestResults = await _permissionRequester(toRequest);
        statuses.addAll(requestResults);
      }

      missing = requiredPermissions
          .where((Permission p) => statuses[p] != PermissionStatus.granted)
          .toList(growable: false);
    }

    final permanentlyDenied = missing
        .where(
          (Permission p) => statuses[p] == PermissionStatus.permanentlyDenied,
        )
        .toList(growable: false);

    var isBtOn = false;
    try {
      final state = await _bluetoothAdapterStateProvider()
          .first
          .timeout(const Duration(seconds: 2));
      isBtOn = state == BluetoothAdapterState.on;
    } catch (error) {
      debugPrint(
        'No se pudo leer el estado del adaptador en 2 s: $error; se asume apagado.',
      );
      isBtOn = false;
    }

    var isLocServiceOn = true;
    if (sdkVersion <= 30) {
      try {
        final locStatus = await _locationServiceStatusChecker();
        isLocServiceOn = locStatus == ServiceStatus.enabled;
      } catch (error) {
        debugPrint(
          'Error al verificar el servicio de ubicación: $error; se asume apagado.',
        );
        isLocServiceOn = false;
      }
    }

    final isReady = missing.isEmpty && isBtOn && isLocServiceOn;
    String? failureMessage;

    if (permanentlyDenied.isNotEmpty) {
      failureMessage =
          'Permisos de Bluetooth denegados permanentemente. '
          'Abre los ajustes para concederlos.';
    } else if (missing.isNotEmpty) {
      failureMessage =
          'Faltan permisos de Bluetooth necesarios para operar en el aula.';
    } else if (!isBtOn) {
      failureMessage =
          'El Bluetooth está apagado. Enciéndelo para operar en el aula.';
    } else if (sdkVersion <= 30 && !isLocServiceOn) {
      failureMessage =
          'Activa la ubicación del celular. En Android 11 o anterior el Bluetooth '
          'la necesita para encontrar otros celulares; la app no guarda tu ubicación.';
    }

    return BlePermissionResult(
      isReady: isReady,
      missingPermissions: missing,
      permanentlyDeniedPermissions: permanentlyDenied,
      isBluetoothTurnedOn: isBtOn,
      isLocationServiceEnabled: isLocServiceOn,
      sdkVersion: sdkVersion,
      failureMessage: failureMessage,
    );
  }

  /// Solicita el encendido del adaptador Bluetooth en Android.
  Future<void> turnOnBluetooth() => _bluetoothTurnOnAction();

  /// Abre la pantalla de ajustes de la aplicación.
  Future<bool> openAppSettings() => _openAppSettingsAction();

  static Future<int> _defaultAndroidSdkVersion() async {
    try {
      final sdk = await androidSdkInt();
      if (sdk != null) {
        return sdk;
      }
      return 33;
    } catch (error) {
      debugPrint(
        'No se pudo determinar el SDK de Android: $error; '
        'se asume Android 12+ (SDK 31).',
      );
      return 31;
    }
  }

  static Future<PermissionStatus> _defaultCheckStatus(
    Permission permission,
  ) => permission.status;

  static Future<Map<Permission, PermissionStatus>> _defaultRequestPermissions(
    List<Permission> permissions,
  ) => permissions.request();

  static Stream<BluetoothAdapterState> _defaultAdapterStateStream() =>
      FlutterBluePlus.adapterState;

  static Future<void> _defaultTurnOnBluetooth() => FlutterBluePlus.turnOn();

  static Future<bool> _defaultOpenAppSettings() =>
      ph.openAppSettings();

  static Future<ServiceStatus> _defaultLocationServiceStatus() async {
    try {
      return await Permission.location.serviceStatus;
    } catch (error) {
      debugPrint('No se pudo verificar el servicio de ubicación: $error');
      return ServiceStatus.disabled;
    }
  }
}

/// Acción sugerida para resolver un problema de permisos o hardware BLE.
enum BleAdviceAction {
  turnOnBluetooth,
  checkLocation,
  openSettings,
  retry,
}

/// Diagnóstico con textos y acción recomendada para avisar al usuario.
class BlePermissionAdvice {
  const BlePermissionAdvice({
    required this.title,
    required this.message,
    required this.action,
    required this.isBluetoothOff,
    required this.isLocationOff,
    required this.requiresSettings,
  });

  final String title;
  final String message;
  final BleAdviceAction action;
  final bool isBluetoothOff;
  final bool isLocationOff;
  final bool requiresSettings;
}

/// Genera el título, mensaje explicativo y acción recomendada para mostrar en pantalla
/// según el resultado de [BlePermissionResult] y el propósito [purpose] en infinitivo
/// (por ejemplo, "tomar asistencia" o "registrar tu asistencia").
BlePermissionAdvice blePermissionAdvice(
  BlePermissionResult? result,
  String purpose, {
  String? bluetoothMessage,
}) {
  if (result == null) {
    return const BlePermissionAdvice(
      title: 'No se pudo revisar el Bluetooth',
      message: 'Inténtalo de nuevo.',
      action: BleAdviceAction.retry,
      isBluetoothOff: false,
      isLocationOff: false,
      requiresSettings: false,
    );
  }

  if (result.isReady) {
    return const BlePermissionAdvice(
      title: 'Listo',
      message: '',
      action: BleAdviceAction.retry,
      isBluetoothOff: false,
      isLocationOff: false,
      requiresSettings: false,
    );
  }

  if (result.isBluetoothOffBlocking) {
    return BlePermissionAdvice(
      title: 'El Bluetooth está apagado',
      message: bluetoothMessage ?? 'Enciéndelo para $purpose.',
      action: BleAdviceAction.turnOnBluetooth,
      isBluetoothOff: true,
      isLocationOff: false,
      requiresSettings: false,
    );
  }

  if (result.isLocationServiceOffBlocking) {
    return BlePermissionAdvice(
      title: 'Ubicación desactivada',
      message: result.failureMessage ??
          'Activa la ubicación del celular. En Android 11 o anterior el Bluetooth '
          'la necesita para encontrar otros celulares; la app no guarda tu ubicación.',
      action: BleAdviceAction.checkLocation,
      isBluetoothOff: false,
      isLocationOff: true,
      requiresSettings: false,
    );
  }

  final isAndroid11OrLower = result.isAndroid11OrLower ||
      result.missingPermissions.contains(Permission.locationWhenInUse);
  final permissionName =
      isAndroid11OrLower ? '«Ubicación»' : '«Dispositivos cercanos»';

  if (result.requiresAppSettings) {
    return BlePermissionAdvice(
      title: 'Falta un permiso',
      message: 'Abre los ajustes y permite $permissionName para $purpose.',
      action: BleAdviceAction.openSettings,
      isBluetoothOff: false,
      isLocationOff: false,
      requiresSettings: true,
    );
  }

  return BlePermissionAdvice(
    title: 'Falta un permiso',
    message: 'Permite el acceso a $permissionName para $purpose.',
    action: BleAdviceAction.retry,
    isBluetoothOff: false,
    isLocationOff: false,
    requiresSettings: false,
  );
}

