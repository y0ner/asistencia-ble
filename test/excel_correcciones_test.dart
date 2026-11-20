import 'dart:convert';
import 'dart:io';

import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/models/attendance_record_model.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/session_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/course_overview_service.dart';
import 'package:asistencia_uniguajira/data/services/excel_report_service.dart';
import 'package:asistencia_uniguajira/features/teacher/course_reports_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _testCourseSecret =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

String _cellToString(Data? cell) {
  final CellValue? val = cell?.value;
  if (val == null) return '';
  if (val is TextCellValue) return val.value.text ?? '';
  if (val is IntCellValue) return val.value.toString();
  if (val is DoubleCellValue) return val.value.toString();
  if (val is BoolCellValue) return val.value.toString();
  return val.toString();
}

String _fakeSig(String name) => sha256.convert(utf8.encode(name)).toString();

CourseModel _buildCourse({
  String id = 'course-test-1',
  String code = 'SIST-401',
  String name = 'Arquitectura de Software',
  String groupCode = '01',
  String semester = '2026-2',
}) {
  return CourseModel(
    id: id,
    code: code,
    name: name,
    groupCode: groupCode,
    semester: semester,
    courseSecret: _testCourseSecret,
    createdAt: '2026-11-01T08:00:00.000Z',
  );
}

StudentModel _buildStudent({
  required String id,
  required String courseId,
  required String studentCode,
  required String fullName,
  required int bitIndex,
  String status = AppConstants.studentStatusActive,
  String origin = AppConstants.studentOriginRoster,
  String? deviceKeyId,
  String? deviceBoundAt,
  String? retiredAt,
  String? enrolledAt = '2026-11-01T08:00:00.000Z',
}) {
  return StudentModel(
    id: id,
    courseId: courseId,
    studentCode: studentCode,
    fullName: fullName,
    email: '$studentCode@uniguajira.edu.co',
    bitIndex: bitIndex,
    personalSecret: _testCourseSecret,
    enrolledAt: enrolledAt,
    status: status,
    origin: origin,
    deviceKeyId: deviceKeyId,
    deviceBoundAt: deviceBoundAt,
    retiredAt: retiredAt,
  );
}

