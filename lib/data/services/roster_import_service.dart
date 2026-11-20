import 'dart:convert';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/crypto/enrollment_packet_codec.dart';
import '../../core/models/course_model.dart';
import '../../core/models/student_model.dart';
import '../local/app_database.dart';

/// Resumen de una importación masiva de estudiantes a un curso.
class RosterImportResult {
  const RosterImportResult({
    required this.insertedCount,
    required this.duplicatesSkipped,
    required this.invalidRowsSkipped,
    this.invalidCodesSkipped = 0,
    this.formulaCellsSkipped = 0,
    this.skippedClassFull = 0,
    required this.insertedStudents,
  });

  /// Cantidad de estudiantes efectivamente persistidos.
  final int insertedCount;

  /// Filas descartadas por repetir código dentro del lote o del curso.
  final int duplicatesSkipped;

  /// Filas descartadas por datos incompletos.
  final int invalidRowsSkipped;

  /// Filas descartadas por código estudiantil no válido o con notación científica.
  final int invalidCodesSkipped;

  /// Filas descartadas por contener fórmulas en celdas de código o nombre.
  final int formulaCellsSkipped;

  /// Filas descartadas por haber alcanzado el límite de 64 estudiantes del curso.
  final int skippedClassFull;

  /// Estudiantes persistidos, en el mismo orden en que fueron asignados.
  final List<StudentModel> insertedStudents;
}

/// Motor de ingesta de cursos y estudiantes sin dependencia del SMA.
///
/// Acepta tres vías de entrada (CSV, Excel y texto pegado), además del alta
/// manual, y aplica las reglas de normalización, deduplicación y capacidad del
/// Bitmap de 64 posiciones.
class RosterImportService {
  RosterImportService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  static const Set<String> _codeHeaders = <String>{
    'codigo',
    'cod',
    'codigo estudiantil',
    'codigo estudiante',
    'codigo del estudiante',
  };
  static const Set<String> _fullNameHeaders = <String>{
    'nombre completo',
    'nombres y apellidos',
    'apellidos y nombres',
    'estudiante',
  };
  static const Set<String> _lastNameHeaders = <String>{
    'apellidos',
    'apellido',
  };
  static const Set<String> _firstNameHeaders = <String>{
    'nombres',
  };
  static const Set<String> _emailHeaders = <String>{
    'correo',
    'email',
    'correo electronico',
    'correo institucional',
  };

  /// Decodifica los bytes de un archivo CSV intentando UTF-8 estricto
  /// y recurriendo a Latin-1 (ISO-8859-1) si lanza [FormatException]
  /// (común en archivos exportados por Excel en Windows).
  static String decodeCsvBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// Normaliza el código del estudiante:
  /// - Quita espacios en los extremos y espacios internos («0182 120016» → «0182120016»).
  /// - Si es un número con decimales en cero («12345.0», «12345,00»), quita los decimales.
  static String normalizeStudentCode(String rawCode) {
    var code = rawCode.replaceAll(RegExp(r'\s+'), '');
    code = code.replaceAll(RegExp(r'[\.,]0+$'), '');
    return code;
  }

  /// Importa estudiantes desde el contenido literal de un archivo CSV.
  ///
  /// La fila de encabezados se detecta y se ignora, y los códigos se conservan
  /// como texto para no perder los ceros a la izquierda.
  Future<RosterImportResult> importFromCsvString(
    String courseId,
    String csvContent,
  ) async {
    return _importRows(courseId, _parseCsvRows(csvContent));
  }

  /// Importa estudiantes desde los bytes de un libro de Excel (`.xlsx`).
  Future<RosterImportResult> importFromExcelBytes(
    String courseId,
    List<int> bytes,
  ) async {
    return _importRows(courseId, _parseExcelRows(bytes));
  }

  /// Importa estudiantes desde texto pegado con columnas separadas por
  /// tabulador, punto y coma, coma o guion.
  Future<RosterImportResult> importFromClipboardText(
    String courseId,
    String rawText,
  ) async {
    return _importRows(courseId, _parseClipboardRows(rawText));
  }

