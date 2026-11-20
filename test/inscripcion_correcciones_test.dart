import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:asistencia_uniguajira/core/crypto/enrollment_crypto.dart';
import 'package:asistencia_uniguajira/core/crypto/enrollment_packet_codec.dart';
import 'package:asistencia_uniguajira/core/models/course_model.dart';
import 'package:asistencia_uniguajira/core/models/student_enrollment_model.dart';
import 'package:asistencia_uniguajira/core/models/student_model.dart';
import 'package:asistencia_uniguajira/data/local/app_database.dart';
import 'package:asistencia_uniguajira/data/services/ble_attendance_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_client_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_host_service.dart';
import 'package:asistencia_uniguajira/data/services/enrollment_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_ble_air.dart';

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

class _Phone {
  _Phone(this.db, this.ble, {EnrollmentKeyStore? keyStore}) {
    client = EnrollmentClientService(
      database: db,
      bleService: ble,
      keyStore: keyStore,
      fragmentInterval: const Duration(milliseconds: 8),
      timeout: const Duration(milliseconds: 900),
    );
  }

  final AppDatabase db;
  final AirBle ble;
  late final EnrollmentClientService client;

  Future<List<EnrollmentClientUpdate>> join(ClassInvite invite, String code, {String name = 'Yo'}) {
    return client.request(invite: invite, studentCode: code, displayName: name).toList();
  }
}

class _FailingBle extends BleAttendanceService {
  _FailingBle({this.shouldThrowScan = false});

  final bool shouldThrowScan;

  @override
  Future<void> startScan({Duration? timeout}) async {
    if (shouldThrowScan) throw Exception('Fallo BLE al iniciar escaneo');
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> startAdvertisingPacket(List<int> packet16) async {}

  @override
  Future<void> stopAdvertising() async {}
}

class _FailingDatabase extends Fake implements AppDatabase {
  @override
  Future<int> upsertStudentEnrollment(StudentEnrollmentModel enrollment) async {
    throw Exception('Error simulado al guardar inscripción en base de datos');
  }
}

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late BleAir air;
  late AppDatabase teacherDb;
  late EnrollmentHostService host;
  late ClassInvite invite;
  final phones = <_Phone>[];
  var dbCount = 0;

  AppDatabase newDb() =>
      AppDatabase(factory: databaseFactoryFfi, databasePath: p.join(tmp.path, 'db${dbCount++}.sqlite'));

  _Phone newPhone({EnrollmentKeyStore? keyStore}) {
    final phone = _Phone(newDb(), air.node(), keyStore: keyStore);
    phones.add(phone);
    return phone;
  }

  Future<void> waitUntil(bool Function() condition, {String reason = ''}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('No se cumplió a tiempo: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('inscripcion_fix_');
    air = BleAir();
    teacherDb = newDb();
    await teacherDb.insertCourse(_course);
    host = EnrollmentHostService(
      course: _course,
      database: teacherDb,
      bleService: air.node(),
      responseInterval: const Duration(milliseconds: 10),
      responseLinger: const Duration(milliseconds: 150),
    );
  });

  Future<void> openEnrollment() async {
    await host.start();
    invite = ClassInvite.parse(await host.buildClassQrPayload());
  }

  tearDown(() async {
    for (final phone in phones) {
      await phone.client.cancel();
      await phone.db.close();
    }
    phones.clear();
    await host.dispose();
    await air.dispose();
    await teacherDb.close();
    tmp.deleteSync(recursive: true);
  });

  test('con MemoryEnrollmentKeyStore, dos solicitudes seguidas usan la misma clave pública', () async {
    final keyStore = MemoryEnrollmentKeyStore();
    final phoneDb = newDb();
    final client = EnrollmentClientService(
      database: phoneDb,
      bleService: air.node(),
      keyStore: keyStore,
      fragmentInterval: const Duration(milliseconds: 10),
    );

    await openEnrollment();

    final packets1 = <Uint8List>[];
    final listener = air.node();
    await listener.startScan();
    final sub1 = listener.packetEvents.listen((e) => packets1.add(e.packet16));

    unawaited(client.request(invite: invite, studentCode: '0182120016', displayName: 'Yoner').drain());
    await waitUntil(() => packets1.any((p) => EnrollmentPacketCodec.isRequestFragment(p)));
    await client.cancel();
    await sub1.cancel();

    final storedPair = await keyStore.load(invite.courseId, '0182120016');
    expect(storedPair, isNotNull);

    final packets2 = <Uint8List>[];
    final sub2 = listener.packetEvents.listen((e) => packets2.add(e.packet16));
    unawaited(client.request(invite: invite, studentCode: '0182120016', displayName: 'Yoner').drain());
    await waitUntil(() => packets2.any((p) => EnrollmentPacketCodec.isRequestFragment(p)));
    await client.cancel();
    await sub2.cancel();
    await listener.stopScan();

    final storedPair2 = await keyStore.load(invite.courseId, '0182120016');
    expect(storedPair2!.publicKeyHex, storedPair!.publicKeyHex);
    expect(storedPair2.privateKeyHex, storedPair.privateKeyHex);
    await phoneDb.close();
  });

