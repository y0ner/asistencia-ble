import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_client_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_host_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _secret = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

final _course = CourseModel(
  id: 'curso-bd2',
  code: 'SIST-401',
  name: 'Bases de Datos II',
  groupCode: '01',
  semester: '2026-2',
  courseSecret: _secret,
  createdAt: '2026-11-01T08:00:00.000-05:00',
);

StudentModel _rosterStudent(String code, int bit, {String? name}) => StudentModel(
      id: 'st-$code',
      courseId: _course.id,
      studentCode: code,
      fullName: name ?? 'Estudiante $code',
      bitIndex: bit,
      personalSecret: 'ff' * 32,
      enrolledAt: '2026-11-01T08:00:00.000-05:00',
    );

/// Simulación de entorno BLE que propaga anuncios utilizando el filtro de duplicados
/// real implementado en [BleAttendanceService.debugHandleAdvertisedPacket].
class _FilteringBleAir {
  _FilteringBleAir();

  static const Duration _tick = Duration(milliseconds: 20);
  final List<_FilteringBleNode> _nodes = <_FilteringBleNode>[];
  Timer? _timer;

  _FilteringBleNode node({int rssi = -60, Duration duplicateWindow = const Duration(seconds: 2)}) {
    final ble = _FilteringBleNode(this, rssi, duplicateWindow: duplicateWindow);
    _nodes.add(ble);
    _timer ??= Timer.periodic(_tick, (_) => _deliver());
    return ble;
  }

  void _deliver() {
    for (final sender in _nodes) {
      final packet = sender._current;
      if (packet == null) continue;
      for (final receiver in _nodes) {
        if (identical(receiver, sender) || !receiver.isScanning) continue;
        receiver.debugHandleAdvertisedPacket(packet, sender.rssi);
      }
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    for (final node in _nodes) {
      await node.dispose();
    }
    _nodes.clear();
  }
}

class _FilteringBleNode extends BleAttendanceService {
  _FilteringBleNode(this._air, this.rssi, {super.duplicateWindow});

  // ignore: unused_field
  final _FilteringBleAir _air;
  final int rssi;
  Uint8List? _current;
  bool _scanning = false;

  @override
  bool get isScanning => _scanning;

  @override
  bool get isAdvertising => _current != null;

  @override
  Future<void> startScan({Duration? timeout}) async {
    _scanning = true;
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
  }

  @override
  Future<void> startAdvertisingPacket(Uint8List packet16) async {
    _current = Uint8List.fromList(packet16);
  }

  @override
  Future<void> stopAdvertising() async {
    _current = null;
  }
}

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late _FilteringBleAir air;
  late AppDatabase teacherDb;
  late EnrollmentHostService host;
  late ClassInvite invite;
  final clientDbs = <AppDatabase>[];
  final clients = <EnrollmentClientService>[];
  var dbCount = 0;

  AppDatabase newDb() {
    final db = AppDatabase(factory: databaseFactoryFfi, databasePath: p.join(tmp.path, 'db${dbCount++}.sqlite'));
    return db;
  }

  Future<void> waitUntil(bool Function() condition, {String reason = ''}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('No se cumplió a tiempo: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('inscripcion_espera_');
    air = _FilteringBleAir();
    teacherDb = newDb();
    await teacherDb.insertCourse(_course);
    host = EnrollmentHostService(
      course: _course,
      database: teacherDb,
      bleService: air.node(),
      // Intervalo real del host según brief (600 ms):
      responseInterval: const Duration(milliseconds: 600),
      responseLinger: const Duration(seconds: 3),
    );
    await host.start();
    invite = ClassInvite.parse(await host.buildClassQrPayload());
  });

  tearDown(() async {
    for (final client in clients) {
      await client.cancel();
    }
    clients.clear();
    for (final db in clientDbs) {
      await db.close();
    }
    clientDbs.clear();
    await host.dispose();
    await air.dispose();
    await teacherDb.close();
    tmp.deleteSync(recursive: true);
  });

