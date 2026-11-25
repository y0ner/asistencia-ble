import 'dart:async';
import 'dart:io';

import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/student_enrollment_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:asistencia_uniguajira/data/services/ble_permission_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_client_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_host_service.dart';
import 'package:asistencia_uniguajira/features/student/student_qr_enrollment_screen.dart';
import 'package:asistencia_uniguajira/features/teacher/enrollment_host_screen.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

const _secret = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const _course = CourseModel(
  id: 'curso-bd2',
  code: 'SIST-401',
  name: 'Bases de Datos II',
  groupCode: '01',
  semester: '2026-2',
  courseSecret: _secret,
  createdAt: '2026-11-01T08:00:00.000-05:00',
);

final _invite = ClassInvite(
  courseId: _course.id,
  courseCode: _course.code,
  courseName: _course.name,
  sharedSecretHex: _secret,
  teacherPublicKeyHex: 'ab' * 32,
);

class _NoopBle extends BleAttendanceService {
  @override
  Future<void> startScan({Duration? timeout}) async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> startAdvertisingPacket(List<int> packet16) async {}
  @override
  Future<void> stopAdvertising() async {}
}

class _NoopWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

BlePermissionService _permissions({bool bluetoothOn = true}) => BlePermissionService(
      androidSdkVersionProvider: () => 33,
      permissionStatusChecker: (Permission p) async => PermissionStatus.granted,
      permissionRequester: (List<Permission> list) async => {for (final p in list) p: PermissionStatus.granted},
      bluetoothAdapterStateProvider: () =>
          Stream<BluetoothAdapterState>.value(bluetoothOn ? BluetoothAdapterState.on : BluetoothAdapterState.off),
      bluetoothTurnOnAction: () async {},
    );

StudentModel _student(String code, String name, int bit, {bool bound = false}) => StudentModel(
      id: 's$bit',
      courseId: _course.id,
      studentCode: code,
      fullName: name,
      bitIndex: bit,
      personalSecret: _secret,
      deviceKeyId: bound ? '00112233aabbccdd' : null,
    );

/// Servicio del docente con estado controlado por la prueba (sin radio ni base de datos).
class _FakeHost extends EnrollmentHostService {
  _FakeHost() : super(course: _course, database: AppDatabase(), bleService: _NoopBle());

  final StreamController<EnrollmentHostState> _controller = StreamController<EnrollmentHostState>.broadcast();
  EnrollmentHostState _current = const EnrollmentHostState();
  final List<String> calls = <String>[];

  void emit(EnrollmentHostState state) {
    _current = state;
    _controller.add(state);
  }

  @override
  Stream<EnrollmentHostState> get states => _controller.stream;
  @override
  EnrollmentHostState get state => _current;
  @override
  Future<String> buildClassQrPayload() async => '{"v":2,"courseId":"curso-bd2"}';
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<StudentModel> approve(int requestId, {required String fullName, String? email}) async {
    calls.add('approve:$requestId:$fullName:${email ?? ''}');
    final student = _student('0182120099', fullName, 2, bound: true);
    emit(EnrollmentHostState(students: [..._current.students, student], recentlyEnrolled: [student]));
    return student;
  }

  @override
  Future<StudentModel> replaceDevice(int requestId) async {
    calls.add('replace:$requestId');
    return _current.students.first;
  }

  @override
  Future<void> reject(int requestId) async {
    calls.add('reject:$requestId');
    emit(EnrollmentHostState(students: _current.students));
  }
}

/// Servicio del estudiante que entrega los estados que decide la prueba.
class _FakeClient extends EnrollmentClientService {
  _FakeClient() : super(database: AppDatabase(), bleService: _NoopBle());

  StreamController<EnrollmentClientUpdate>? controller;
  String? lastCode;
  String? lastName;
  bool cancelled = false;

  @override
  Stream<EnrollmentClientUpdate> request({
    required ClassInvite invite,
    required String studentCode,
    required String displayName,
  }) {
    lastCode = studentCode;
    lastName = displayName;
    controller = StreamController<EnrollmentClientUpdate>();
    return controller!.stream;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

Future<void> _loadFigtree() async {
  final loader = FontLoader(UiText.family);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(Future.value(ByteData.view(File('assets/fonts/Figtree-$w.ttf').readAsBytesSync().buffer)));
  }
  await loader.load();
}

Future<void> _pump(WidgetTester tester, Widget screen, {bool dark = false}) async {
  tester.view.physicalSize = const Size(360, 640) * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(MaterialApp(theme: dark ? UiTheme.dark() : UiTheme.light(), home: screen));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() async {
    WakelockPlusPlatformInterface.instance = _NoopWakelock();
    await _loadFigtree();
  });