void main() {
  sqfliteFfiInit();

  group('Pruebas de correcciones de Excel y Reportes (Brief R1-C)', () {
    late AppDatabase database;
    late ExcelReportService excelService;
    late CourseOverviewService overviewService;

    setUp(() {
      database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      excelService = ExcelReportService(
        database: database,
        teacherEmail: 'docente@uniguajira.edu.co',
      );
      overviewService = CourseOverviewService(
        database: database,
        reportService: excelService,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'Criterio 1: Estudiante retirado con asistencias aparece al final en Resumen y no altera promedios ni en riesgo',
      () async {
        final course = _buildCourse();
        await database.insertCourse(course);

        // Estudiantes activos: s0 y s1
        final s0 = _buildStudent(
          id: 's0',
          courseId: course.id,
          studentCode: '0182100010',
          fullName: 'ANDRES PEREZ',
          bitIndex: 0,
        );
        final s1 = _buildStudent(
          id: 's1',
          courseId: course.id,
          studentCode: '0182100020',
          fullName: 'BERTHA GOMEZ',
          bitIndex: 1,
        );
        // Estudiante s2 que fue retirado con fecha 15/11/2026
        final s2 = _buildStudent(
          id: 's2',
          courseId: course.id,
          studentCode: '0182100030',
          fullName: 'CAMILO RETIRADO',
          bitIndex: 2,
          status: AppConstants.studentStatusRetired,
          retiredAt: '2026-11-15T10:00:00.000Z',
        );

        await database.insertStudent(s0);
        await database.insertStudent(s1);
        await database.insertStudent(s2);

        // Sesión 1: Asisten s0 y s2 (s1 falta)
        const sess1Id = 'sess-1';
        await database.upsertSession(const SessionModel(
          id: sess1Id,
          courseId: 'course-test-1',
          roomPin: '11',
          startedAt: '2026-11-10T08:00:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-1-0',
          sessionId: sess1Id,
          studentId: 's0',
          bitIndex: 0,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-10T08:10:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-1-2',
          sessionId: sess1Id,
          studentId: 's2',
          bitIndex: 2,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-10T08:12:00.000Z',
        ));
        await database.closeSessionWithActa(
          sessionId: sess1Id,
          closedAt: '2026-11-10T10:00:00.000Z',
          bitmapHex: '0500000000000000',
          actaJson: jsonEncode(<String, Object?>{
            'sessionId': sess1Id,
            'records': <Map<String, Object?>>[
              {'studentCode': '0182100010', 'status': 'PRESENT'},
              {'studentCode': '0182100020', 'status': 'ABSENT'},
              {'studentCode': '0182100030', 'status': 'PRESENT'},
            ],
          }),
          actaHmacSignature: _fakeSig('sig-$sess1Id'),
        );

        // Sesión 2: Después del retiro de s2. Asisten s0 y s1.
        const sess2Id = 'sess-2';
        await database.upsertSession(const SessionModel(
          id: sess2Id,
          courseId: 'course-test-1',
          roomPin: '22',
          startedAt: '2026-11-16T08:00:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-2-0',
          sessionId: sess2Id,
          studentId: 's0',
          bitIndex: 0,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-16T08:10:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-2-1',
          sessionId: sess2Id,
          studentId: 's1',
          bitIndex: 1,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-16T08:12:00.000Z',
        ));
        await database.closeSessionWithActa(
          sessionId: sess2Id,
          closedAt: '2026-11-16T10:00:00.000Z',
          bitmapHex: '0300000000000000',
          actaJson: jsonEncode(<String, Object?>{
            'sessionId': sess2Id,
            'records': <Map<String, Object?>>[
              {'studentCode': '0182100010', 'status': 'PRESENT'},
              {'studentCode': '0182100020', 'status': 'PRESENT'},
            ],
          }),
          actaHmacSignature: _fakeSig('sig-$sess2Id'),
        );

        final summaryWithRetired = await excelService.buildCourseSummary(course.id);

        // 1. En la lista de métricas, los activos van primero y el retirado al final
        expect(summaryWithRetired.students.length, 3);
        expect(summaryWithRetired.students[0].studentCode, '0182100010');
        expect(summaryWithRetired.students[0].isActive, isTrue);
        expect(summaryWithRetired.students[1].studentCode, '0182100020');
        expect(summaryWithRetired.students[1].isActive, isTrue);
        expect(summaryWithRetired.students[2].studentCode, '0182100030');
        expect(summaryWithRetired.students[2].isRetired, isTrue);

        // 2. Metadatos reflejan activos y retirados por separado
        expect(summaryWithRetired.totalStudents, 2);
        expect(summaryWithRetired.totalRetiredStudents, 1);

        final metaRows = summaryWithRetired.sheets['Metadatos']!;
        final metaMap = <String, String>{
          for (final row in metaRows.skip(1)) row[0].toString(): row[1].toString(),
        };
        expect(metaMap['TotalEstudiantesMatriculados'], '2');
        expect(metaMap['TotalEstudiantesRetirados'], '1');

        // 3. En la hoja Resumen, s2 aparece al final con Estado "Retirado el dd/MM/yyyy"
        final summaryRows = summaryWithRetired.sheets['Resumen']!;
        final s2Row = summaryRows.last;
        expect(s2Row[1], '0182100030');
        expect(s2Row[13].toString(), contains('Retirado el 15/11/2026'));

        // 4. Promedio y "en riesgo" no cambian por la presencia del retirado
        final avgAttendance = CourseOverviewService.averageAttendance(
          summaryWithRetired.students,
          summaryWithRetired.totalClosedSessions,
        );
        final atRiskCount =
            summaryWithRetired.students.where(CourseOverviewService.isAtRisk).length;

        // s0: 2 de 2 = 100%, s1: 1 de 2 = 50% -> promedio = 75.0%
        // s1 tiene 50% inasistencia -> en riesgo (>= 30%). s2 está retirado -> no entra en riesgo
        expect(avgAttendance, 75.0);
        expect(atRiskCount, 1);

        // Si eliminamos a s2 y recalculamos sobre solo activos:
        await database.deleteStudent(s2.id);
        final summaryWithoutRetired = await excelService.buildCourseSummary(course.id);
        final avgWithout = CourseOverviewService.averageAttendance(
          summaryWithoutRetired.students,
          summaryWithoutRetired.totalClosedSessions,
        );
        final atRiskWithout =
            summaryWithoutRetired.students.where(CourseOverviewService.isAtRisk).length;

        expect(avgAttendance, equals(avgWithout));
        expect(atRiskCount, equals(atRiskWithout));
      },
    );

    test(
      'Criterio 2: Columnas «Origen», «Celular vinculado desde» y «Estado» tienen valores esperados para estudiante de lista y agregado en clase',
      () async {
        final course = _buildCourse(id: 'course-criterio-2');
        await database.insertCourse(course);

        // Estudiante de lista sin celular
        final rosterStudent = _buildStudent(
          id: 'roster-1',
          courseId: course.id,
          studentCode: '0182190001',
          fullName: 'ESTUDIANTE LISTA',
          bitIndex: 0,
          origin: AppConstants.studentOriginRoster,
          deviceKeyId: null,
          deviceBoundAt: null,
        );
        // Estudiante agregado en clase con celular vinculado
        final addedInClassStudent = _buildStudent(
          id: 'added-1',
          courseId: course.id,
          studentCode: '0182190002',
          fullName: 'ESTUDIANTE AGREGADO',
          bitIndex: 1,
          origin: AppConstants.studentOriginAddedInClass,
          deviceKeyId: 'dev-key-99',
          deviceBoundAt: '2026-11-05T14:30:00.000Z',
        );

        await database.insertStudent(rosterStudent);
        await database.insertStudent(addedInClassStudent);

        final bytes = await excelService.generateCourseAttendanceWorkbook(course.id);
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables['Resumen']!;

        final headers = sheet.rows[0].map(_cellToString).toList();
        final origenIndex = headers.indexOf('Origen');
        final celularIndex = headers.indexOf('Celular vinculado desde');
        final estadoIndex = headers.indexOf('Estado');

        expect(origenIndex, isNonNegative);
        expect(celularIndex, isNonNegative);
        expect(estadoIndex, isNonNegative);

        // Fila 1: Estudiante de lista sin celular
        final row1 = sheet.rows[1];
        expect(_cellToString(row1[origenIndex]), 'Lista');
        expect(_cellToString(row1[celularIndex]), '');
        expect(_cellToString(row1[estadoIndex]), 'Activo');

        // Fila 2: Estudiante agregado en clase con celular
        final row2 = sheet.rows[2];
        expect(_cellToString(row2[origenIndex]), 'Agregado en clase');
        expect(_cellToString(row2[celularIndex]), '05/11/2026');
        expect(_cellToString(row2[estadoIndex]), 'Activo');
      },
    );

    test(
      'Criterio 3: Estudiante inscrito tarde no recibe fallas de sesiones anteriores y en Detalle van con «—»',
      () async {
        final course = _buildCourse(id: 'course-criterio-3');
        await database.insertCourse(course);

        // Estudiante existente desde el inicio
        final earlyStudent = _buildStudent(
          id: 'early-1',
          courseId: course.id,
          studentCode: '0182100100',
          fullName: 'ALUMNO ANTIGUO',
          bitIndex: 0,
          enrolledAt: '2026-11-01T08:00:00.000Z',
        );
        await database.insertStudent(earlyStudent);

        // Sesión 1 y 2 cerradas antes de que el nuevo se inscriba
        for (var n = 1; n <= 2; n++) {
          final sId = 'old-sess-$n';
          await database.upsertSession(SessionModel(
            id: sId,
            courseId: course.id,
            roomPin: '3$n',
            startedAt: '2026-11-0${n + 1}T08:00:00.000Z',
          ));
          await database.upsertAttendanceRecord(AttendanceRecordModel(
            id: 'rec-old-$n',
            sessionId: sId,
            studentId: earlyStudent.id,
            bitIndex: 0,
            method: AppConstants.attendanceMethodBleHmac,
            recordedAt: '2026-11-0${n + 1}T08:10:00.000Z',
          ));
          await database.closeSessionWithActa(
            sessionId: sId,
            closedAt: '2026-11-0${n + 1}T10:00:00.000Z',
            bitmapHex: '0100000000000000',
            actaJson: jsonEncode(<String, Object?>{
              'sessionId': sId,
              'records': <Map<String, Object?>>[
                {'studentCode': '0182100100', 'status': 'PRESENT'},
              ],
            }),
            actaHmacSignature: _fakeSig('sig-$sId'),
          );
        }

        // Estudiante nuevo se inscribe el 04 de noviembre (después de sesiones 1 y 2)
        final lateStudent = _buildStudent(
          id: 'late-1',
          courseId: course.id,
          studentCode: '0182100200',
          fullName: 'ALUMNO NUEVO',
          bitIndex: 1,
          enrolledAt: '2026-11-04T08:00:00.000Z',
        );
        await database.insertStudent(lateStudent);

        // Sesión 3: Asisten ambos
        const sess3Id = 'sess-new-3';
        await database.upsertSession(const SessionModel(
          id: sess3Id,
          courseId: 'course-criterio-3',
          roomPin: '33',
          startedAt: '2026-11-05T08:00:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-3-0',
          sessionId: sess3Id,
          studentId: 'early-1',
          bitIndex: 0,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-05T08:10:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-3-1',
          sessionId: sess3Id,
          studentId: 'late-1',
          bitIndex: 1,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-05T08:12:00.000Z',
        ));
        await database.closeSessionWithActa(
          sessionId: sess3Id,
          closedAt: '2026-11-05T10:00:00.000Z',
          bitmapHex: '0300000000000000',
          actaJson: jsonEncode(<String, Object?>{
            'sessionId': sess3Id,
            'records': <Map<String, Object?>>[
              {'studentCode': '0182100100', 'status': 'PRESENT'},
              {'studentCode': '0182100200', 'status': 'PRESENT'},
            ],
          }),
          actaHmacSignature: _fakeSig('sig-$sess3Id'),
        );

        final summary = await excelService.buildCourseSummary(course.id);
        final lateMetric =
            summary.students.firstWhere((m) => m.studentCode == '0182100200');

        // Tiene 100 % y 0 inasistencias en sus sesiones
        expect(lateMetric.totalSessions, 1);
        expect(lateMetric.totalAttendances, 1);
        expect(lateMetric.totalAbsences, 0);
        expect(lateMetric.attendancePercentage, 100.0);
        expect(lateMetric.alertStatus, AttendanceAlertStatus.normal);

        // En la hoja Detalle, las dos primeras sesiones van con «—»
        final detailRows = summary.sheets['Detalle']!;
        final lateDetailRows = detailRows.where((r) => r[4] == '0182100200').toList();
        expect(lateDetailRows.length, 3);
        expect(lateDetailRows[0][6], '—'); // Sesión 1
        expect(lateDetailRows[1][6], '—'); // Sesión 2
        expect(lateDetailRows[2][6], AppConstants.attendanceStatusPresent); // Sesión 3
      },
    );

    test(
      'Criterio 4: CourseOverviewService: con un retirado que tenía asistencia en la última sesión, presentCount <= totalStudents',
      () async {
        final course = _buildCourse(id: 'course-criterio-4');
        await database.insertCourse(course);

        // 1 estudiante activo
        final activeStudent = _buildStudent(
          id: 'active-1',
          courseId: course.id,
          studentCode: '0182100501',
          fullName: 'ACTIVO UNICO',
          bitIndex: 0,
        );
        // 1 estudiante retirado que asistió a la sesión
        final retiredStudent = _buildStudent(
          id: 'retired-1',
          courseId: course.id,
          studentCode: '0182100502',
          fullName: 'RETIRADO ASISTIO',
          bitIndex: 1,
          status: AppConstants.studentStatusRetired,
          retiredAt: '2026-11-10T12:00:00.000Z',
        );

        await database.insertStudent(activeStudent);
        await database.insertStudent(retiredStudent);

        const sessId = 'sess-overview';
        await database.upsertSession(const SessionModel(
          id: sessId,
          courseId: 'course-criterio-4',
          roomPin: '88',
          startedAt: '2026-11-09T08:00:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-act',
          sessionId: sessId,
          studentId: 'active-1',
          bitIndex: 0,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-09T08:10:00.000Z',
        ));
        await database.upsertAttendanceRecord(const AttendanceRecordModel(
          id: 'rec-ret',
          sessionId: sessId,
          studentId: 'retired-1',
          bitIndex: 1,
          method: AppConstants.attendanceMethodBleHmac,
          recordedAt: '2026-11-09T08:15:00.000Z',
        ));
        await database.closeSession(
          sessionId: sessId,
          closedAt: '2026-11-09T10:00:00.000Z',
        );

        final overview = await overviewService.load(course.id);
        expect(overview.studentCount, 1);
        expect(overview.recentSessions.length, 1);
        final row = overview.recentSessions.first;
        expect(row.presentCount, 1);
        expect(row.totalStudents, 1);
        expect(row.presentCount <= row.totalStudents, isTrue);
      },
    );

    test(
      'Criterio 5: exportFileNameFor genera nombres distintos para clases con igual código y grupo pero distinto semestre o id',
      () {
        final c1 = _buildCourse(
          id: 'c-uuid-111111',
          code: 'SIST-401',
          groupCode: '01',
          semester: '2026-1',
        );
        final c2 = _buildCourse(
          id: 'c-uuid-111111',
          code: 'SIST-401',
          groupCode: '01',
          semester: '2026-2',
        );
        final c3 = _buildCourse(
          id: 'c3diff-222222',
          code: 'SIST-401',
          groupCode: '01',
          semester: '2026-1',
        );

        final name1 = ExcelReportService.exportFileNameFor(c1);
        final name2 = ExcelReportService.exportFileNameFor(c2);
        final name3 = ExcelReportService.exportFileNameFor(c3);

        expect(name1, isNot(equals(name2)));
        expect(name1, isNot(equals(name3)));
        expect(name2, isNot(equals(name3)));

        expect(name1, 'Asistencia_Uniguajira_SIST-401_01_2026-1_c-uuid.xlsx');
        expect(name2, 'Asistencia_Uniguajira_SIST-401_01_2026-2_c-uuid.xlsx');
        expect(name3, 'Asistencia_Uniguajira_SIST-401_01_2026-1_c3diff.xlsx');
        // Distinto prefijo de 6 caracteres del id
        final c4 = _buildCourse(
          id: 'abcde123',
          code: 'SIST-401',
          groupCode: '01',
          semester: '2026-1',
        );
        final name4 = ExcelReportService.exportFileNameFor(c4);
        expect(name4, 'Asistencia_Uniguajira_SIST-401_01_2026-1_abcde1.xlsx');
        expect(name4, isNot(equals(name1)));
      },
    );

    test(
      'Criterio 6: exportWorkbookToFile lanza ante directorio no escribible y CourseReportsScreen usa el respaldo',
      () async {
        final course = _buildCourse(id: 'course-criterio-6');
        await database.insertCourse(course);
        await database.insertStudent(_buildStudent(
          id: 's-crit-6',
          courseId: course.id,
          studentCode: '0182100999',
          fullName: 'ESTUDIANTE RESALTO',
          bitIndex: 0,
        ));

        // Directorio no escribible lanza
        expect(
          () => excelService.exportWorkbookToFile(
            courseId: course.id,
            directoryPath: '/proc/invalid_unwritable_path',
          ),
          throwsA(isA<FileSystemException>()),
        );

        final tempFallbackDir = Directory.systemTemp.createTempSync('backup_reports_');
        try {
          // CourseReportsScreen.exportWithFallback utiliza el directorio de respaldo si el principal falla
          final filePath = await CourseReportsScreen.exportWithFallback(
            excelService: excelService,
            courseId: course.id,
            primaryDirectoryPath: '/proc/invalid_unwritable_path',
            fallbackDirectoryPath: tempFallbackDir.path,
          );

          expect(filePath, startsWith(tempFallbackDir.path));
          final exportedFile = File(filePath);
          expect(exportedFile.existsSync(), isTrue);
          expect(exportedFile.lengthSync(), greaterThan(0));

          // resolveLatestExportedFile selecciona el archivo más reciente entre las carpetas
          final tempPrimaryDir = Directory.systemTemp.createTempSync('primary_reports_');
          try {
            final fileName = ExcelReportService.exportFileNameFor(course);
            final olderFile = File('${tempPrimaryDir.path}/$fileName');
            await olderFile.writeAsString('antiguo');
            await olderFile.setLastModified(
              DateTime.now().subtract(const Duration(minutes: 5)),
            );

            // Aseguramos que el archivo en el fallback sea más reciente
            final newerFile = File('${tempFallbackDir.path}/$fileName');
            await newerFile.writeAsString('nuevo');
            await newerFile.setLastModified(DateTime.now());

            final latest = await CourseReportsScreen.resolveLatestExportedFile(
              course: course,
              directoriesToCheck: [tempPrimaryDir.path, tempFallbackDir.path],
            );
            expect(latest?.path, newerFile.path);
          } finally {
            tempPrimaryDir.deleteSync(recursive: true);
          }
        } finally {
          tempFallbackDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'Sin sesiones cerradas, CourseOverviewService.averageAttendance es nulo y la pantalla muestra «—»',
      () async {
        final course = _buildCourse(id: 'course-sin-sesiones');
        await database.insertCourse(course);
        await database.insertStudent(_buildStudent(
          id: 's-single',
          courseId: course.id,
          studentCode: '0182100888',
          fullName: 'ESTUDIANTE UNICO',
          bitIndex: 0,
        ));

        final summary = await excelService.buildCourseSummary(course.id);
        final avgAttendance = CourseOverviewService.averageAttendance(
          summary.students,
          summary.totalClosedSessions,
        );

        expect(summary.totalClosedSessions, 0);
        expect(avgAttendance, isNull);
      },
    );
  });
}