  /// Da de alta un estudiante individual en el siguiente Bitmap libre.
  ///
  /// Valida el código, rechaza códigos ya registrados y aplica el límite de 64 cupos.
  Future<StudentModel> addManualStudent({
    required String courseId,
    required String studentCode,
    required String fullName,
    String? email,
  }) async {
    final course = await _database.getCourseById(courseId);
    if (course == null) {
      throw ArgumentError.value(
        courseId,
        'courseId',
        'El curso no existe.',
      );
    }

    final code = normalizeStudentCode(studentCode);
    final name = _normalizeFullName(fullName);
    if (!EnrollmentPacketCodec.isValidStudentCode(code)) {
      throw ArgumentError(
        'El código debe tener solo números, de 4 a 12 dígitos.',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        fullName,
        'fullName',
        'El nombre del estudiante no puede estar vacío.',
      );
    }

    final existing = await _database.getAllStudentsByCourse(courseId);
    if (existing.length >= AppConstants.bitmapBitCount) {
      throw StateError(
        'El curso $courseId ya ocupó las '
        '${AppConstants.bitmapBitCount} posiciones del Bitmap.',
      );
    }
    final existingCodes = existing
        .map((StudentModel student) => student.studentCode.trim())
        .toSet();
    if (existingCodes.contains(code)) {
      throw StateError('El código $code ya está registrado en el curso.');
    }

    final usedBits =
        existing.map((StudentModel student) => student.bitIndex).toSet();
    final student = StudentModel(
      id: _uuid.v4(),
      courseId: courseId,
      studentCode: code,
      fullName: name,
      email: _normalizeEmail(email),
      bitIndex: _firstFreeBit(usedBits),
      personalSecret: _generateSecret(),
      enrolledAt: _nowIso(),
    );
    await _database.insertStudent(student);
    return student;
  }

  /// Genera el JSON compacto que el teléfono del estudiante escanea una sola vez.
  ///
  /// [deviceSecret] es el secreto personal persistido para ese estudiante y
  /// [sharedSecret] es el secreto del curso con el que se verifica el HMAC.
  String generateEnrollmentQrPayload({
    required CourseModel course,
    required StudentModel student,
  }) {
    if (student.courseId != course.id) {
      throw ArgumentError.value(
        student.courseId,
        'student',
        'El estudiante no pertenece al curso indicado.',
      );
    }
    return jsonEncode(<String, Object?>{
      'courseId': course.id,
      'courseCode': course.code,
      'courseName': course.name,
      'studentId': student.id,
      'studentCode': student.studentCode,
      'fullName': student.fullName,
      'bitmapIndex': student.bitIndex,
      'deviceSecret': student.personalSecret,
      'sharedSecret': course.courseSecret,
    });
  }

  // ---------------------------------------------------------------------------
  // Ingesta y reglas de negocio
  // ---------------------------------------------------------------------------

  Future<RosterImportResult> _importRows(
    String courseId,
    List<List<_RawCell>> rawRows,
  ) async {
    final course = await _database.getCourseById(courseId);
    if (course == null) {
      throw ArgumentError.value(
        courseId,
        'courseId',
        'El curso no existe.',
      );
    }

    final existing = await _database.getAllStudentsByCourse(courseId);
    final existingCodes = existing
        .map((StudentModel student) => student.studentCode.trim())
        .toSet();
    final usedBits =
        existing.map((StudentModel student) => student.bitIndex).toSet();

    final batchCodes = <String>{};
    final inserted = <StudentModel>[];
    var duplicatesSkipped = 0;
    var invalidRowsSkipped = 0;
    var invalidCodesSkipped = 0;
    var formulaCellsSkipped = 0;
    var skippedClassFull = 0;

    for (final _ParsedRow row in _mapRows(rawRows)) {
      if (row.isCodeFormula) {
        formulaCellsSkipped++;
        invalidCodesSkipped++;
        if (row.isNameFormula) {
          formulaCellsSkipped++;
        }
        continue;
      }
      if (row.isNameFormula) {
        formulaCellsSkipped++;
        invalidRowsSkipped++;
        continue;
      }

      final rawCode = row.code.trim();
      final rawName = row.name.trim();
      if (rawCode.isEmpty || rawName.isEmpty) {
        invalidRowsSkipped++;
        continue;
      }

      final code = normalizeStudentCode(rawCode);
      final name = _normalizeFullName(rawName);

      if (rawCode.contains(RegExp(r'[eE]')) ||
          !EnrollmentPacketCodec.isValidStudentCode(code)) {
        invalidCodesSkipped++;
        continue;
      }

      final repeated =
          batchCodes.contains(code) || existingCodes.contains(code);
      if (repeated) {
        duplicatesSkipped++;
        continue;
      }

      if (existing.length + inserted.length >=
          AppConstants.bitmapBitCount) {
        skippedClassFull++;
        continue;
      }

      final student = StudentModel(
        id: _uuid.v4(),
        courseId: courseId,
        studentCode: code,
        fullName: name,
        email: _normalizeEmail(row.email),
        bitIndex: _firstFreeBit(usedBits),
        personalSecret: _generateSecret(),
        enrolledAt: _nowIso(),
      );
      await _database.insertStudent(student);

      usedBits.add(student.bitIndex);
      batchCodes.add(code);
      inserted.add(student);
    }

    return RosterImportResult(
      insertedCount: inserted.length,
      duplicatesSkipped: duplicatesSkipped,
      invalidRowsSkipped: invalidRowsSkipped,
      invalidCodesSkipped: invalidCodesSkipped,
      formulaCellsSkipped: formulaCellsSkipped,
      skippedClassFull: skippedClassFull,
      insertedStudents: List<StudentModel>.unmodifiable(inserted),
    );
  }

