import 'dart:async';
import 'dart:io';

import 'package:asistencia_uniguajira/core/models/attendance_record_model.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/session_model.dart';
import 'package:asistencia_uniguajira/core/models/student_enrollment_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/attendance_session_controller.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:asistencia_uniguajira/data/services/ble_permission_service.dart';
import 'package:asistencia_uniguajira/features/shared/ble_ready_gate.dart';
import 'package:asistencia_uniguajira/features/student/student_live_beacon_screen.dart';
import 'package:asistencia_uniguajira/features/teacher/live_attendance_session_screen.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<bool> get enabled async => true;

  @override
  Future<void> toggle({required bool enable}) async {}
}

class _FakeAppDatabase extends AppDatabase {
  final Map<String, CourseModel> courses = <String, CourseModel>{};
  final Map<String, StudentModel> students = <String, StudentModel>{};
  final Map<String, SessionModel> sessions = <String, SessionModel>{};
  final Map<String, AttendanceRecordModel> records =
      <String, AttendanceRecordModel>{};

  @override
  Future<void> insertCourse(CourseModel course) async {
    courses[course.id] = course;
  }

  @override
  Future<void> insertStudent(StudentModel student) async {
    students[student.id] = student;
  }

  @override
  Future<List<StudentModel>> getStudentsByCourse(String courseId) async {
    return students.values.where((s) => s.courseId == courseId).toList();
  }

  @override
  Future<void> upsertSession(SessionModel session) async {
    sessions[session.id] = session;
  }

  @override
  Future<List<SessionModel>> getSessionsByCourse(String courseId) async {
    return sessions.values.where((s) => s.courseId == courseId).toList();
  }

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecordsBySession(
    String sessionId,
  ) async {
    return records.values.where((r) => r.sessionId == sessionId).toList();
  }

  @override
  Future<void> upsertAttendanceRecord(
    AttendanceRecordModel record, {
    String? bitmapHex,
  }) async {
    records['${record.sessionId}_${record.studentId}'] = record;
  }

  @override
  Future<int> deleteAttendanceRecord({
    required String sessionId,
    required String studentId,
    String? bitmapHex,
  }) async {
    final removed = records.remove('${sessionId}_$studentId');
    return removed != null ? 1 : 0;
  }

  @override
  Future<void> closeSessionWithActa({
    required String sessionId,
    required String closedAt,
    required String bitmapHex,
    required String actaJson,
    required String actaHmacSignature,
    String? actHash,
  }) async {
    final session = sessions[sessionId];
    if (session != null) {
      sessions[sessionId] = session.copyWith(
        closedAt: closedAt,
        bitmapHex: bitmapHex,
      );
    }
  }

  @override
  Future<void> close() async {}
}

class _FakeBleAttendanceService extends BleAttendanceService {
  @override
  Future<void> startScan({Duration? timeout}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> startAdvertisingPacket(List<int> packet16) async {}

  @override
  Future<void> stopAdvertising() async {}
}

class _FakeAttendanceSessionController extends AttendanceSessionController {
  _FakeAttendanceSessionController({
    required super.database,
    required super.bleService,
  });

  @override
  Future<void> dispose() async {}
}

const CourseModel _sampleCourse = CourseModel(
  id: 'course-comb-1',
  code: 'INF-201',
  name: 'Bases de Datos II',
  groupCode: '01',
  semester: '2026-2',
  courseSecret:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  createdAt: '2026-11-11T08:00:00.000Z',
);

const StudentEnrollmentModel _sampleEnrollment = StudentEnrollmentModel(
  id: 'course-comb-1_20261001',
  courseId: 'course-comb-1',
  courseCode: 'INF-201',
  courseName: 'Bases de Datos II',
  studentId: 'stud-comb-1',
  studentCode: '20261001',
  fullName: 'Estudiante Prueba',
  bitIndex: 7,
  deviceSecret:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  sharedSecret:
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
  enrolledAtEpochMs: 1762862400000,
);

Future<void> _loadFonts() async {
  final loader = FontLoader(UiText.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Figtree-$weight.ttf');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    final fakeWakelock = _FakeWakelockPlusPlatform();
    WakelockPlusPlatformInterface.instance = fakeWakelock;
    wakelockPlusPlatformInstance = fakeWakelock;
  });

