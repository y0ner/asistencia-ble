import 'dart:convert';

import 'package:asistencia_uniguajira/core/constants/app_constants.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/roster_import_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _courseSecret =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

CourseModel _createCourse({String id = 'course-test-1'}) {
  return CourseModel(
    id: id,
    code: 'ING-201',
    name: 'Estructuras de Datos',
    groupCode: '01',
    semester: '2026-2',
    courseSecret: _courseSecret,
    createdAt: '2026-11-19T08:00:00.000-05:00',
  );
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late RosterImportService service;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    service = RosterImportService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
      'CSV con 12345.0, 1,18212E+09, 0182 120016 y ABC123: se importan 12345 y 0182120016, los otros dos cuentan en invalidCodesSkipped',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    const csv = 'codigo;nombre\n'
        '12345.0;Estudiante Uno\n'
        '1,18212E+09;Estudiante Dos\n'
        '0182 120016;Estudiante Tres\n'
        'ABC123;Estudiante Cuatro\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 2);
    expect(result.invalidCodesSkipped, 2);
    expect(result.invalidRowsSkipped, 0);
    expect(
      result.insertedStudents.map((s) => s.studentCode).toList(),
      <String>['12345', '0182120016'],
    );
    expect(
      result.insertedStudents.map((s) => s.fullName).toList(),
      <String>['ESTUDIANTE UNO', 'ESTUDIANTE TRES'],
    );
  });

  test(
      'CSV con una línea de título antes de CODIGO;NOMBRE: importa todos los estudiantes y no crea uno llamado NOMBRE',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    const csv = 'UNIVERSIDAD DE LA GUAJIRA - LISTA DE CLASE 2026-2\n'
        'CODIGO;NOMBRE\n'
        '0182120016;Maria Lopez\n'
        '0182120017;Carlos Gomez\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 2);
    expect(
      result.insertedStudents.map((s) => s.studentCode).toList(),
      <String>['0182120016', '0182120017'],
    );
    expect(
      result.insertedStudents.map((s) => s.fullName).toList(),
      <String>['MARIA LOPEZ', 'CARLOS GOMEZ'],
    );
    expect(
      result.insertedStudents.any((s) => s.fullName.contains('NOMBRE')),
      isFalse,
    );
    expect(
      result.insertedStudents.any((s) => s.fullName.contains('UNIVERSIDAD')),
      isFalse,
    );
  });

  test(
      'CSV N°;Código;Apellidos;Nombres -> el nombre es Nombres Apellidos y el código es el de la columna Código',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    const csv = 'N°;Código;Apellidos;Nombres\n'
        '1;0182120016;Pérez Gómez;María José\n'
        '2;0182110072;Ipuana Pushaina;Carmen Rosa\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 2);
    expect(result.insertedStudents[0].studentCode, '0182120016');
    expect(result.insertedStudents[0].fullName, 'MARIA JOSE PEREZ GOMEZ');
    expect(result.insertedStudents[1].studentCode, '0182110072');
    expect(result.insertedStudents[1].fullName, 'CARMEN ROSA IPUANA PUSHAINA');
  });

  test(
      'decodeCsvBytes(latin1.encode("0123456789;PÉREZ")) contiene PÉREZ',
      () {
    final bytes = latin1.encode('0123456789;PÉREZ');
    final decoded = RosterImportService.decodeCsvBytes(bytes);
    expect(decoded.contains('PÉREZ'), isTrue);
    expect(decoded, '0123456789;PÉREZ');
  });

  test(
      'Texto pegado 0182120016 MARÍA PÉREZ-GÓMEZ -> un estudiante con ese código y nombre completo',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    const text = '0182120016 MARÍA PÉREZ-GÓMEZ';
    final result = await service.importFromClipboardText(course.id, text);

    expect(result.insertedCount, 1);
    expect(result.insertedStudents.single.studentCode, '0182120016');
    expect(result.insertedStudents.single.fullName, 'MARIA PEREZ-GOMEZ');
  });

  test(
      'Dos homónimos con códigos distintos -> se importan los dos',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    const csv = 'codigo,nombre\n'
        '0182120016,Maria Jose Gomez\n'
        '0182120099,Maria Jose Gomez\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 2);
    expect(result.duplicatesSkipped, 0);
    expect(
      result.insertedStudents.map((s) => s.studentCode).toList(),
      <String>['0182120016', '0182120099'],
    );
    expect(result.insertedStudents[0].fullName, 'MARIA JOSE GOMEZ');
    expect(result.insertedStudents[1].fullName, 'MARIA JOSE GOMEZ');

    final dbStudents = await database.getStudentsByCourse(course.id);
    expect(dbStudents, hasLength(2));
  });

  test(
      'XLSX con una celda entera, una con fórmula y una de texto mixto: se comportan como pide el arreglo 2',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Encabezados
    sheet.appendRow(<CellValue>[
      TextCellValue('Código'),
      TextCellValue('Nombre'),
    ]);

    // Fila 1: Celda entera (IntCellValue) y texto
    sheet.appendRow(<CellValue>[
      const IntCellValue(1234567890),
      TextCellValue('Estudiante Entero'),
    ]);

    // Fila 2: Celda con DoubleCellValue entero (p. ej. 9876543210.0)
    sheet.appendRow(<CellValue>[
      const DoubleCellValue(9876543210.0),
      TextCellValue('Estudiante Double Entero'),
    ]);

    // Fila 3: Celda de código con fórmula (FormulaCellValue)
    sheet.appendRow(<CellValue>[
      const FormulaCellValue('=A2'),
      TextCellValue('Estudiante Formula Codigo'),
    ]);

    // Fila 4: Celda de nombre con fórmula (FormulaCellValue)
    sheet.appendRow(<CellValue>[
      const IntCellValue(1122334455),
      const FormulaCellValue('=B2'),
    ]);

    // Fila 5: TextCellValue con TextSpan que tiene children (formato mixto)
    sheet.appendRow(<CellValue>[
      const IntCellValue(5566778899),
      TextCellValue.span(
        const TextSpan(
          children: <TextSpan>[
            TextSpan(text: 'Ana '),
            TextSpan(text: 'María '),
            TextSpan(text: 'Pérez'),
          ],
        ),
      ),
    ]);

    final bytes = excel.encode()!;
    final result = await service.importFromExcelBytes(course.id, bytes);

    expect(result.insertedCount, 3);
    expect(result.formulaCellsSkipped, 2);
    expect(result.invalidCodesSkipped, 1); // Fila 3: fórmula en celda de código
    expect(result.invalidRowsSkipped, 1); // Fila 4: fórmula en celda de nombre
    expect(
      result.insertedStudents.map((s) => s.studentCode).toList(),
      <String>['1234567890', '9876543210', '5566778899'],
    );
    expect(
      result.insertedStudents.map((s) => s.fullName).toList(),
      <String>[
        'ESTUDIANTE ENTERO',
        'ESTUDIANTE DOUBLE ENTERO',
        'ANA MARIA PEREZ',
      ],
    );
  });

  test(
      'Clase con 63 estudiantes + CSV de 3 -> 1 importado y skippedClassFull == 2',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    for (var i = 0; i < 63; i++) {
      await database.insertStudent(
        StudentModel(
          id: 'prev-$i',
          courseId: course.id,
          studentCode: i.toString().padLeft(10, '0'),
          fullName: 'ESTUDIANTE PREVIO $i',
          bitIndex: i,
          personalSecret: 'a' * 64,
          enrolledAt: '2026-11-19T08:00:00.000-05:00',
        ),
      );
    }

    const csv = 'codigo,nombre\n'
        '9990000001,Nuevo Uno\n'
        '9990000002,Nuevo Dos\n'
        '9990000003,Nuevo Tres\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 1);
    expect(result.skippedClassFull, 2);
    expect(result.invalidRowsSkipped, 0);
    expect(result.insertedStudents.single.studentCode, '9990000001');
    expect(result.insertedStudents.single.bitIndex, 63);

    final allStudents = await database.getAllStudentsByCourse(course.id);
    expect(allStudents, hasLength(64));
  });

  test(
      'addManualStudent con 12ab lanza ArgumentError',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    expect(
      () => service.addManualStudent(
        courseId: course.id,
        studentCode: '12ab',
        fullName: 'Juan Perez',
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'El código debe tener solo números, de 4 a 12 dígitos.',
        ),
      ),
    );
  });

  test(
      'El cupo de 64 cuenta a los retirados: clase con 62 activos + 1 retirado + CSV de 3 -> 1 importado y skippedClassFull == 2',
      () async {
    final course = _createCourse();
    await database.insertCourse(course);

    for (var i = 0; i < 62; i++) {
      await database.insertStudent(
        StudentModel(
          id: 'activo-$i',
          courseId: course.id,
          studentCode: i.toString().padLeft(10, '0'),
          fullName: 'ESTUDIANTE ACTIVO $i',
          bitIndex: i,
          personalSecret: 'a' * 64,
          enrolledAt: '2026-11-19T08:00:00.000-05:00',
          status: AppConstants.studentStatusActive,
        ),
      );
    }

    await database.insertStudent(
      StudentModel(
        id: 'retirado-62',
        courseId: course.id,
        studentCode: '0000000062',
        fullName: 'ESTUDIANTE RETIRADO 62',
        bitIndex: 62,
        personalSecret: 'b' * 64,
        enrolledAt: '2026-11-19T08:00:00.000-05:00',
        status: AppConstants.studentStatusRetired,
        retiredAt: '2026-11-19T09:00:00.000-05:00',
      ),
    );

    const csv = 'codigo;nombre\n'
        '9990000001;Nuevo Uno\n'
        '9990000002;Nuevo Dos\n'
        '9990000003;Nuevo Tres\n';

    final result = await service.importFromCsvString(course.id, csv);

    expect(result.insertedCount, 1);
    expect(result.skippedClassFull, 2);
    expect(result.invalidRowsSkipped, 0);
    expect(result.insertedStudents.single.studentCode, '9990000001');
    expect(result.insertedStudents.single.bitIndex, 63);

    final allStudents = await database.getAllStudentsByCourse(course.id);
    expect(allStudents, hasLength(64));
    final activeStudents = await database.getStudentsByCourse(course.id);
    expect(activeStudents, hasLength(63));
  });

  group('Encabezados comunes (R2-D)', () {
    test('Importa 2 estudiantes con encabezado CODIGO;NOMBRES', () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'CODIGO;NOMBRES\n'
          '0182120016;Maria Lopez\n'
          '0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test(
        'Importa 2 estudiantes con encabezado Código;Nombre del estudiante',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'Código;Nombre del estudiante\n'
          '0182120016;Maria Lopez\n'
          '0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test(
        'Importa 2 estudiantes con encabezado Código;Apellidos y nombre',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'Código;Apellidos y nombre\n'
          '0182120016;Lopez Maria\n'
          '0182120017;Gomez Carlos\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'LOPEZ MARIA');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'GOMEZ CARLOS');
    });

    test('Importa 2 estudiantes con encabezado ID;Nombre;Correo', () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'ID;Nombre;Correo\n'
          '0182120016;Maria Lopez;maria@institucion.edu.co\n'
          '0182120017;Carlos Gomez;carlos@institucion.edu.co\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[0].email, 'maria@institucion.edu.co');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
      expect(result.insertedStudents[1].email, 'carlos@institucion.edu.co');
    });

    test('Importa 2 estudiantes con encabezado Codigo;Alumno', () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'Codigo;Alumno\n'
          '0182120016;Maria Lopez\n'
          '0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test(
        'Importa 2 estudiantes con encabezado Código  estudiantil:;Nombre completo',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'Código  estudiantil:;Nombre completo\n'
          '0182120016;Maria Lopez\n'
          '0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test(
        'Fallback nombre: primera columna no código ni correo con texto no numérico en primera fila de datos',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'N°;Código;Titular de la matrícula\n'
          '1;0182120016;Maria Lopez\n'
          '2;0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test(
        'Fallback código: primera columna cuya primera fila de datos sea un código válido',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'Matrícula;Nombre completo\n'
          '0182120016;Maria Lopez\n'
          '0182120017;Carlos Gomez\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'MARIA LOPEZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'CARLOS GOMEZ');
    });

    test('Importa 2 estudiantes con encabezado con solo Apellidos', () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv = 'CODIGO;APELLIDOS\n'
          '0182120016;Lopez Perez\n'
          '0182120017;Gomez Diaz\n';

      final result = await service.importFromCsvString(course.id, csv);

      expect(result.insertedCount, 2);
      expect(result.invalidRowsSkipped, 0);
      expect(result.insertedStudents[0].studentCode, '0182120016');
      expect(result.insertedStudents[0].fullName, 'LOPEZ PEREZ');
      expect(result.insertedStudents[1].studentCode, '0182120017');
      expect(result.insertedStudents[1].fullName, 'GOMEZ DIAZ');
    });

    test(
        'Sinónimos adicionales: codigo alumno, nombre estudiante, nombres completos',
        () async {
      final course = _createCourse();
      await database.insertCourse(course);

      const csv1 = 'codigo alumno;nombre estudiante\n'
          '0182120016;Maria Lopez\n';
      final res1 = await service.importFromCsvString(course.id, csv1);
      expect(res1.insertedCount, 1);
      expect(res1.insertedStudents.single.studentCode, '0182120016');
      expect(res1.insertedStudents.single.fullName, 'MARIA LOPEZ');

      const csv2 = 'codigo;nombres completos\n'
          '0182120017;Carlos Gomez\n';
      final res2 = await service.importFromCsvString(course.id, csv2);
      expect(res2.insertedCount, 1);
      expect(res2.insertedStudents.single.studentCode, '0182120017');
      expect(res2.insertedStudents.single.fullName, 'CARLOS GOMEZ');
    });
  });
}