  test('flujo de inscripción con filtro de duplicados e intervalos reales (400 ms cliente, 600 ms host) para estudiante en lista', () async {
    await teacherDb.insertStudent(_rosterStudent('0182120016', 5, name: 'Yoner Isaza'));

    final phoneDb = newDb();
    clientDbs.add(phoneDb);
    final client = EnrollmentClientService(
      database: phoneDb,
      bleService: air.node(),
      keyStore: MemoryEnrollmentKeyStore(),
      // Intervalo real del cliente según brief (400 ms):
      fragmentInterval: const Duration(milliseconds: 400),
      timeout: const Duration(seconds: 15),
    );
    clients.add(client);

    final stopwatch = Stopwatch()..start();
    final updates = await client.request(
      invite: invite,
      studentCode: '0182120016',
      displayName: 'Yoner',
    ).toList();
    stopwatch.stop();

    // Debe terminar en aceptado en menos de 10 segundos:
    expect(stopwatch.elapsedMilliseconds, lessThan(10000), reason: 'debe completarse en menos de 10 s');
    expect(updates.first.phase, EnrollmentClientPhase.searching);
    expect(updates.last.phase, EnrollmentClientPhase.accepted);

    final enrollment = updates.last.enrollment;
    expect(enrollment, isNotNull);
    expect(enrollment!.bitIndex, 5);
    expect(enrollment.studentCode, '0182120016');

    final stored = await teacherDb.getStudentByCode(courseId: _course.id, studentCode: '0182120016');
    expect(stored!.hasDevice, isTrue);
    expect(stored.personalSecret, enrollment.deviceSecret);
  });

  test('flujo de inscripción con filtro de duplicados e intervalos reales para estudiante fuera de lista aprobado por docente', () async {
    final phoneDb = newDb();
    clientDbs.add(phoneDb);
    final client = EnrollmentClientService(
      database: phoneDb,
      bleService: air.node(),
      keyStore: MemoryEnrollmentKeyStore(),
      // Intervalo real del cliente según brief (400 ms):
      fragmentInterval: const Duration(milliseconds: 400),
      timeout: const Duration(seconds: 15),
    );
    clients.add(client);

    final stopwatch = Stopwatch()..start();
    final updates = <EnrollmentClientUpdate>[];
    final sub = client.request(
      invite: invite,
      studentCode: '0182120099',
      displayName: 'Carlos Pérez',
    ).listen(updates.add);

    // Esperar a que la solicitud en espera llegue al host:
    await waitUntil(() => host.state.pending.isNotEmpty, reason: 'solicitud en espera en el docente');
    expect(host.state.pending.length, 1);
    final reqId = host.state.pending.single.requestId;

    // Esperar a que el host anuncie y el estudiante reciba «pending»:
    await waitUntil(
      () => updates.any((u) => u.phase == EnrollmentClientPhase.pending),
      reason: 'el estudiante debe recibir pending mientras espera',
    );

    // El docente aprueba al estudiante:
    final approved = await host.approve(reqId, fullName: 'Carlos Pérez');
    expect(approved.studentCode, '0182120099');

    // Esperar a que el cliente reciba la aceptación:
    await waitUntil(
      () => updates.any((u) => u.phase == EnrollmentClientPhase.accepted),
      reason: 'el estudiante debe recibir accepted tras la aprobación',
    );
    stopwatch.stop();

    // Debe terminar en aceptado en menos de 10 segundos:
    expect(stopwatch.elapsedMilliseconds, lessThan(10000), reason: 'debe completarse en menos de 10 s');
    final last = updates.lastWhere((u) => u.phase == EnrollmentClientPhase.accepted);
    expect(last.enrollment, isNotNull);
    expect(last.enrollment!.studentCode, '0182120099');
    expect(last.enrollment!.bitIndex, approved.bitIndex);

    await sub.cancel();
  });
}