  List<_ParsedRow> _mapRows(List<List<_RawCell>> rows) {
    if (rows.isEmpty) {
      return const <_ParsedRow>[];
    }

    var headerRowIndex = -1;
    _HeaderInfo? header;

    // Busca el encabezado en las primeras 5 filas no vacías
    var nonEmptyCount = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((_RawCell cell) => cell.text.trim().isEmpty && !cell.isFormula)) {
        continue;
      }
      nonEmptyCount++;
      final candidate = _headerMapping(row);
      if (candidate != null) {
        headerRowIndex = i;
        header = candidate;
        break;
      }
      if (nonEmptyCount >= 5) {
        break;
      }
    }

    final start = headerRowIndex >= 0 ? headerRowIndex + 1 : 0;
    final parsed = <_ParsedRow>[];
    for (var i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((_RawCell cell) => cell.text.trim().isEmpty && !cell.isFormula)) {
        continue;
      }

      String codeText = '';
      var isCodeFormula = false;
      String nameText = '';
      var isNameFormula = false;
      String? emailText;

      if (header != null) {
        if (header.codeIndex != null) {
          final codeCell = _rawCellAt(row, header.codeIndex!);
          codeText = codeCell.text;
          isCodeFormula = codeCell.isFormula;
        }
        if (header.fullNameIndex != null) {
          final nameCell = _rawCellAt(row, header.fullNameIndex!);
          nameText = nameCell.text;
          isNameFormula = nameCell.isFormula;
        } else if (header.firstNameIndex != null && header.lastNameIndex != null) {
          final firstCell = _rawCellAt(row, header.firstNameIndex!);
          final lastCell = _rawCellAt(row, header.lastNameIndex!);
          nameText = '${firstCell.text.trim()} ${lastCell.text.trim()}'.trim();
          isNameFormula = firstCell.isFormula || lastCell.isFormula;
        }
        if (header.emailIndex != null) {
          emailText = _rawCellAt(row, header.emailIndex!).text;
        }
      } else {
        final codeCell = _rawCellAt(row, 0);
        codeText = codeCell.text;
        isCodeFormula = codeCell.isFormula;

        final nameCell = _rawCellAt(row, 1);
        nameText = nameCell.text;
        isNameFormula = nameCell.isFormula;

        emailText = _rawCellAt(row, 2).text;
      }

      parsed.add(
        _ParsedRow(
          code: codeText,
          name: nameText,
          email: emailText,
          isCodeFormula: isCodeFormula,
          isNameFormula: isNameFormula,
        ),
      );
    }
    return parsed;
  }

  _HeaderInfo? _headerMapping(List<_RawCell> row) {
    var hasLastName = false;
    for (final cell in row) {
      final token = _normalizeHeaderToken(cell.text);
      if (_lastNameHeaders.contains(token)) {
        hasLastName = true;
        break;
      }
    }

    int? codeIndex;
    int? fullNameIndex;
    int? lastNameIndex;
    int? firstNameIndex;
    int? emailIndex;

    for (var i = 0; i < row.length; i++) {
      final token = _normalizeHeaderToken(row[i].text);
      if (_codeHeaders.contains(token)) {
        codeIndex ??= i;
      } else if (_emailHeaders.contains(token)) {
        emailIndex ??= i;
      } else if (_fullNameHeaders.contains(token)) {
        fullNameIndex ??= i;
      } else if (_lastNameHeaders.contains(token)) {
        lastNameIndex ??= i;
      } else if (_firstNameHeaders.contains(token)) {
        firstNameIndex ??= i;
      } else if (token == 'nombre') {
        if (hasLastName) {
          firstNameIndex ??= i;
        } else {
          fullNameIndex ??= i;
        }
      }
    }

    final hasRecognizedColumns = codeIndex != null ||
        fullNameIndex != null ||
        (firstNameIndex != null && lastNameIndex != null);

    if (!hasRecognizedColumns) {
      return null;
    }

    final codePosition = codeIndex;
    if (codePosition != null &&
        RegExp(r'^\d{4,}$').hasMatch(row[codePosition].text.trim())) {
      return null;
    }
    return _HeaderInfo(
      codeIndex: codeIndex,
      fullNameIndex: fullNameIndex,
      lastNameIndex: lastNameIndex,
      firstNameIndex: firstNameIndex,
      emailIndex: emailIndex,
    );
  }

  List<List<_RawCell>> _parseCsvRows(String content) {
    final normalized = _normalizeNewlines(_stripBom(content)).trim();
    if (normalized.isEmpty) {
      return const <List<_RawCell>>[];
    }
    final rawDelimited = _parseDelimitedRows(
      normalized,
      _detectCsvDelimiter(normalized),
    );
    return rawDelimited
        .map(
          (List<String> row) => row
              .map((String cell) => _RawCell(cell.trim()))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  List<List<String>> _parseDelimitedRows(String content, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }
      if (char == '"') {
        inQuotes = true;
      } else if (char == delimiter) {
        row.add(field.toString().trim());
        field = StringBuffer();
      } else if (char == '\n') {
        row.add(field.toString().trim());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString().trim());
      rows.add(row);
    }
    return rows;
  }

  List<List<_RawCell>> _parseExcelRows(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    for (final String tableName in workbook.tables.keys) {
      final sheet = workbook.tables[tableName];
      if (sheet == null) {
        continue;
      }
      final rows = sheet.rows
          .map(
            (List<Data?> row) => row
                .map((Data? cell) => _rawCellFromExcel(cell))
                .toList(growable: false),
          )
          .toList(growable: false);
      final hasData = rows.any(
        (List<_RawCell> row) =>
            row.any((_RawCell cell) => cell.text.isNotEmpty || cell.isFormula),
      );
      if (hasData) {
        return rows;
      }
    }
    throw ArgumentError.value(
      bytes,
      'bytes',
      'El archivo Excel no contiene filas con datos.',
    );
  }

  List<List<_RawCell>> _parseClipboardRows(String rawText) {
    final normalized = _normalizeNewlines(_stripBom(rawText));
    final rows = <List<_RawCell>>[];
    for (final String line in normalized.split('\n')) {
      if (line.trim().isEmpty) {
        continue;
      }
      final parts = _splitClipboardLine(line);
      rows.add(
        parts
            .map((String p) => _RawCell(p.trim()))
            .toList(growable: false),
      );
    }
    return rows;
  }

  List<String> _splitClipboardLine(String line) {
    for (final String delimiter in <String>['\t', ';', ',']) {
      if (line.contains(delimiter)) {
        return line.split(delimiter);
      }
    }
    final spacedHyphen = RegExp(r'\s+-\s+').firstMatch(line);
    if (spacedHyphen != null) {
      return line.split(RegExp(r'\s+-\s+'));
    }
    // «0182120097-Juan Pérez»: un guion pegado a los dígitos del código separa
    // sin ambigüedad (el código solo tiene números).
    final codeHyphen = RegExp(r'^(\d{4,12})-(.+)$').firstMatch(line.trim());
    if (codeHyphen != null) {
      return <String>[codeHyphen.group(1)!, codeHyphen.group(2)!];
    }
    final match = RegExp(r'^(\d{4,12})\s+(.+?)(?:\s+(\S+@\S+))?$')
        .firstMatch(line.trim());
    if (match != null) {
      final code = match.group(1)!;
      final name = match.group(2)!;
      final email = match.group(3);
      if (email != null && email.isNotEmpty) {
        return <String>[code, name, email];
      }
      return <String>[code, name];
    }
    return <String>[line];
  }

  static _RawCell _rawCellFromExcel(Data? cell) {
    final CellValue? value = cell?.value;
    if (value == null) {
      return const _RawCell('');
    }
    if (value is FormulaCellValue) {
      return const _RawCell('', isFormula: true);
    }
    if (value is TextCellValue) {
      return _RawCell(_extractTextSpan(value.value).trim());
    }
    if (value is IntCellValue) {
      return _RawCell(value.value.toString());
    }
    if (value is DoubleCellValue) {
      final double val = value.value;
      if (val == val.toInt().toDouble()) {
        return _RawCell(val.toInt().toString());
      }
      return _RawCell(val.toString());
    }
    if (value is BoolCellValue) {
      return _RawCell(value.value.toString());
    }
    return _RawCell(value.toString().trim());
  }

  static String _extractTextSpan(TextSpan span) {
    final buffer = StringBuffer();
    if (span.text != null && span.text!.isNotEmpty) {
      buffer.write(span.text);
    }
    if (span.children != null) {
      for (final child in span.children!) {
        buffer.write(_extractTextSpan(child));
      }
    }
    return buffer.toString();
  }

  static String _detectCsvDelimiter(String content) {
    final lines = content
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .take(5)
        .toList();
    if (lines.isEmpty) {
      return ',';
    }
    final candidates = <String>[';', ',', '\t'];
    var best = ',';
    var bestCount = 0;
    for (final String candidate in candidates) {
      var count = 0;
      for (final String line in lines) {
        count += candidate.allMatches(line).length;
      }
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  static String _normalizeNewlines(String content) {
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static String _stripBom(String content) {
    return content.startsWith('\uFEFF') ? content.substring(1) : content;
  }

  static _RawCell _rawCellAt(List<_RawCell> row, int index) {
    return index >= 0 && index < row.length ? row[index] : const _RawCell('');
  }

  static String _normalizeHeaderToken(String value) {
    return _stripAccents(value).trim().toLowerCase().replaceAll(':', '');
  }

  static String _normalizeFullName(String value) {
    return _stripAccents(value)
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _normalizeEmail(String? email) {
    final value = email?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static String _stripAccents(String value) {
    var result = value;
    _accentMap.forEach((String from, String to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  static int _firstFreeBit(Set<int> usedBits) {
    for (var bit = 0; bit < AppConstants.bitmapBitCount; bit++) {
      if (!usedBits.contains(bit)) {
        return bit;
      }
    }
    throw StateError(
      'El curso ya ocupó las ${AppConstants.bitmapBitCount} '
      'posiciones del Bitmap.',
    );
  }

  static String _generateSecret() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  static const Map<String, String> _accentMap = <String, String>{
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'á': 'A',
    'é': 'E',
    'í': 'I',
    'ó': 'O',
    'ú': 'U',
    'ü': 'U',
    'À': 'A',
    'È': 'E',
    'Ì': 'I',
    'Ò': 'O',
    'Ù': 'U',
    'à': 'A',
    'è': 'E',
    'ì': 'I',
    'ò': 'O',
    'ù': 'U',
  };
}

class _RawCell {
  const _RawCell(this.text, {this.isFormula = false});
  final String text;
  final bool isFormula;
}

class _HeaderInfo {
  const _HeaderInfo({
    this.codeIndex,
    this.fullNameIndex,
    this.lastNameIndex,
    this.firstNameIndex,
    this.emailIndex,
  });

  final int? codeIndex;
  final int? fullNameIndex;
  final int? lastNameIndex;
  final int? firstNameIndex;
  final int? emailIndex;

  bool get hasName =>
      fullNameIndex != null ||
      (firstNameIndex != null && lastNameIndex != null);
}

/// Fila cruda ya mapeada a las tres columnas del roster.
class _ParsedRow {
  const _ParsedRow({
    required this.code,
    required this.name,
    this.email,
    this.isCodeFormula = false,
    this.isNameFormula = false,
  });

  final String code;
  final String name;
  final String? email;
  final bool isCodeFormula;
  final bool isNameFormula;
}
