import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/models/attendance_record_model.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/session_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/course_overview_service.dart';
import 'package:asistencia_uniguajira/data/services/student_admin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _secret = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

StudentModel _student(int bit, String name, {bool bound = false}) => StudentModel(
      id: 's$bit',
      courseId: 'c1',
      studentCode: '018212001$bit',
      fullName: name,
      bitIndex: bit,
      personalSecret: _secret,
      deviceKeyId: bound ? 'aabbccdd00112233' : null,
      deviceBoundAt: bound ? '2026-11-12T08:00:00.000-05:00' : null,
    );

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late StudentAdminService admin;

  setUp(() async {
    db = AppDatabase(factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath);
    admin = StudentAdminService(database: db, now: () => DateTime(2026, 11, 12, 9));
    await db.insertCourse(const CourseModel(
      id: 'c1',
      code: 'SIST-401',
      name: 'Bases de Datos II',
      groupCode: '01',
      semester: '2026-2',
      courseSecret: _secret,
      createdAt: '2026-11-01T08:00:00.000-05:00',
    ));
  });

  tearDown(() => db.close());

  Future<void> addAttendance(StudentModel s) async {
    await db.insertSession(const SessionModel(
      id: 'ses1',
      courseId: 'c1',
      startedAt: '2026-11-02T08:00:00.000-05:00',
      roomPin: '47',
    ));
    await db.insertAttendanceRecord(AttendanceRecordModel(
      id: 'r-${s.id}',
      sessionId: 'ses1',
      studentId: s.id,
      bitIndex: s.bitIndex,
      method: AppConstants.attendanceMethodBleHmac,
      recordedAt: '2026-11-02T08:10:00.000-05:00',
    ));
  }

  test('sin asistencias se elimina por completo', () async {
    final s = _student(0, 'Ana Lucía Pérez');
    await db.insertStudent(s);
    expect(await admin.removalKindFor(s), StudentRemovalKind.delete);
    expect(await admin.remove(s), StudentRemovalKind.delete);
    expect(await db.getAllStudentsByCourse('c1'), isEmpty);
  });

  test('con asistencias se retira: conserva historial y pierde el celular', () async {
    final s = _student(1, 'Carlos Iguarán', bound: true);
    await db.insertStudent(s);
    await addAttendance(s);

    expect(await admin.removalKindFor(s), StudentRemovalKind.retire);
    expect(await admin.remove(s), StudentRemovalKind.retire);

    expect(await db.getStudentsByCourse('c1'), isEmpty); // ya no entra a sesiones nuevas
    final retired = (await db.getAllStudentsByCourse('c1')).single;
    expect(retired.isRetired, isTrue);
    expect(retired.retiredAt, startsWith('2026-11-12'));
    expect(retired.hasDevice, isFalse);
    expect(retired.personalSecret, isNot(_secret)); // su celular deja de ser reconocido
    expect(await db.countAttendanceByStudent(s.id), 1); // el historial sigue
  });

  test('desvincular cambia el secreto y deja al estudiante activo', () async {
    final s = _student(2, 'María Epieyú', bound: true);
    await db.insertStudent(s);
    await admin.unbindDevice(s);
    final after = (await db.getStudentById(s.id))!;
    expect(after.isActive, isTrue);
    expect(after.hasDevice, isFalse);
    expect(after.personalSecret, isNot(_secret));
  });

  test('la segunda confirmación acepta el primer nombre sin tildes ni mayúsculas', () {
    final s = _student(3, 'José María Pushaina');
    expect(StudentAdminService.firstNameOf(s), 'José');
    expect(StudentAdminService.confirmsFirstName(s, 'jose'), isTrue);
    expect(StudentAdminService.confirmsFirstName(s, ' JOSÉ '), isTrue);
    expect(StudentAdminService.confirmsFirstName(s, 'Jos'), isFalse);
    expect(StudentAdminService.confirmsFirstName(s, ''), isFalse);
    expect(StudentAdminService.confirmsFirstName(s, 'María'), isFalse);
  });

  test('el resumen de la clase cuenta los celulares vinculados y excluye retirados', () async {
    await db.insertStudent(_student(0, 'Ana Pérez', bound: true));
    await db.insertStudent(_student(1, 'Carlos Iguarán'));
    final third = _student(2, 'Luisa Brito', bound: true);
    await db.insertStudent(third);
    await addAttendance(third);
    await admin.remove(third); // retirada

    final overview = await CourseOverviewService(database: db).load('c1');
    expect(overview.studentCount, 2);
    expect(overview.boundCount, 1);
  });
}
