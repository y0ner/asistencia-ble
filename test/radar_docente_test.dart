import 'dart:convert';
import 'dart:typed_data';

import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/crypto/ble_packet_codec.dart';
import 'package:asistencia_uniguajira/core/models/attendance_record_model.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/attendance_session_controller.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _courseSecret =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const String _studentSecret0 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const String _studentSecret1 =
    '2222222222222222222222222222222222222222222222222222222222222222';
const String _studentSecret2 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const String _studentSecret63 =
    '4444444444444444444444444444444444444444444444444444444444444444';

CourseModel _course() {
  return const CourseModel(
    id: 'course-radar-1',
    code: 'SIST-301',
    name: 'Sistemas Distribuidos',
    groupCode: '01',
    semester: '2026-2',
    courseSecret: _courseSecret,
    createdAt: '2026-11-06T08:00:00.000Z',
  );
}

StudentModel _student({
  required String id,
  required String studentCode,
  required String fullName,
  required int bitIndex,
  required String personalSecret,
}) {
  return StudentModel(
    id: id,
    courseId: 'course-radar-1',
    studentCode: studentCode,
    fullName: fullName,
    email: '$studentCode${AppConstants.institutionalDomain}',
    bitIndex: bitIndex,
    personalSecret: personalSecret,
    enrolledAt: '2026-11-06T08:02:00.000Z',
  );
}

class _FakeBleAttendanceService extends BleAttendanceService {
  final List<Uint8List> advertisements = <Uint8List>[];
  final List<String> lifecycle = <String>[];
  bool _scanning = false;
  bool _advertising = false;

  @override
  bool get isScanning => _scanning;

  @override
  bool get isAdvertising => _advertising;

  @override
  Future<void> startScan({Duration? timeout}) async {
    _scanning = true;
    lifecycle.add('scan-start');
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
    lifecycle.add('scan-stop');
  }

  @override
  Future<void> startAdvertisingPacket(Uint8List packet16) async {
    _advertising = true;
    advertisements.add(Uint8List.fromList(packet16));
  }

  @override
  Future<void> stopAdvertising() async {
    _advertising = false;
    lifecycle.add('ad-stop');
  }
}

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase({
    required super.factory,
    required super.databasePath,
  });

  bool shouldFailCloseActa = false;

  @override
  Future<void> closeSessionWithActa({
    required String sessionId,
    required String closedAt,
    required String bitmapHex,
    required String actaJson,
    required String actaHmacSignature,
    String? actHash,
  }) async {
    if (shouldFailCloseActa) {
      throw Exception('Fallo inducido al persistir el acta en SQLite.');
    }
    await super.closeSessionWithActa(
      sessionId: sessionId,
      closedAt: closedAt,
      bitmapHex: bitmapHex,
      actaJson: actaJson,
      actaHmacSignature: actaHmacSignature,
      actHash: actHash,
    );
  }
}

