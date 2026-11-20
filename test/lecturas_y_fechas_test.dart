import 'dart:convert';

import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/models/attendance_record_model.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/session_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/course_overview_service.dart';
import 'package:asistencia_uniguajira/data/services/excel_report_service.dart';
import 'package:asistencia_uniguajira/features/teacher/course_reports_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _secret =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

CourseModel _course(String id, String name) => CourseModel(
      id: id,
      code: 'SIST-$id',
      name: name,
      groupCode: '01',
      semester: '2026-2',
      courseSecret: _secret,
      createdAt: '2026-11-01T08:00:00.000-05:00',
    );

StudentModel _student(
  String courseId,
  int bit, {
  String? enrolledAt,
  String status = AppConstants.studentStatusActive,
  String? retiredAt,
}) =>
    StudentModel(
      id: '$courseId-s$bit',
      courseId: courseId,
      studentCode: '01821200${bit.toString().padLeft(2, '0')}',
      fullName: 'Estudiante $bit',
      bitIndex: bit,
      personalSecret: _secret,
      enrolledAt: enrolledAt ?? '2026-11-01T08:00:00.000-05:00',
      status: status,
      retiredAt: retiredAt,
    );

AttendanceRecordModel _record(
  String sessionId,
  StudentModel s, {
  bool manual = false,
  String? recordedAt,
}) =>
    AttendanceRecordModel(
      id: '$sessionId-${s.id}',
      sessionId: sessionId,
      studentId: s.id,
      bitIndex: s.bitIndex,
      method: manual
          ? AppConstants.attendanceMethodManualInverted
          : AppConstants.attendanceMethodBleHmac,
      recordedAt: recordedAt ?? '2026-11-02T08:10:00.000-05:00',
    );

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late ExcelReportService excelService;
  late CourseOverviewService service;

  setUp(() {
    db = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    excelService = ExcelReportService(database: db);
    service = CourseOverviewService(database: db, reportService: excelService);
  });

  tearDown(() => db.close());

  group('Lecturas no modifican sesiones y selección de sesión en curso', () {
    test(
      'Clase con dos sesiones abiertas de hoy (una sin registros): '
      'load() no borra ni cierra ninguna y la sesión en curso es la más reciente',
      () async {
        final course = _course('c-open-today', 'Ingeniería de Software');
        await db.insertCourse(course);
        final s1 = _student(course.id, 0);
        await db.insertStudent(s1);

        final now = DateTime.now();
        final earlierToday = now
            .subtract(const Duration(minutes: 30))
            .toIso8601String();
        final laterToday = now
            .subtract(const Duration(minutes: 5))
            .toIso8601String();

        // Sesión 1: abierta hoy, sin registros.
        await db.insertSession(SessionModel(
          id: 'ses-today-empty',
          courseId: course.id,
          startedAt: earlierToday,
          roomPin: '11',
        ));

        // Sesión 2: abierta hoy, más reciente, con un registro de asistencia.
        await db.insertSession(SessionModel(
          id: 'ses-today-with-rec',
          courseId: course.id,
          startedAt: laterToday,
          roomPin: '22',
        ));
        await db.insertAttendanceRecord(_record('ses-today-with-rec', s1));

        // Comprobación antes de llamar a load()
        final sessionsBefore = await db.getSessionsByCourse(course.id);
        expect(sessionsBefore.length, 2);
        expect(sessionsBefore.every((s) => s.closedAt == null), isTrue);

        final overview = await service.load(course.id);

        // Comprobación después de llamar a load(): no se borró ni cerró ninguna
        final sessionsAfter = await db.getSessionsByCourse(course.id);
        expect(sessionsAfter.length, 2);
        expect(sessionsAfter.every((s) => s.closedAt == null), isTrue);

        // La sesión en curso es la más reciente
        expect(overview.openSession, isNotNull);
        expect(overview.openSession!.session.id, 'ses-today-with-rec');
        expect(overview.openSession!.presentCount, 1);
      },
    );

    test(
      'Clase con una sesión abierta de ayer: load() no la modifica y no la muestra como en curso',
      () async {
        final course = _course('c-open-yesterday', 'Redes de Computadores');
        await db.insertCourse(course);
        final s1 = _student(course.id, 0);
        await db.insertStudent(s1);

        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String();

        await db.insertSession(SessionModel(
          id: 'ses-yesterday',
          courseId: course.id,
          startedAt: yesterday,
          roomPin: '33',
        ));

        final sessionsBefore = await db.getSessionsByCourse(course.id);
        expect(sessionsBefore.length, 1);
        expect(sessionsBefore.first.closedAt, isNull);

        final overview = await service.load(course.id);

        // La sesión no fue modificada
        final sessionsAfter = await db.getSessionsByCourse(course.id);
        expect(sessionsAfter.length, 1);
        expect(sessionsAfter.first.closedAt, isNull);

        // No se muestra como en curso
        expect(overview.openSession, isNull);
        // Pero aparece en sesiones recientes de la clase
        expect(overview.recentSessions.length, 1);
        expect(overview.recentSessions.first.session.id, 'ses-yesterday');
        expect(overview.recentSessions.first.isOpen, isTrue);
      },
    );
  });

  group('Formato de fechas en el Excel', () {
    test(
      'En el Excel, una sesión iniciada a las 2026-11-19T08:05:00.000 (hora local) '
      'aparece como 2026-11-19 08:05 en Detalle y en Sesiones',
      () async {
        final course = _course('c-fechas', 'Sistemas Operativos');
        await db.insertCourse(course);
        final s1 = _student(course.id, 0);
        await db.insertStudent(s1);

        const startedAt = '2026-11-19T08:05:00.000';
        const closedAt = '2026-11-19T10:15:00.000';

        await db.insertSession(const SessionModel(
          id: 'ses-fechas-1',
          courseId: 'c-fechas',
          startedAt: startedAt,
          closedAt: closedAt,
          roomPin: '55',
        ));
        await db.insertAttendanceRecord(_record('ses-fechas-1', s1));

        final summary = await excelService.buildCourseSummary(course.id);

        // Comprobación en Detalle
        final detailRows = summary.sheets['Detalle']!;
        expect(detailRows.first[1], 'FechaApertura');
        expect(detailRows.first[2], 'FechaCierre');

        final detailDataRow = detailRows.skip(1).first;
        expect(detailDataRow[0], 'ses-fechas-1');
        expect(detailDataRow[1], '2026-11-19 08:05');
        expect(detailDataRow[2], '2026-11-19 10:15');

        // Comprobación en Sesiones
        final sessionRows = summary.sheets['Sesiones']!;
        expect(sessionRows.first[2], 'FechaApertura');
        expect(sessionRows.first[3], 'FechaCierre');

        final sessionDataRow = sessionRows.skip(1).first;
        expect(sessionDataRow[0], 'ses-fechas-1');
        expect(sessionDataRow[2], '2026-11-19 08:05');
        expect(sessionDataRow[3], '2026-11-19 10:15');
      },
    );

    test(
      'Metadatos tiene FechaGeneracionISO8601 y FechaGeneracionLocal',
      () async {
        final course = _course('c-meta', 'Bases de Datos');
        await db.insertCourse(course);

        final summary = await excelService.buildCourseSummary(course.id);
        final metaRows = summary.sheets['Metadatos']!;

        final metaMap = <String, String>{
          for (final row in metaRows.skip(1))
            row[0].toString(): row[1].toString(),
        };

        expect(metaMap.containsKey('FechaGeneracionISO8601'), isTrue);
        expect(metaMap.containsKey('FechaGeneracionLocal'), isTrue);

        final isoVal = metaMap['FechaGeneracionISO8601']!;
        final localVal = metaMap['FechaGeneracionLocal']!;

        expect(DateTime.tryParse(isoVal), isNotNull);
        expect(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(localVal), isTrue);

        // FechaGeneracionLocal debe estar justo debajo de FechaGeneracionISO8601
        final isoIndex = metaRows.indexWhere((r) => r[0] == 'FechaGeneracionISO8601');
        final localIndex = metaRows.indexWhere((r) => r[0] == 'FechaGeneracionLocal');
        expect(localIndex, isoIndex + 1);
      },
    );
  });

  group('Hallazgos de la revisión R1-C y R2-C', () {
    test(
      'un retirado en riesgo (muchas faltas) no cuenta en atRiskCount y lleva «—» en EstadoAlerta',
      () async {
        final course = _course('c-retirado', 'Cálculo Diferencial');
        await db.insertCourse(course);

        // s0 activo con 100% asistencias
        final s0 = _student(course.id, 0);
        // s1 retirado con 0% asistencias (3 faltas de 3 sesiones)
        final s1 = _student(
          course.id,
          1,
          status: AppConstants.studentStatusRetired,
          retiredAt: '2026-11-15T08:00:00.000-05:00',
        );
        await db.insertStudent(s0);
        await db.insertStudent(s1);

        for (var i = 1; i <= 3; i++) {
          final id = 'ses-r-$i';
          await db.insertSession(SessionModel(
            id: id,
            courseId: course.id,
            startedAt: '2026-11-0${i}T08:00:00.000-05:00',
            closedAt: '2026-11-0${i}T10:00:00.000-05:00',
            roomPin: '1$i',
          ));
          await db.insertAttendanceRecord(_record(id, s0));
        }

        final summary = await excelService.buildCourseSummary(course.id);
        final s1Metric = summary.students.firstWhere((s) => s.studentId == s1.id);

        expect(s1Metric.isRetired, isTrue);
        expect(s1Metric.alertStatus, '—');

        final resumenRows = summary.sheets['Resumen']!;
        final s1Row = resumenRows.firstWhere((r) => r[1] == s1.studentCode);
        // Columna EstadoAlerta es el índice 10
        expect(resumenRows.first[10], 'EstadoAlerta');
        expect(s1Row[10], '—');

        final overview = await service.load(course.id);
        expect(overview.atRiskCount, 0);
      },
    );

    test(
      'la regla «sesión sin acta + enrolledAt»: un estudiante con enrolledAt posterior al inicio '
      'de una sesión sin acta no la tiene como falla',
      () async {
        final course = _course('c-enrolled', 'Física I');
        await db.insertCourse(course);

        // Sesión 1 ocurrió el 2026-11-02 (cerrada sin acta)
        await db.insertSession(const SessionModel(
          id: 'ses-old-sin-acta',
          courseId: 'c-enrolled',
          startedAt: '2026-11-02T08:00:00.000-05:00',
          closedAt: '2026-11-02T10:00:00.000-05:00',
          roomPin: '88',
        ));

        // Estudiante matriculado el 2026-11-05 (después de la sesión)
        final sLate = _student(
          course.id,
          0,
          enrolledAt: '2026-11-05T08:00:00.000-05:00',
        );
        await db.insertStudent(sLate);

        final summary = await excelService.buildCourseSummary(course.id);
        final metric = summary.students.firstWhere((s) => s.studentId == sLate.id);

        expect(metric.totalSessions, 0);
        expect(metric.totalAbsences, 0);
        expect(metric.attendancePercentage, 100.0);

        final detailRows = summary.sheets['Detalle']!;
        final lateRow = detailRows.firstWhere((r) => r[4] == sLate.studentCode);
        // EstadoAsistencia debe ser '—'
        expect(lateRow[6], '—');
      },
    );

    test(
      'retirar a alguien no cambia «presentes de total» de una sesión con acta',
      () async {
        final course = _course('c-acta-totals', 'Algoritmos');
        await db.insertCourse(course);

        // Simulamos un acta firmada con 32 matriculados y 29 presentes
        final actaRecords = <Map<String, dynamic>>[
          for (var i = 0; i < 29; i++)
            {
              'bitIndex': i,
              'studentCode': '01821200${i.toString().padLeft(2, '0')}',
              'fullName': 'Estudiante $i',
              'status': 'PRESENT',
            },
          for (var i = 29; i < 32; i++)
            {
              'bitIndex': i,
              'studentCode': '01821200${i.toString().padLeft(2, '0')}',
              'fullName': 'Estudiante $i',
              'status': 'ABSENT',
            },
        ];

        final actaJson = jsonEncode({
          'sessionId': 'ses-acta-1',
          'courseId': course.id,
          'courseCode': course.code,
          'courseName': course.name,
          'sessionPin': '99',
          'startedAtIso': '2026-11-10T08:00:00.000-05:00',
          'closedAtIso': '2026-11-10T10:00:00.000-05:00',
          'totalEnrolled': 32,
          'presentBleCount': 25,
          'presentManualCount': 4,
          'absentCount': 3,
          'bitmapHex': '0000000000000000',
          'records': actaRecords,
          'actaHmacSignature': _secret,
        });

        await db.insertSession(const SessionModel(
          id: 'ses-acta-1',
          courseId: 'c-acta-totals',
          startedAt: '2026-11-10T08:00:00.000-05:00',
          closedAt: '2026-11-10T10:00:00.000-05:00',
          roomPin: '99',
        ));
        await db.closeSessionWithActa(
          sessionId: 'ses-acta-1',
          closedAt: '2026-11-10T10:00:00.000-05:00',
          bitmapHex: '0000000000000000',
          actaJson: actaJson,
          actaHmacSignature: _secret,
        );

        // En la base de datos actual solo hay 25 estudiantes activos (por retiros)
        for (var i = 0; i < 25; i++) {
          await db.insertStudent(_student(course.id, i));
        }

        final overview = await service.load(course.id);
        expect(overview.recentSessions.length, 1);
        final row = overview.recentSessions.first;

        // Deben mantenerse los valores del acta firmada: 29 de 32
        expect(row.presentCount, 29);
        expect(row.totalStudents, 32);
      },
    );

    test(
      'el promedio ignora a quien tiene 0 sesiones y devuelve null si nadie tiene sesiones',
      () {
        // Estudiante activo con sesiones: 1 de 2 = 50%
        const s1 = StudentAttendanceMetric(
          studentId: 's1',
          bitIndex: 0,
          studentCode: '001',
          fullName: 'S1',
          email: null,
          totalSessions: 2,
          bleAttendances: 1,
          manualAttendances: 0,
          totalAttendances: 1,
          totalAbsences: 1,
          attendancePercentage: 50.0,
          alertStatus: AttendanceAlertStatus.failureByAbsences,
        );

        // Estudiante inscrito tarde: 0 sesiones (default 100%)
        const s2Late = StudentAttendanceMetric(
          studentId: 's2',
          bitIndex: 1,
          studentCode: '002',
          fullName: 'S2 Late',
          email: null,
          totalSessions: 0,
          bleAttendances: 0,
          manualAttendances: 0,
          totalAttendances: 0,
          totalAbsences: 0,
          attendancePercentage: 100.0,
          alertStatus: AttendanceAlertStatus.normal,
        );

        // El promedio no debe promediar con s2Late (que daría (50+100)/2 = 75%).
        // Debe ser 50.0%.
        final avg = CourseOverviewService.averageAttendance([s1, s2Late], 2);
        expect(avg, 50.0);

        // Si solo hay estudiantes con 0 sesiones, devuelve null
        final avgOnlyLate = CourseOverviewService.averageAttendance([s2Late], 2);
        expect(avgOnlyLate, isNull);
      },
    );

    test(
      'exportWithFallback solo usa respaldo ante FileSystemException; '
      'otros errores se relanzan sin reintentar',
      () async {
        // Curso inexistente provoca StateError
        expect(
          () => CourseReportsScreen.exportWithFallback(
            excelService: excelService,
            courseId: 'curso-que-no-existe-en-db',
            primaryDirectoryPath: '/ruta/inexistente/primaria',
            fallbackDirectoryPath: '/ruta/inexistente/fallback',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
