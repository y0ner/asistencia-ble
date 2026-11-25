import 'dart:math';

import '../../core/crypto/enrollment_crypto.dart';
import '../../core/models/student_model.dart';
import '../local/app_database.dart';

/// Qué se puede hacer con un estudiante al quitarlo de la clase.
enum StudentRemovalKind {
  /// No tiene asistencias: se borra por completo.
  delete,

  /// Tiene asistencias: se retira y su historial se conserva.
  retire,
}

/// Acciones del docente sobre un estudiante ya registrado.
class StudentAdminService {
  StudentAdminService({AppDatabase? database, Random? random, DateTime Function()? now})
      : _database = database ?? AppDatabase.instance,
        _random = random ?? Random.secure(),
        _now = now ?? DateTime.now;

  final AppDatabase _database;
  final Random _random;
  final DateTime Function() _now;

  /// Si el estudiante tiene asistencias solo se puede retirar; si no, eliminar.
  Future<StudentRemovalKind> removalKindFor(StudentModel student) async {
    final count = await _database.countAttendanceByStudent(student.id);
    return count > 0 ? StudentRemovalKind.retire : StudentRemovalKind.delete;
  }

  Future<int> attendanceCount(StudentModel student) => _database.countAttendanceByStudent(student.id);

  /// La segunda confirmación: lo escrito debe ser el primer nombre del estudiante.
  /// No distingue mayúsculas ni tildes.
  static bool confirmsFirstName(StudentModel student, String typed) {
    final expected = firstNameOf(student);
    return expected.isNotEmpty && _fold(typed) == _fold(expected);
  }

  static String firstNameOf(StudentModel student) {
    final parts = student.fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  /// Elimina o retira según tenga asistencias. Devuelve lo que se hizo.
  Future<StudentRemovalKind> remove(StudentModel student) async {
    final kind = await removalKindFor(student);
    switch (kind) {
      case StudentRemovalKind.delete:
        await _database.deleteStudent(student.id);
      case StudentRemovalKind.retire:
        await _database.retireStudent(
          studentId: student.id,
          retiredAt: _now().toIso8601String(),
          newSecretHex: _newSecret(),
        );
    }
    return kind;
  }

  /// Desvincula el celular: el anterior deja de ser reconocido y el estudiante
  /// puede inscribir otro.
  Future<void> unbindDevice(StudentModel student) {
    return _database.unbindStudentDevice(studentId: student.id, newSecretHex: _newSecret());
  }

  String _newSecret() => EnrollmentCrypto.bytesToHex(List<int>.generate(32, (_) => _random.nextInt(256)));

  static String _fold(String text) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
    const to = 'aaaaaeeeeiiiiooooouuuun';
    final lower = text.trim().toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }
}
