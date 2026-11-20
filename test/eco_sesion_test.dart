import 'dart:typed_data';

import 'package:asistencia_uniguajira/core/crypto/ble_packet_codec.dart';
import 'package:asistencia_uniguajira/core/models/student_enrollment_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/attendance_session_controller.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _courseId = 'course-eco-1';
const String _courseSecret =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const String _otherSecret =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const String _studentSecret =
    '1111111111111111111111111111111111111111111111111111111111111111';

class _FakeBleAttendanceService extends BleAttendanceService {
  @override
  Future<void> startScan({Duration? timeout}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> startAdvertisingPacket(Uint8List packet16) async {}

  @override
  Future<void> stopAdvertising() async {}
}

void main() {
  sqfliteFfiInit();

  group('Brief R2-A · Eco docente atado al PIN de la sesión y a la hora', () {
    const int pin42 = 42;
    const int pin43 = 43;
    const int tickT = 1000;

    late Uint8List bitmap;
    late Uint8List ecoT;

    setUp(() {
      bitmap = BlePacketCodec.setStudentBit(
        BlePacketCodec.createEmptyBitmap8(),
        7,
      );
      ecoT = BlePacketCodec.buildTeacherEchoBytes(
        courseId: _courseId,
        sessionPin: pin42,
        bitmap8: bitmap,
        sharedSecretHex: _courseSecret,
        timeTick: tickT,
      );
    });

    test(
      'Un eco con PIN 42 y tick T se acepta verificando con PIN 42 y tick T, T-1 y T+1',
      () {
        for (final tick in [tickT, tickT - 1, tickT + 1]) {
          final result = BlePacketCodec.verifyTeacherEchoBytes(
            packet16: ecoT,
            expectedCourseId: _courseId,
            expectedSessionPin: pin42,
            sharedSecretHex: _courseSecret,
            currentTimeTick: tick,
          );
          expect(
            result.isValid,
            isTrue,
            reason: 'Debe aceptar eco en tick $tick',
          );
          expect(result.failureReason, isNull);
          expect(result.bitmap8, isNotNull);
          expect(BlePacketCodec.isStudentBitSet(result.bitmap8!, 7), isTrue);
        }
      },
    );

    test(
      'El mismo eco se rechaza con tick T+2 (vencido) y con PIN 43 (otra sesión)',
      () {
        // Rechazo por tick vencido (T+2)
        final resultVencido = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoT,
          expectedCourseId: _courseId,
          expectedSessionPin: pin42,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT + 2,
        );
        expect(resultVencido.isValid, isFalse);
        expect(
          resultVencido.failureReason,
          'La firma HMAC del eco no es válida o está vencida.',
        );

        // Rechazo por tick anterior fuera de tolerancia (T-2)
        final resultAntiguo = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoT,
          expectedCourseId: _courseId,
          expectedSessionPin: pin42,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT - 2,
        );
        expect(resultAntiguo.isValid, isFalse);
        expect(
          resultAntiguo.failureReason,
          'La firma HMAC del eco no es válida o está vencida.',
        );

        // Rechazo por PIN diferente (otra sesión)
        final resultOtroPin = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoT,
          expectedCourseId: _courseId,
          expectedSessionPin: pin43,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT,
        );
        expect(resultOtroPin.isValid, isFalse);
        expect(
          resultOtroPin.failureReason,
          'El eco es de otra sesión.',
        );
      },
    );

    test(
      'Un eco de otro curso, uno adulterado y un paquete de estudiante se siguen rechazando',
      () {
        // Otro curso
        final resultOtroCurso = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoT,
          expectedCourseId: 'curso-diferente',
          expectedSessionPin: pin42,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT,
        );
        expect(resultOtroCurso.isValid, isFalse);
        expect(resultOtroCurso.failureReason, 'El eco pertenece a otro curso.');

        // Secreto erróneo
        final resultSecretoErroneo = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoT,
          expectedCourseId: _courseId,
          expectedSessionPin: pin42,
          sharedSecretHex: _otherSecret,
          currentTimeTick: tickT,
        );
        expect(resultSecretoErroneo.isValid, isFalse);
        expect(
          resultSecretoErroneo.failureReason,
          'La firma HMAC del eco no es válida o está vencida.',
        );

        // Paquete adulterado en el bitmap
        final ecoAdulterado = Uint8List.fromList(ecoT);
        ecoAdulterado[5] ^= 0xFF;
        final resultAdulterado = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: ecoAdulterado,
          expectedCourseId: _courseId,
          expectedSessionPin: pin42,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT,
        );
        expect(resultAdulterado.isValid, isFalse);
        expect(
          resultAdulterado.failureReason,
          'La firma HMAC del eco no es válida o está vencida.',
        );

        // Paquete de estudiante en vez de eco
        final studentBeacon = BlePacketCodec.buildStudentBeaconBytes(
          courseId: _courseId,
          bitIndex: 7,
          sessionPin: pin42,
          secretHex: _studentSecret,
          timeTick: tickT,
        );
        final resultStudentBeacon = BlePacketCodec.verifyTeacherEchoBytes(
          packet16: studentBeacon,
          expectedCourseId: _courseId,
          expectedSessionPin: pin42,
          sharedSecretHex: _courseSecret,
          currentTimeTick: tickT,
        );
        expect(resultStudentBeacon.isValid, isFalse);
        expect(
          resultStudentBeacon.failureReason,
          'El paquete no es un eco del docente.',
        );
      },
    );

    test(
      'checkTeacherEchoForStudent con el PIN equivocado no confirma, aunque el bit del estudiante esté encendido',
      () async {
        final database = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        );
        final ble = _FakeBleAttendanceService();
        final controller = AttendanceSessionController(
          database: database,
          bleService: ble,
        );

        final enrollment = StudentEnrollmentModel(
          id: '${_courseId}_0182120007',
          courseId: _courseId,
          courseCode: 'TEST-101',
          courseName: 'Pruebas Unitarias',
          studentId: 'student-7',
          studentCode: '0182120007',
          fullName: 'ESTUDIANTE SIETE',
          bitIndex: 7,
          deviceSecret: _studentSecret,
          sharedSecret: _courseSecret,
          enrolledAtEpochMs: 1762416120000,
        );

        final now = DateTime.fromMillisecondsSinceEpoch(tickT * 30 * 1000);

        // Intento con PIN 43 cuando el eco fue generado con PIN 42
        final outcome = await controller.checkTeacherEchoForStudent(
          enrollment: enrollment,
          sessionPin: pin43,
          teacherPacket16: ecoT,
          rssi: -60,
          nowOverride: now,
        );

        expect(outcome.isConfirmed, isFalse);
        expect(outcome.isGreenSeal, isFalse);
        expect(outcome.verifyCode, isNull);
        expect(outcome.failureReason, 'El eco es de otra sesión.');

        // Verificamos que con el PIN 42 correcto sí confirma
        final outcomeCorrecto = await controller.checkTeacherEchoForStudent(
          enrollment: enrollment,
          sessionPin: pin42,
          teacherPacket16: ecoT,
          rssi: -60,
          nowOverride: now,
        );

        expect(outcomeCorrecto.isConfirmed, isTrue);
        expect(outcomeCorrecto.isGreenSeal, isTrue);
        expect(outcomeCorrecto.verifyCode, isNotNull);

        await controller.dispose();
        await ble.dispose();
        await database.close();
      },
    );
  });
}