  group('BlePermissionResult getters y asesoría', () {
    test('Con Bluetooth y ubicación apagados en SDK 30, getters bloqueantes y consejo', () {
      const result = BlePermissionResult(
        isReady: false,
        missingPermissions: <Permission>[],
        permanentlyDeniedPermissions: <Permission>[],
        isBluetoothTurnedOn: false,
        isLocationServiceEnabled: false,
        sdkVersion: 30,
        failureMessage: 'El Bluetooth está apagado. Enciéndelo para operar en el aula.',
      );

      expect(result.onlyBluetoothOff, isFalse);
      expect(result.onlyLocationServiceOff, isFalse);
      expect(result.isBluetoothOffBlocking, isTrue);
      expect(result.isLocationServiceOffBlocking, isTrue);

      final advice = blePermissionAdvice(result, 'tomar asistencia');
      expect(advice.title, 'El Bluetooth está apagado');
      expect(advice.isBluetoothOff, isTrue);
      expect(advice.isLocationOff, isFalse);
      expect(advice.action, BleAdviceAction.turnOnBluetooth);
    });

    test('Con Bluetooth encendido y ubicación apagada en SDK 30, getters y consejo', () {
      const result = BlePermissionResult(
        isReady: false,
        missingPermissions: <Permission>[],
        permanentlyDeniedPermissions: <Permission>[],
        isBluetoothTurnedOn: true,
        isLocationServiceEnabled: false,
        sdkVersion: 30,
        failureMessage:
            'Activa la ubicación del celular. En Android 11 o anterior el Bluetooth la necesita para encontrar otros celulares; la app no guarda tu ubicación.',
      );

      expect(result.isBluetoothOffBlocking, isFalse);
      expect(result.isLocationServiceOffBlocking, isTrue);
      expect(result.onlyLocationServiceOff, isTrue);

      final advice = blePermissionAdvice(result, 'tomar asistencia');
      expect(advice.title, 'Ubicación desactivada');
      expect(advice.isBluetoothOff, isFalse);
      expect(advice.isLocationOff, isTrue);
      expect(advice.action, BleAdviceAction.checkLocation);
      expect(advice.message, contains('Activa la ubicación del celular'));
    });
  });