void main() {
  sqfliteFfiInit();

  group('Radar del Docente (Brief R1-A)', () {
    late _TestAppDatabase database;
    late _FakeBleAttendanceService ble;
    late AttendanceSessionController controller;
    late CourseModel course;
    late StudentModel student0;
    late StudentModel student1;
    late StudentModel student2;
    late StudentModel student63;

    setUp(() async {
      database = _TestAppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      course = _course();
      await database.insertCourse(course);
      student0 = _student(
        id: 'student-0',
        studentCode: '0182120016',
        fullName: 'ANA MARIA GOMEZ',
        bitIndex: 0,
        personalSecret: _studentSecret0,
      );
      student1 = _student(
        id: 'student-1',
        studentCode: '0182120017',
        fullName: 'LUIS ALBERTO PEREZ',
        bitIndex: 1,
        personalSecret: _studentSecret1,
      );
      student2 = _student(
        id: 'student-2',
        studentCode: '0182120018',
        fullName: 'SOFIA GARRIDO',
        bitIndex: 2,
        personalSecret: _studentSecret2,
      );
      student63 = _student(
        id: 'student-63',
        studentCode: '0182120063',
        fullName: 'CARLOS ENRIQUE VALDEZ',
        bitIndex: 63,
        personalSecret: _studentSecret63,
      );
      for (final student in [student0, student1, student2, student63]) {
        await database.insertStudent(student);
      }
      ble = _FakeBleAttendanceService();
      controller = AttendanceSessionController(
        database: database,
        bleService: ble,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await ble.dispose();
      await database.close();
    });

    test(
      'procesar 50 veces el mismo paquete valido de un estudiante deja un registro y su recordedAt es el de la primera deteccion',
      () async {
        final state = await controller.startTeacherSession(
          course: course,
          customPin: 42,
        );
        final t1 = DateTime.utc(2026, 11, 20, 8, 0, 0);
        final tick1 = BlePacketCodec.computeTimeTick(t1);
        final packet = BlePacketCodec.buildStudentBeaconBytes(
          courseId: course.id,
          bitIndex: student0.bitIndex,
          sessionPin: 42,
          secretHex: student0.personalSecret,
          timeTick: tick1,
        );

        final outcome1 = await controller.processIncomingStudentPacket(
          packet16: packet,
          rssi: -60,
          nowOverride: t1,
        );
        expect(outcome1.isAccepted, isTrue);

        // 49 detecciones repetidas con instantes de tiempo posteriores
        for (int i = 1; i < 50; i++) {
          final ti = t1.add(Duration(seconds: i));
          final outcomeI = await controller.processIncomingStudentPacket(
            packet16: packet,
            rssi: -50,
            nowOverride: ti,
          );
          expect(outcomeI.isAccepted, isTrue);
        }

        final records =
            await database.getAttendanceRecordsBySession(state.session.id);
        expect(records, hasLength(1));
        expect(records.first.studentId, student0.id);
        expect(records.first.recordedAt, t1.toIso8601String());
        expect(records.first.rssiAvg, -60.0);
      },
    );

    test(
      'estudiante marcado a mano con nota llego tarde y luego llega su beacon: el registro sigue con metodo manual, la nota y la hora original',
      () async {
        final state = await controller.startTeacherSession(
          course: course,
          customPin: 42,
        );

        // Marcado manual con nota
        await controller.toggleManualAttendance(
          studentId: student0.id,
          isPresent: true,
          observation: 'llegó tarde',
        );

        final recordsBefore =
            await database.getAttendanceRecordsBySession(state.session.id);
        expect(recordsBefore, hasLength(1));
        final original = recordsBefore.first;
        expect(original.method, AppConstants.attendanceMethodManualInverted);
        expect(original.observation, 'llegó tarde');

        // Luego llega su beacon
        final tBeacon = DateTime.utc(2026, 11, 20, 8, 20, 0);
        final tickBeacon = BlePacketCodec.computeTimeTick(tBeacon);
        final packet = BlePacketCodec.buildStudentBeaconBytes(
          courseId: course.id,
          bitIndex: student0.bitIndex,
          sessionPin: 42,
          secretHex: student0.personalSecret,
          timeTick: tickBeacon,
        );

        final outcome = await controller.processIncomingStudentPacket(
          packet16: packet,
          rssi: -55,
          nowOverride: tBeacon,
        );
        expect(outcome.isAccepted, isTrue);

        final recordsAfter =
            await database.getAttendanceRecordsBySession(state.session.id);
        expect(recordsAfter, hasLength(1));
        final finalRecord = recordsAfter.first;
        expect(finalRecord.method, AppConstants.attendanceMethodManualInverted);
        expect(finalRecord.observation, 'llegó tarde');
        expect(finalRecord.recordedAt, original.recordedAt);
        expect(finalRecord.timeTick, original.timeTick);
        expect(finalRecord.hmacTag, isNull);
      },
    );

    test(
      'editar la nota de un presente cambia la nota y conserva method y recordedAt',
      () async {
        final state = await controller.startTeacherSession(
          course: course,
          customPin: 42,
        );
        final tBle = DateTime.utc(2026, 11, 20, 8, 5, 0);
        final tick = BlePacketCodec.computeTimeTick(tBle);

        // Detección inicial BLE
        final packet = BlePacketCodec.buildStudentBeaconBytes(
          courseId: course.id,
          bitIndex: student0.bitIndex,
          sessionPin: 42,
          secretHex: student0.personalSecret,
          timeTick: tick,
        );
        await controller.processIncomingStudentPacket(
          packet16: packet,
          rssi: -65,
          nowOverride: tBle,
        );

        final recordsInitial =
            await database.getAttendanceRecordsBySession(state.session.id);
        final initial = recordsInitial.first;
        expect(initial.method, AppConstants.attendanceMethodBleHmac);
        expect(initial.recordedAt, tBle.toIso8601String());
        expect(initial.observation, isNull);
        expect(initial.rssiAvg, -65.0);

        // Docente edita la nota a mano
        await controller.toggleManualAttendance(
          studentId: student0.id,
          isPresent: true,
          observation: 'Presentó excusa médica',
        );

        final recordsUpdated =
            await database.getAttendanceRecordsBySession(state.session.id);
        expect(recordsUpdated, hasLength(1));
        final updated = recordsUpdated.first;
        expect(updated.observation, 'Presentó excusa médica');
        expect(updated.method, AppConstants.attendanceMethodBleHmac);
        expect(updated.recordedAt, initial.recordedAt);
        expect(updated.timeTick, initial.timeTick);
        expect(updated.hmacTag, initial.hmacTag);
        expect(updated.rssiAvg, -65.0);
      },
    );

    test(
      'sesion abierta de ayer con un registro: startTeacherSession crea sesion nueva y la de ayer queda cerrada con acta y closedAt de su registro',
      () async {
        final ayer = DateTime(2026, 11, 19, 9, 0, 0);
        final hoy = DateTime(2026, 11, 20, 8, 0, 0);
        final horaRegistroAyer = DateTime(2026, 11, 19, 9, 30, 0);

        final sesionAyer = await controller.startTeacherSession(
          course: course,
          customPin: 33,
          nowOverride: ayer,
        );
        await database.insertAttendanceRecord(
          AttendanceRecordModel(
            id: 'rec-ayer',
            sessionId: sesionAyer.session.id,
            studentId: student0.id,
            bitIndex: student0.bitIndex,
            method: AppConstants.attendanceMethodManualInverted,
            recordedAt: horaRegistroAyer.toIso8601String(),
          ),
        );

        await controller.dispose();
        controller = AttendanceSessionController(
          database: database,
          bleService: ble,
        );

        final sesionHoy = await controller.startTeacherSession(
          course: course,
          customPin: 77,
          nowOverride: hoy,
        );

        expect(sesionHoy.session.id, isNot(sesionAyer.session.id));
        expect(sesionHoy.pin, 77);

        final sesionAyerDb =
            await database.getSessionById(sesionAyer.session.id);
        expect(sesionAyerDb, isNotNull);
        expect(sesionAyerDb!.closedAt, horaRegistroAyer.toIso8601String());
        expect(sesionAyerDb.actHash, isNotNull);

        final actaJson =
            await database.getSessionActaJson(sesionAyer.session.id);
        expect(actaJson, isNotNull);
        final actaMap = jsonDecode(actaJson!) as Map<String, dynamic>;
        expect(actaMap['closedAtIso'], horaRegistroAyer.toIso8601String());
        expect(actaMap['presentManualCount'], 1);

        final signature =
            await database.getSessionActaSignature(sesionAyer.session.id);
        expect(signature, isNotNull);
        expect(signature, hasLength(64));
      },
    );

    test(
      'sesion abierta de ayer sin registros: se borra y se crea una nueva',
      () async {
        final ayer = DateTime(2026, 11, 19, 14, 0, 0);
        final hoy = DateTime(2026, 11, 20, 8, 0, 0);

        final sesionAyer = await controller.startTeacherSession(
          course: course,
          customPin: 55,
          nowOverride: ayer,
        );
        await controller.dispose();
        controller = AttendanceSessionController(
          database: database,
          bleService: ble,
        );

        final sesionHoy = await controller.startTeacherSession(
          course: course,
          customPin: 88,
          nowOverride: hoy,
        );

        expect(sesionHoy.session.id, isNot(sesionAyer.session.id));
        final sesionAyerDb =
            await database.getSessionById(sesionAyer.session.id);
        expect(sesionAyerDb, isNull);
      },
    );

    test(
      'sesion abierta de hoy: se retoma con mismo id y PIN',
      () async {
        final hoyManana = DateTime(2026, 11, 20, 8, 0, 0);
        final hoyTarde = DateTime(2026, 11, 20, 8, 30, 0);

        final primera = await controller.startTeacherSession(
          course: course,
          customPin: 49,
          nowOverride: hoyManana,
        );
        await controller.toggleManualAttendance(
          studentId: student1.id,
          isPresent: true,
        );
        await controller.dispose();

        controller = AttendanceSessionController(
          database: database,
          bleService: ble,
        );
        final retomada = await controller.startTeacherSession(
          course: course,
          customPin: 99,
          nowOverride: hoyTarde,
        );

        expect(retomada.session.id, primera.session.id);
        expect(retomada.pin, 49);
        expect(
          BlePacketCodec.isStudentBitSet(retomada.bitmap8, student1.bitIndex),
          isTrue,
        );
      },
    );

    test(
      'si guardar el acta falla en closeSessionWithActa, closeAndSignSession relanza y el escaneo vuelve a estar activo',
      () async {
        await controller.startTeacherSession(course: course, customPin: 42);
        expect(ble.isScanning, isTrue);

        database.shouldFailCloseActa = true;
        addTearDown(() => database.shouldFailCloseActa = false);

        await expectLater(
          () => controller.closeAndSignSession(),
          throwsA(isA<Exception>()),
        );

        expect(controller.state?.isOpen, isTrue);
        expect(ble.isScanning, isTrue);
      },
    );

    test(
      'dispose detiene el runtime BLE despues de procesar la cola de operaciones',
      () async {
        await controller.startTeacherSession(course: course, customPin: 42);
        expect(ble.isScanning, isTrue);

        await controller.dispose();
        expect(ble.isScanning, isFalse);
        expect(ble.isAdvertising, isFalse);
        expect(controller.state, isNull);
      },
    );

    test(
      'si controller es liberado antes de iniciar escaneo, no suscribe ni escanea',
      () async {
        final ctrl = AttendanceSessionController(database: database, bleService: ble);
        await ctrl.dispose();
        expect(
          () => ctrl.startTeacherSession(course: course, customPin: 42),
          throwsStateError,
        );
      },
    );
  });
}