  test('estudiante de la lista ya vinculado con esa clave que vuelve a pedir: queda aceptado sin pasar a Reemplazar celular', () async {
    await teacherDb.insertStudent(_rosterStudent('0182120016', 5, name: 'Yoner Isaza'));
    await openEnrollment();

    final keyStore = MemoryEnrollmentKeyStore();
    final phone = newPhone(keyStore: keyStore);

    // Primera inscripción:
    final updates1 = await phone.join(invite, '0182120016', name: 'Yoner');
    expect(updates1.last.phase, EnrollmentClientPhase.accepted);
    expect(host.state.pending, isEmpty);

    // Reintento con el mismo celular (misma clave en keyStore):
    final updates2 = await phone.join(invite, '0182120016', name: 'Yoner');
    expect(updates2.last.phase, EnrollmentClientPhase.accepted);
    expect(host.state.pending, isEmpty, reason: 'No debe salir en Por aprobar ni en conflictos');
  });

  test('dos teléfonos con el mismo código: queda una tarjeta estable y el teléfono desplazado recibe rechazada', () async {
    await openEnrollment();

    final phone1 = newPhone(keyStore: MemoryEnrollmentKeyStore());
    final phone2 = newPhone(keyStore: MemoryEnrollmentKeyStore());

    final f1 = phone1.join(invite, '0182120099');
    await waitUntil(() => host.state.pending.isNotEmpty, reason: 'primera solicitud en espera');
    expect(host.state.pending.length, 1);
    final firstReqId = host.state.pending.single.requestId;

    final f2 = phone2.join(invite, '0182120099');
    await waitUntil(
      () => host.state.pending.isNotEmpty && host.state.pending.single.requestId != firstReqId,
      reason: 'segunda solicitud reemplaza a la anterior',
    );

    expect(host.state.pending.length, 1, reason: 'Solo debe quedar una solicitud para ese código');
    expect(host.state.pending.single.studentCode, '0182120099');

    // El teléfono 1 desplazado debe recibir «rechazada» y terminar su flujo:
    final updates1 = await f1;
    expect(updates1.last.phase, EnrollmentClientPhase.rejected);

    // Tras el rechazo del teléfono 1, la tarjeta del teléfono 2 sigue estable en espera:
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(host.state.pending.length, 1);
    expect(host.state.pending.single.requestId, isNot(equals(firstReqId)));

    // El docente puede aprobar la solicitud estable del teléfono 2:
    final approved = await host.approve(host.state.pending.single.requestId, fullName: 'Carlos');
    expect(approved.studentCode, '0182120099');

    final updates2 = await f2;
    expect(updates2.last.phase, EnrollmentClientPhase.accepted);
  });