  group('Criterios de aceptación R2-E', () {
    testWidgets(
      'SDK 30, permiso concedido, Bluetooth y ubicación apagados -> BleReadyGate muestra «Encender Bluetooth» (no «Falta un permiso»)',
      (WidgetTester tester) async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 30,
          permissionStatusChecker: (_) async => PermissionStatus.granted,
          locationServiceStatusChecker: () async => ServiceStatus.disabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.off),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: BleReadyGate(
              permissionService: service,
              title: 'Pasar asistencia',
              purpose: 'tomar asistencia',
              onBack: () {},
              builder: (_) => const Text('CONTENIDO LISTO'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('CONTENIDO LISTO'), findsNothing);
        expect(find.text('El Bluetooth está apagado'), findsOneWidget);
        expect(find.text('Encender Bluetooth'), findsOneWidget);
        expect(find.text('Falta un permiso'), findsNothing);
      },
    );

    testWidgets(
      'SDK 30, Bluetooth encendido y ubicación apagada -> mensaje de ubicación y «Revisar de nuevo»',
      (WidgetTester tester) async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 30,
          permissionStatusChecker: (_) async => PermissionStatus.granted,
          locationServiceStatusChecker: () async => ServiceStatus.disabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: BleReadyGate(
              permissionService: service,
              title: 'Pasar asistencia',
              purpose: 'tomar asistencia',
              onBack: () {},
              builder: (_) => const Text('CONTENIDO LISTO'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('CONTENIDO LISTO'), findsNothing);
        expect(find.text('Ubicación desactivada'), findsOneWidget);
        expect(find.text('Revisar de nuevo'), findsOneWidget);
        expect(
          find.textContaining('Activa la ubicación del celular'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'SDK 30 con el permiso de ubicación sin conceder -> el texto dice «Ubicación», no «Dispositivos cercanos»',
      (WidgetTester tester) async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 30,
          permissionStatusChecker: (_) async => PermissionStatus.denied,
          permissionRequester: (list) async => <Permission, PermissionStatus>{
            for (final p in list) p: PermissionStatus.denied,
          },
          locationServiceStatusChecker: () async => ServiceStatus.enabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: BleReadyGate(
              permissionService: service,
              title: 'Pasar asistencia',
              purpose: 'tomar asistencia',
              onBack: () {},
              builder: (_) => const Text('CONTENIDO LISTO'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Falta un permiso'), findsOneWidget);
        expect(find.textContaining('«Ubicación»'), findsOneWidget);
        expect(find.textContaining('«Dispositivos cercanos»'), findsNothing);
      },
    );

    testWidgets(
      'SDK 33 con permisos sin conceder -> el texto dice «Dispositivos cercanos»',
      (WidgetTester tester) async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 33,
          permissionStatusChecker: (_) async => PermissionStatus.denied,
          permissionRequester: (list) async => <Permission, PermissionStatus>{
            for (final p in list) p: PermissionStatus.denied,
          },
          locationServiceStatusChecker: () async => ServiceStatus.enabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: BleReadyGate(
              permissionService: service,
              title: 'Pasar asistencia',
              purpose: 'tomar asistencia',
              onBack: () {},
              builder: (_) => const Text('CONTENIDO LISTO'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Falta un permiso'), findsOneWidget);
        expect(find.textContaining('«Dispositivos cercanos»'), findsOneWidget);
        expect(find.textContaining('«Ubicación»'), findsNothing);
      },
    );

    testWidgets(
      'Las dos pantallas de asistencia (docente y estudiante) con SDK 30 y el permiso sin conceder no muestran «Dispositivos cercanos»',
      (WidgetTester tester) async {
        final service = BlePermissionService(
          androidSdkVersionProvider: () => 30,
          permissionStatusChecker: (_) async => PermissionStatus.denied,
          permissionRequester: (list) async => <Permission, PermissionStatus>{
            for (final p in list) p: PermissionStatus.denied,
          },
          locationServiceStatusChecker: () async => ServiceStatus.enabled,
          bluetoothAdapterStateProvider: () =>
              Stream<BluetoothAdapterState>.value(BluetoothAdapterState.on),
        );

        final database = _FakeAppDatabase();
        await database.insertCourse(_sampleCourse);
        final bleService = _FakeBleAttendanceService();

        // 1. Probar pantalla del docente (LiveAttendanceSessionScreen)
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: LiveAttendanceSessionScreen(
              course: _sampleCourse,
              database: database,
              permissionService: service,
              bleService: bleService,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Falta un permiso'), findsOneWidget);
        expect(find.textContaining('«Ubicación»'), findsOneWidget);
        expect(find.textContaining('«Dispositivos cercanos»'), findsNothing);

        await tester.pumpWidget(const SizedBox());

        // 2. Probar pantalla del estudiante (StudentLiveBeaconScreen)
        final sessionController = _FakeAttendanceSessionController(
          database: database,
          bleService: bleService,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: StudentLiveBeaconScreen(
              enrollment: _sampleEnrollment,
              database: database,
              sessionController: sessionController,
              permissionService: service,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // En la pantalla del estudiante se ingresa el PIN y se pulsa Continuar
        await tester.tap(find.text('4'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('7'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Continuar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Falta un permiso'), findsOneWidget);
        expect(find.textContaining('«Ubicación»'), findsOneWidget);
        expect(find.textContaining('«Dispositivos cercanos»'), findsNothing);
      },
    );
  });
}
