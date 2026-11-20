import 'dart:io';

import 'package:asistencia_uniguajira/data/services/app_permissions_service.dart';
import 'package:asistencia_uniguajira/data/services/ble_permission_service.dart';
import 'package:asistencia_uniguajira/features/shared/hardware_diagnostic_dialog.dart';
import 'package:asistencia_uniguajira/features/shared/permissions_gate.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeFailingAppPermissionsService extends AppPermissionsService {
  _FakeFailingAppPermissionsService({required this.shouldThrow})
      : super(needsCamera: false, sdkVersion: () => 33);

  bool shouldThrow;

  @override
  Future<AppPermissionsStatus> check() async {
    if (shouldThrow) {
      throw Exception('Fallo de prueba al consultar permisos');
    }
    return const AppPermissionsStatus(
      items: <AppPermissionItem>[],
      granted: <AppPermissionItem>{},
      permanentlyDenied: <AppPermissionItem>{},
      isLocationServiceEnabled: true,
    );
  }
}

void main() {
  group('BlePermissionService y Android <= 11', () {
    test(
      'SDK 30, permiso de ubicación concedido y servicio apagado -> ensureReady no está listo y su mensaje habla de activar la ubicación',
      () async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 30,
          permissionStatusChecker: (Permission p) async =>
              PermissionStatus.granted,
          locationServiceStatusChecker: () async => ServiceStatus.disabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        final result = await service.ensureReady();

        expect(result.isReady, isFalse);
        expect(result.isLocationServiceEnabled, isFalse);
        expect(
          result.failureMessage,
          contains('Activa la ubicación del celular'),
        );
      },
    );

    test('SDK 30, permiso concedido y servicio encendido -> listo', () async {
      final service = BlePermissionService(
        androidSdkVersionProvider: () => 30,
        permissionStatusChecker: (Permission p) async =>
            PermissionStatus.granted,
        locationServiceStatusChecker: () async => ServiceStatus.enabled,
        bluetoothAdapterStateProvider: () =>
            Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
      );

      final result = await service.ensureReady();

      expect(result.isReady, isTrue);
      expect(result.failureMessage, isNull);
      expect(result.isLocationServiceEnabled, isTrue);
    });

    test(
      'SDK 33 con los permisos de Bluetooth concedidos -> listo sin consultar el servicio de ubicación',
      () async {
        var locationServiceQueried = false;
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 33,
          permissionStatusChecker: (Permission p) async =>
              PermissionStatus.granted,
          locationServiceStatusChecker: () async {
            locationServiceQueried = true;
            return ServiceStatus.disabled;
          },
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        final result = await service.ensureReady();

        expect(result.isReady, isTrue);
        expect(locationServiceQueried, isFalse);
      },
    );
  });

  group('PermissionsGate y recuperación de errores', () {
    testWidgets(
      'PermissionsGate con un servicio cuyo check() lanza muestra «Reintentar»; al tocarlo con un servicio que ya responde, avanza',
      (WidgetTester tester) async {
        final fakeService = _FakeFailingAppPermissionsService(shouldThrow: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: PermissionsGate(
              service: fakeService,
              enabled: true,
              child: const Text('APP LISTA'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('APP LISTA'), findsNothing);
        expect(find.text('No pudimos revisar los permisos.'), findsOneWidget);
        expect(find.widgetWithText(UiButton, 'Reintentar'), findsOneWidget);

        // Ahora el servicio se recupera
        fakeService.shouldThrow = false;
        await tester.tap(find.widgetWithText(UiButton, 'Reintentar'));
        await tester.pump();
        await tester.pump();

        expect(find.text('No pudimos revisar los permisos.'), findsNothing);
        expect(find.text('APP LISTA'), findsOneWidget);
      },
    );
  });

  group('HardwareDiagnosticDialog', () {
    testWidgets(
      'El diálogo de diagnóstico con SDK 30 no muestra las filas de Bluetooth cercano y con needsCamera: false no muestra «Cámara»',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: Scaffold(
              body: HardwareDiagnosticDialog(
                sdkInt: 30,
                needsCamera: false,
                permissionChecker: (_) async => PermissionStatus.granted,
                locationServiceChecker: () async => ServiceStatus.enabled,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Filas de Bluetooth cercano NO deben aparecer en SDK 30
        expect(find.text('Buscar celulares cercanos'), findsNothing);
        expect(find.text('Avisar a celulares cercanos'), findsNothing);
        expect(find.text('Conectar con celulares cercanos'), findsNothing);

        // Cámara NO debe aparecer si needsCamera es false
        expect(find.textContaining('Cámara'), findsNothing);

        // Ubicación y Ubicación del celular encendida SÍ deben aparecer en SDK 30
        expect(find.text('Ubicación'), findsOneWidget);
        expect(find.text('Ubicación del celular encendida'), findsOneWidget);
      },
    );
  });

  group('Manifiesto de Docente y run.sh', () {
    test('AndroidManifest de docente remueve la cámara', () {
      final manifestFile = File('android/app/src/docente/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();
      expect(
        RegExp(r'tools:node="remove"').allMatches(content).length,
        1,
      );
    });

    test('run.sh tiene sintaxis bash correcta', () {
      final result = Process.runSync('bash', ['-n', 'run.sh']);
      expect(result.exitCode, 0);
    });
  });
}