  test('una solicitud en espera no vence mientras el teléfono sigue anunciando aunque pase pendingTtl, y vence cuando deja de anunciar', () async {
    var currentTime = DateTime(2026, 11, 1, 8, 0, 0);
    final timedHost = EnrollmentHostService(
      course: _course,
      database: teacherDb,
      bleService: air.node(),
      now: () => currentTime,
      responseInterval: const Duration(milliseconds: 10),
      pendingTtl: const Duration(seconds: 90),
    );
    await timedHost.start();
    final timedInvite = ClassInvite.parse(await timedHost.buildClassQrPayload());

    final phone = newPhone(keyStore: MemoryEnrollmentKeyStore());
    unawaited(phone.join(timedInvite, '0182120099'));

    await waitUntil(() => timedHost.state.pending.isNotEmpty, reason: 'solicitud visible en espera');
    expect(timedHost.state.pending.length, 1);
    final reqId = timedHost.state.pending.single.requestId;

    // Avanzar reloj simulado más allá de pendingTtl (90s):
    currentTime = currentTime.add(const Duration(seconds: 95));

    // Mientras el teléfono sigue anunciando fragmentos, la solicitud NO debe vencer:
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(timedHost.state.pending, isNotEmpty, reason: 'no debe vencer mientras el teléfono siga anunciando');
    expect(timedHost.state.pending.single.requestId, reqId);

    // El estudiante cancela (deja de anunciar fragmentos):
    await phone.client.cancel();

    // Avanzar reloj simulado más allá de pendingTtl desde que dejó de anunciar:
    currentTime = currentTime.add(const Duration(seconds: 95));

    // El temporizador de respuestas descarta la solicitud vencida:
    await waitUntil(() => timedHost.state.pending.isEmpty, reason: 'solicitud vencida descartada');

    // Intentar aprobar solicitud vencida lanza StateError:
    await expectLater(
      () => timedHost.approve(reqId, fullName: 'Carlos'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('ya no está disponible'))),
    );

    await timedHost.dispose();
  });

  test('dos approve simultáneos de solicitudes distintas terminan con dos estudiantes en casillas distintas', () async {
    await openEnrollment();

    final phone1 = newPhone(keyStore: MemoryEnrollmentKeyStore());
    final phone2 = newPhone(keyStore: MemoryEnrollmentKeyStore());

    final f1 = phone1.join(invite, '0182120001');
    final f2 = phone2.join(invite, '0182120002');

    await waitUntil(() => host.state.pending.length == 2, reason: 'dos solicitudes en espera');
    final req1 = host.state.pending.firstWhere((p) => p.studentCode == '0182120001').requestId;
    final req2 = host.state.pending.firstWhere((p) => p.studentCode == '0182120002').requestId;

    final results = await Future.wait([
      host.approve(req1, fullName: 'Estudiante Uno'),
      host.approve(req2, fullName: 'Estudiante Dos'),
    ]);

    expect(results[0].bitIndex, isNot(equals(results[1].bitIndex)));
    expect({results[0].bitIndex, results[1].bitIndex}, hasLength(2));

    final st1 = await teacherDb.getStudentByCode(courseId: _course.id, studentCode: '0182120001');
    final st2 = await teacherDb.getStudentByCode(courseId: _course.id, studentCode: '0182120002');
    expect(st1!.bitIndex, isNot(equals(st2!.bitIndex)));
    await Future.wait([f1, f2]);
  });

  test('start() con startScan que lanza: relanza y luego stop() deja todo limpio sin aceptar paquetes posteriores', () async {
    final failingBle = _FailingBle(shouldThrowScan: true);
    final brokenHost = EnrollmentHostService(
      course: _course,
      database: teacherDb,
      bleService: failingBle,
    );

    await expectLater(brokenHost.start(), throwsA(isA<Exception>()));

    await brokenHost.stop();
    expect(brokenHost.isRunning, isFalse);
    expect(brokenHost.state.pending, isEmpty);

    // Un paquete de solicitud que llega después de stop() no crea ninguna solicitud en espera:
    final pair = await EnrollmentCrypto.generateKeyPair();
    final fragments = EnrollmentPacketCodec.buildRequestFragments(
      courseId: _course.id,
      requestId: 5555,
      studentCode: '0182120099',
      studentPublicKeyHex: pair.publicKeyHex,
      sharedSecretHex: _secret,
    );
    for (final fragment in fragments) {
      failingBle.injectSimulatedPacket(packet16: fragment, rssi: -50);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(brokenHost.state.pending, isEmpty, reason: 'paquetes tras stop() no deben crear solicitudes en espera');

    await brokenHost.dispose();
  });

  test('approve cuando el código ya existe en la clase lanza StateError y quita la solicitud', () async {
    await teacherDb.insertStudent(_rosterStudent('0182120016', 2, name: 'Original'));
    await openEnrollment();

    final phone = newPhone(keyStore: MemoryEnrollmentKeyStore());
    unawaited(phone.join(invite, '0182120099'));
    await waitUntil(() => host.state.pending.isNotEmpty);
    final reqId = host.state.pending.single.requestId;

    await teacherDb.insertStudent(_rosterStudent('0182120099', 4, name: 'Existente'));

    await expectLater(
      () => host.approve(reqId, fullName: 'Colisión'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('ya está en la clase'))),
    );
    expect(host.state.pending, isEmpty);
    await phone.client.cancel();
  });

  test('error en upsertStudentEnrollment emite error en el stream del cliente y no se cuelga', () async {
    await teacherDb.insertStudent(_rosterStudent('0182120016', 0));
    await openEnrollment();

    final failingDb = _FailingDatabase();
    final phone = EnrollmentClientService(
      database: failingDb,
      bleService: air.node(),
      keyStore: MemoryEnrollmentKeyStore(),
      fragmentInterval: const Duration(milliseconds: 10),
    );

    Object? caughtError;
    final completer = Completer<void>();
    phone.request(invite: invite, studentCode: '0182120016', displayName: 'Yoner').listen(
      (_) {},
      onError: (err) {
        caughtError = err;
        completer.complete();
      },
    );

    await completer.future.timeout(const Duration(seconds: 3));
    expect(caughtError, isNotNull);
    await phone.cancel();
  });

  test('PrefsEnrollmentKeyStore load devuelve null y save no lanza si SharedPreferences falla', () async {
    const store = PrefsEnrollmentKeyStore();
    final loaded = await store.load('c1', 's1');
    expect(loaded, isNull);

    await store.save('c1', 's1', const EnrollmentKeyPair(privateKeyHex: 'aa', publicKeyHex: 'bb'));
  });

  test('hostState refleja el cupo completo incluyendo estudiantes retirados', () async {
    for (var i = 0; i < 63; i++) {
      await teacherDb.insertStudent(_rosterStudent('01821${i.toString().padLeft(5, '0')}', i));
    }
    await teacherDb.insertStudent(_rosterStudent('0182199999', 63));
    await teacherDb.retireStudent(
      studentId: 'st-0182199999',
      retiredAt: '2026-11-10T08:00:00.000-05:00',
      newSecretHex: 'aa' * 32,
    );

    await openEnrollment();

    expect(host.state.totalStudents, 63);
    expect(host.state.totalAllStudents, 64);
    expect(host.state.isFull, isTrue);
  });
}