  group('Inscribir estudiantes (docente)', () {
    testWidgets('con el Bluetooth apagado pide encenderlo y no abre la inscripción', (tester) async {
      final host = _FakeHost();
      await _pump(
        tester,
        EnrollmentHostScreen(course: _course, permissionService: _permissions(bluetoothOn: false), hostService: host),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('El Bluetooth está apagado'), findsOneWidget);
      expect(find.text('Encender Bluetooth'), findsOneWidget);
      expect(host.calls, isNot(contains('start')));
    });

    for (final dark in [false, true]) {
      testWidgets('muestra el QR de la clase y el contador (${dark ? 'oscuro' : 'claro'})', (tester) async {
        final host = _FakeHost();
        await _pump(
          tester,
          EnrollmentHostScreen(course: _course, permissionService: _permissions(), hostService: host),
          dark: dark,
        );
        host.emit(EnrollmentHostState(students: [
          _student('0182120016', 'Ana Pérez', 0, bound: true),
          _student('0182120017', 'Carlos Iguarán', 1),
        ]));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(host.calls, contains('start'));
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Código de la clase'), findsOneWidget);
        expect(find.text('Inscritos'), findsOneWidget);
        expect(find.text('Los de tu lista entran solos. Faltan 1.'), findsOneWidget);
        expect(find.text('Terminar inscripción'), findsOneWidget);
      });
    }

    testWidgets('fuera de la lista: "Agregar" pide nombre y correo y aprueba', (tester) async {
      final host = _FakeHost();
      await _pump(tester, EnrollmentHostScreen(course: _course, permissionService: _permissions(), hostService: host));
      host.emit(EnrollmentHostState(pending: [
        PendingEnrollment(
          requestId: 77,
          studentCode: '0182120099',
          kind: PendingEnrollmentKind.notInRoster,
          receivedAt: DateTime(2026, 11, 14, 8),
        ),
      ]));
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Código 0182120099'), 200);
      expect(find.text('Por aprobar (1)'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(UiButton, 'Agregar'));
      await tester.pump();
      expect(find.text('No está en tu lista. Pregunta quién es y agrégalo con su nombre.'), findsOneWidget);
      await tester.tap(find.widgetWithText(UiButton, 'Agregar'));
      await _settle(tester);

      expect(find.text('Agregar a la clase'), findsOneWidget);
      await tester.tap(find.widgetWithText(UiButton, 'Agregar y aceptar'));
      await tester.pump();
      expect(find.text('Escribe el nombre completo.'), findsOneWidget); // no se aprueba sin nombre

      await tester.enterText(find.widgetWithText(TextField, 'Nombre completo'), 'María Epieyú');
      await tester.enterText(find.widgetWithText(TextField, 'Correo (opcional)'), 'mepieyu@institucion.edu.co');
      await tester.tap(find.widgetWithText(UiButton, 'Agregar y aceptar'));
      await _settle(tester);

      expect(host.calls, contains('approve:77:María Epieyú:mepieyu@institucion.edu.co'));
      expect(find.text('María Epieyú ya está en la clase.'), findsOneWidget);
      expect(find.text('Por aprobar (1)'), findsNothing);
    });

    testWidgets('conflicto de celular: "Reemplazar" confirma antes de cambiarlo; "Rechazar" lo descarta', (tester) async {
      final host = _FakeHost();
      final ana = _student('0182120016', 'Ana Pérez', 0, bound: true);
      await _pump(tester, EnrollmentHostScreen(course: _course, permissionService: _permissions(), hostService: host));
      host.emit(EnrollmentHostState(students: [ana], pending: [
        PendingEnrollment(
          requestId: 5,
          studentCode: '0182120016',
          kind: PendingEnrollmentKind.deviceConflict,
          receivedAt: DateTime(2026, 11, 14, 8),
          existingStudent: ana,
        ),
      ]));
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Ya tiene un celular vinculado y está pidiendo entrar con otro.'), 200);

      await tester.ensureVisible(find.widgetWithText(UiButton, 'Reemplazar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(UiButton, 'Reemplazar'));
      await _settle(tester);
      expect(find.text('¿Reemplazar el celular?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await _settle(tester);
      expect(host.calls.where((c) => c.startsWith('replace')), isEmpty);

      await tester.tap(find.widgetWithText(UiButton, 'Rechazar'));
      await _settle(tester);
      expect(host.calls, contains('reject:5'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('clase completa: lo avisa', (tester) async {
      final host = _FakeHost();
      await _pump(tester, EnrollmentHostScreen(course: _course, permissionService: _permissions(), hostService: host));
      host.emit(EnrollmentHostState(students: [
        for (var i = 0; i < AppConstants.bitmapBitCount; i++) _student('01821${i.toString().padLeft(5, '0')}', 'E $i', i),
      ]));
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('La clase ya está completa'), 200);
      expect(find.text('Una clase admite hasta 64 estudiantes. No se pueden agregar más.'), findsOneWidget);
    });
  });

  group('Unirme a una clase (estudiante)', () {
    Future<_FakeClient> openForm(WidgetTester tester, {bool dark = false}) async {
      final client = _FakeClient();
      await _pump(
        tester,
        StudentQrEnrollmentScreen(
          initialInvite: _invite,
          permissionService: _permissions(),
          bleService: _NoopBle(),
          clientService: client,
        ),
        dark: dark,
      );
      return client;
    }

    for (final dark in [false, true]) {
      testWidgets('el formulario muestra la clase y valida código y nombre (${dark ? 'oscuro' : 'claro'})', (tester) async {
        await openForm(tester, dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('Bases de Datos II'), findsOneWidget);
        await tester.tap(find.widgetWithText(UiButton, 'Unirme'));
        await tester.pump();
        expect(find.text('Escribe tu código estudiantil, solo números.'), findsOneWidget);
        expect(find.text('Escribe tu nombre.'), findsOneWidget);

        await tester.enterText(find.widgetWithText(TextField, 'Tu código estudiantil'), '01a82');
        await tester.pump();
        // Solo deja escribir números.
        expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Tu código estudiantil')).controller!.text, '0182');
      });
    }

    testWidgets('espera, pasa a "en revisión" y termina con "Ya estás en"', (tester) async {
      final client = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Tu código estudiantil'), '0182120016');
      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Yoner');
      await tester.tap(find.widgetWithText(UiButton, 'Unirme'));
      await _settle(tester);

      expect(client.lastCode, '0182120016');
      expect(client.lastName, 'Yoner');
      client.controller!.add(const EnrollmentClientUpdate(EnrollmentClientPhase.searching));
      await tester.pump();
      expect(find.text('Buscando a tu profesor'), findsOneWidget);

      client.controller!.add(const EnrollmentClientUpdate(EnrollmentClientPhase.pending));
      await tester.pump();
      expect(find.text('Tu profesor está revisando tu solicitud'), findsOneWidget);

      client.controller!.add(EnrollmentClientUpdate(
        EnrollmentClientPhase.accepted,
        enrollment: StudentEnrollmentModel(
          id: 'curso-bd2:0182120016',
          courseId: _course.id,
          courseCode: _course.code,
          courseName: _course.name,
          studentId: 'curso-bd2:0182120016',
          studentCode: '0182120016',
          fullName: 'Yoner',
          bitIndex: 3,
          deviceSecret: _secret,
          sharedSecret: _secret,
          enrolledAtEpochMs: 0,
        ),
      ));
      await _settle(tester);
      expect(find.text('Ya estás en'), findsOneWidget);
      expect(find.text('Ir a mis clases'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (phase, title) in [
      (EnrollmentClientPhase.rejected, 'Tu profesor no aprobó la solicitud'),
      (EnrollmentClientPhase.classFull, 'La clase ya está completa'),
      (EnrollmentClientPhase.timedOut, 'No encontramos a tu profesor'),
    ]) {
      testWidgets('resultado: $title', (tester) async {
        final client = await openForm(tester);
        await tester.enterText(find.widgetWithText(TextField, 'Tu código estudiantil'), '0182120016');
        await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Yoner');
        await tester.tap(find.widgetWithText(UiButton, 'Unirme'));
        await _settle(tester);
        client.controller!.add(EnrollmentClientUpdate(phase));
        await _settle(tester);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Intentar de nuevo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Cancelar" detiene la solicitud y vuelve al formulario', (tester) async {
      final client = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Tu código estudiantil'), '0182120016');
      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Yoner');
      await tester.tap(find.widgetWithText(UiButton, 'Unirme'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(UiButton, 'Cancelar'));
      // Cancelar una suscripción se resuelve en el reloj real, no en el simulado.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await _settle(tester);
      expect(client.cancelled, isTrue);
      expect(find.widgetWithText(UiButton, 'Unirme'), findsOneWidget);
    });
  });
}
