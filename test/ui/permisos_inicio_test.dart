import 'dart:io';

import 'package:asistencia_uniguajira/data/services/app_permissions_service.dart';
import 'package:asistencia_uniguajira/features/shared/permissions_gate.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permisos falsos que la prueba controla.
class _Phone {
  _Phone(this.statuses);

  final Map<Permission, PermissionStatus> statuses;
  final List<List<Permission>> requests = <List<Permission>>[];
  Map<Permission, PermissionStatus> onRequest = <Permission, PermissionStatus>{};

  AppPermissionsService service({required bool camera, int sdk = 34}) => AppPermissionsService(
        needsCamera: camera,
        sdkVersion: () => sdk,
        statusReader: (p) async => statuses[p] ?? PermissionStatus.denied,
        requester: (list) async {
          requests.add(list);
          final result = <Permission, PermissionStatus>{for (final p in list) p: onRequest[p] ?? PermissionStatus.denied};
          statuses.addAll(result);
          return result;
        },
      );
}

const _bt = [Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect];

Future<void> _loadFigtree() async {
  final loader = FontLoader(UiText.family);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(Future.value(ByteData.view(File('assets/fonts/Figtree-$w.ttf').readAsBytesSync().buffer)));
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, AppPermissionsService service, {bool dark = false}) async {
  tester.view.physicalSize = const Size(360, 640) * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(MaterialApp(
    theme: dark ? UiTheme.dark() : UiTheme.light(),
    home: PermissionsGate(service: service, enabled: true, child: const Text('INICIO DE LA APP')),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(_loadFigtree);

  group('AppPermissionsService', () {
    test('docente: solo dispositivos cercanos; estudiante: además la cámara', () async {
      final phone = _Phone({});
      expect((await phone.service(camera: false).requiredItems()).map((i) => i.title), ['Dispositivos cercanos']);
      expect((await phone.service(camera: true).requiredItems()).map((i) => i.title), ['Dispositivos cercanos', 'Cámara']);
    });

    test('Android 11 o anterior pide ubicación en lugar de dispositivos cercanos', () async {
      final items = await _Phone({}).service(camera: true, sdk: 30).requiredItems();
      expect(items.map((i) => i.title), ['Ubicación', 'Cámara']);
    });

    test('pide todo lo que falta en una sola solicitud', () async {
      final phone = _Phone({})..onRequest = {for (final p in [..._bt, Permission.camera]) p: PermissionStatus.granted};
      final status = await phone.service(camera: true).requestAll();
      expect(phone.requests, hasLength(1));
      expect(phone.requests.single.toSet(), {..._bt, Permission.camera});
      expect(status.allGranted, isTrue);
    });

    test('no vuelve a pedir lo bloqueado: hay que ir a Ajustes', () async {
      final phone = _Phone({
        for (final p in _bt) p: PermissionStatus.granted,
        Permission.camera: PermissionStatus.permanentlyDenied,
      });
      final status = await phone.service(camera: true).requestAll();
      expect(phone.requests, isEmpty);
      expect(status.allGranted, isFalse);
      expect(status.needsSettings, isTrue);
    });
  });

  group('PermissionsGate', () {
    for (final dark in [false, true]) {
      testWidgets('sin permisos no deja entrar y los pide de una vez (${dark ? 'oscuro' : 'claro'})', (tester) async {
        final phone = _Phone({})..onRequest = {for (final p in [..._bt, Permission.camera]) p: PermissionStatus.granted};
        await _pump(tester, phone.service(camera: true), dark: dark);

        expect(tester.takeException(), isNull);
        expect(find.text('INICIO DE LA APP'), findsNothing);
        expect(find.text('La app necesita estos permisos'), findsOneWidget);
        expect(find.text('Dispositivos cercanos'), findsOneWidget);
        expect(find.text('Cámara'), findsOneWidget);

        await tester.tap(find.widgetWithText(UiButton, 'Dar permisos'));
        await tester.pump();
        await tester.pump();
        expect(phone.requests, hasLength(1));
        expect(find.text('INICIO DE LA APP'), findsOneWidget);
      });
    }

    testWidgets('si los niega, sigue bloqueada y lo explica', (tester) async {
      final phone = _Phone({});
      await _pump(tester, phone.service(camera: false));
      await tester.tap(find.widgetWithText(UiButton, 'Dar permisos'));
      await tester.pump();
      await tester.pump();
      expect(find.text('INICIO DE LA APP'), findsNothing);
      expect(find.text('Sin estos permisos la app no puede tomar asistencia. Toca «Dar permisos» y acéptalos.'), findsOneWidget);
    });

    testWidgets('si están bloqueados ofrece Abrir ajustes', (tester) async {
      final phone = _Phone({for (final p in _bt) p: PermissionStatus.permanentlyDenied});
      await _pump(tester, phone.service(camera: false));
      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(find.text('Bloqueado'), findsOneWidget);
      expect(find.text('Android ya no deja pedirlos desde aquí'), findsOneWidget);
    });

    testWidgets('con todo concedido entra directo', (tester) async {
      final phone = _Phone({for (final p in [..._bt, Permission.camera]) p: PermissionStatus.granted});
      await _pump(tester, phone.service(camera: true));
      expect(find.text('INICIO DE LA APP'), findsOneWidget);
      expect(phone.requests, isEmpty);
    });
  });
}
