import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/course_model.dart';
import '../../core/models/session_model.dart';
import '../local/app_database.dart';
import 'excel_report_service.dart';

/// Una sesión con cuántos estudiantes llegaron.
class SessionAttendanceRow {
  const SessionAttendanceRow({
    required this.session,
    required this.presentCount,
    required this.totalStudents,
  });

  final SessionModel session;

  /// Registros de asistencia de la sesión (Bluetooth y a mano).
  final int presentCount;

  /// Estudiantes de la clase.
  final int totalStudents;

  bool get isOpen => session.closedAt == null;

  /// De 0 a 1. Cero si la clase no tiene estudiantes.
  double get ratio => totalStudents == 0 ? 0 : presentCount / totalStudents;
}

/// Resumen de una clase para las pantallas del docente.
///
/// Es la única fuente de los números que se muestran en Inicio, Clase y
/// Reportes, para que las tres pantallas digan lo mismo.
class CourseOverview {
  const CourseOverview({
    required this.course,
    required this.studentCount,
    required this.boundCount,
    required this.closedSessionCount,
    required this.attendancePercent,
    required this.atRiskCount,
    required this.inAlertCount,
    required this.openSession,
    required this.recentSessions,
  });

  final CourseModel course;

  /// Estudiantes activos de la clase.
  final int studentCount;

  /// Cuántos ya vincularon su celular.
  final int boundCount;

  final int closedSessionCount;

  /// Promedio de asistencia de los estudiantes en sesiones cerradas, de 0 a 100.
  /// Nulo si aún no hay sesiones cerradas o estudiantes.
  final double? attendancePercent;

  /// Estudiantes con pérdida por fallas (mismo criterio que el Excel).
  final int atRiskCount;

  /// Estudiantes en alerta de asistencia (mismo criterio que el Excel).
  final int inAlertCount;

  /// Sesión abierta de la clase, con su conteo, o nula.
  final SessionAttendanceRow? openSession;

  /// Sesiones de la más reciente a la más antigua (máximo [CourseOverviewService.recentLimit]).
  final List<SessionAttendanceRow> recentSessions;

  bool get hasStudents => studentCount > 0;
}

/// Calcula [CourseOverview] a partir de la base de datos local.
class CourseOverviewService {
  CourseOverviewService({AppDatabase? database, ExcelReportService? reportService})
      : _database = database ?? AppDatabase.instance,
        _reportService = reportService ?? ExcelReportService(database: database ?? AppDatabase.instance);

  /// Cuántas sesiones recientes se devuelven.
  static const int recentLimit = 5;

  final AppDatabase _database;
  final ExcelReportService _reportService;

  /// `true` si el estudiante está en riesgo de perder por fallas.
  static bool isAtRisk(StudentAttendanceMetric metric) =>
      metric.isActive &&
      metric.alertStatus == AttendanceAlertStatus.failureByAbsences;

  /// `true` si el estudiante está en alerta (aún no en riesgo).
  static bool isInAlert(StudentAttendanceMetric metric) =>
      metric.isActive &&
      metric.alertStatus == AttendanceAlertStatus.attendanceAlert;

  /// Promedio de asistencia redondeado a una cifra decimal; nulo si no hay datos.
  static double? averageAttendance(List<StudentAttendanceMetric> students, int closedSessions) {
    final withSessions = students.where((s) => s.isActive && s.totalSessions > 0).toList(growable: false);
    if (withSessions.isEmpty || closedSessions == 0) return null;
    final sum = withSessions.fold<double>(0, (acc, s) => acc + s.attendancePercentage);
    return (sum / withSessions.length * 10).roundToDouble() / 10;
  }

  /// Resumen de todas las clases, en el orden de la base de datos.
  Future<List<CourseOverview>> loadAll({DateTime? nowOverride}) async {
    final courses = await _database.getAllCourses();
    final result = <CourseOverview>[];
    for (final course in courses) {
      result.add(await load(course.id, nowOverride: nowOverride));
    }
    return result;
  }

  /// Resumen de una clase.
  Future<CourseOverview> load(String courseId, {DateTime? nowOverride}) async {
    final summary = await _reportService.buildCourseSummary(courseId);
    final activeStudents =
        summary.students.where((s) => s.isActive).toList(growable: false);
    final studentCount = activeStudents.length;
    final activeStudentIds = activeStudents.map((s) => s.studentId).toSet();

    final sessions = List<SessionModel>.of(await _database.getSessionsByCourse(courseId))
      ..sort((a, b) => _startedAt(b).compareTo(_startedAt(a)));

    final rows = <SessionAttendanceRow>[];
    for (final session in sessions) {
      int presentCount;
      int sessionTotalStudents;

      final actaJson = await _database.getSessionActaJson(session.id);
      Map<String, dynamic>? acta;
      if (actaJson != null && actaJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(actaJson);
          if (decoded is Map) {
            acta = <String, dynamic>{
              for (final entry in decoded.entries) entry.key.toString(): entry.value,
            };
          }
        } on FormatException catch (e) {
          debugPrint('Error al decodificar acta de sesión ${session.id}: $e');
        }
      }

      if (acta != null) {
        final totalEnrolled = acta['totalEnrolled'];
        sessionTotalStudents = (totalEnrolled is num) ? totalEnrolled.toInt() : studentCount;
        final recordsList = acta['records'];
        if (recordsList is List) {
          presentCount = recordsList.where((r) {
            if (r is Map) {
              final status = (r['status'] ?? '').toString();
              return status == 'PRESENT';
            }
            return false;
          }).length;
        } else {
          final ble = (acta['presentBleCount'] as num?)?.toInt() ?? 0;
          final manual = (acta['presentManualCount'] as num?)?.toInt() ?? 0;
          presentCount = ble + manual;
        }
      } else {
        final records = await _database.getAttendanceRecordsBySession(session.id);
        presentCount = records
            .where((r) => activeStudentIds.contains(r.studentId))
            .map((r) => r.studentId)
            .toSet()
            .length;
        sessionTotalStudents = studentCount;
      }

      rows.add(SessionAttendanceRow(
        session: session,
        presentCount: presentCount,
        totalStudents: sessionTotalStudents,
      ));
    }

    final now = (nowOverride ?? DateTime.now()).toLocal();
    SessionAttendanceRow? open;
    for (final row in rows) {
      if (row.isOpen) {
        final started = DateTime.tryParse(row.session.startedAt)?.toLocal();
        final isToday = started != null &&
            started.year == now.year &&
            started.month == now.month &&
            started.day == now.day;
        if (isToday) {
          open = row;
          break;
        }
      }
    }

    return CourseOverview(
      course: summary.course,
      studentCount: studentCount,
      boundCount: (await _database.getStudentsByCourse(courseId)).where((s) => s.hasDevice).length,
      closedSessionCount: summary.totalClosedSessions,
      attendancePercent: averageAttendance(summary.students, summary.totalClosedSessions),
      atRiskCount: activeStudents.where(isAtRisk).length,
      inAlertCount: activeStudents.where(isInAlert).length,
      openSession: open,
      recentSessions: rows.take(recentLimit).toList(growable: false),
    );
  }

  static DateTime _startedAt(SessionModel session) =>
      DateTime.tryParse(session.startedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
