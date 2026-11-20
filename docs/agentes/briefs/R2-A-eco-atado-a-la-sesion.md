# Brief R2-A · Eco del docente atado al PIN de la sesión y a la hora

- **Rama:** `fix/eco-sesion` · **Worktree:** `../worktrees/fix-eco-sesion`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md` (las reglas
  comunes de R1 valen igual para R2), `lib/core/crypto/ble_packet_codec.dart`
  (completo), y en `lib/data/services/attendance_session_controller.dart` los
  métodos `_publishTeacherEcho` y `checkTeacherEchoForStudent`. Busca todos los
  usos con `grep -rn "TeacherEcho" lib test`.
- **Objetivo:** que un eco grabado de otra clase, de otra sesión o de otro
  momento no le dé «¡Presente!» al estudiante.

## Contexto

El docente emite un «eco» de 16 bytes con el bitmap de presentes:
`[courseHash16:2][0x00:1][sessionShortId alto:1][bitmap:8][HMAC:4]`. El HMAC
cubre los 12 primeros bytes con el secreto del curso. El estudiante verifica el
curso y la firma, pero **no** el byte 3 ni la hora. Por eso un eco grabado de
otra sesión del mismo curso (otro día, otro PIN) se acepta. El beacon del
estudiante sí está atado al PIN y a un tick de 30 s, con tolerancia de ±1 tick
(`verifyStudentBeaconBytes`, `computeTimeTick`).

## Archivos permitidos

- `lib/core/crypto/ble_packet_codec.dart`
- `lib/data/services/ble_attendance_service.dart` (**solo** `startTeacherEcho`)
- `lib/data/services/attendance_session_controller.dart` (**solo**
  `_publishTeacherEcho`, `checkTeacherEchoForStudent` y lo que necesiten)
- `lib/features/student/student_live_beacon_screen.dart` (**solo** la llamada a
  `verifyTeacherEchoBytes` del indicador de señal)
- Las pruebas que usan el eco: `test/ble_packet_codec_test.dart`,
  `test/ble_crypto_and_enrollment_test.dart`, `test/enrollment_codec_test.dart`,
  `test/attendance_session_controller_test.dart`, `test/ui/estudiante_marcar_test.dart`
  (solo para pasar los parámetros nuevos; no quites comprobaciones).
- `test/eco_sesion_test.dart` (**nuevo**)

## Cambio de protocolo

1. **Formato nuevo del eco:** `[courseHash16:2][0x00:1][pin:1][bitmap:8][HMAC:4]`.
   - El byte 3 pasa a ser el **PIN de la sesión** (10–99), igual que en el
     beacon del estudiante.
   - El HMAC (4 bytes, secreto del curso) firma los 12 primeros bytes **más el
     tick de 30 s** en 4 bytes big-endian. El tick **no** viaja en el paquete.
2. **`buildTeacherEchoBytes`**:
   `({required String courseId, required int sessionPin, required Uint8List bitmap8, required String sharedSecretHex, required int timeTick})`.
   Ya no recibe `sessionId`. Valida el PIN como lo hace el beacon.
3. **`verifyTeacherEchoBytes`**:
   `({required Uint8List packet16, required String expectedCourseId, required int expectedSessionPin, required String sharedSecretHex, required int currentTimeTick, int clockSkewToleranceTicks = 1})`.
   - Rechaza si el byte 3 no es el PIN esperado, con el motivo
     «El eco es de otra sesión.».
   - Acepta si la firma coincide con algún tick entre `currentTimeTick - tolerancia`
     y `currentTimeTick + tolerancia`. Si ninguno coincide:
     «La firma HMAC del eco no es válida o está vencida.».
   - Compara siempre en tiempo constante, como hoy.
   - Conserva los rechazos que ya existen (no es eco, es de inscripción, otro curso).
4. **Docente:** `BleAttendanceService.startTeacherEcho` recibe `sessionPin` y
   `timeTick` en lugar de `sessionId`. `_publishTeacherEcho` pasa el PIN de la
   sesión y `computeTimeTick(DateTime.now())`. El temporizador del eco ya
   republica cada `teacherEchoIntervalSeconds`; al cambiar el tick cambia el
   paquete y el servicio lo vuelve a anunciar solo. Compruébalo leyendo
   `_executeAdvertisingPacket`.
5. **Estudiante:** `checkTeacherEchoForStudent` ya recibe `sessionPin`:
   pásalo junto con el tick actual (usa `nowOverride` si viene). En
   `student_live_beacon_screen.dart`, el chequeo del indicador de señal también
   pasa `_sessionPin` y el tick actual.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/eco_sesion_test.dart`:

- [ ] Un eco con PIN 42 y tick T se acepta verificando con PIN 42 y tick T,
      T−1 y T+1.
- [ ] El mismo eco se rechaza con tick T+2 (vencido) y con PIN 43 (otra sesión).
- [ ] Un eco de otro curso, uno adulterado y un paquete de estudiante se siguen rechazando.
- [ ] `checkTeacherEchoForStudent` con el PIN equivocado no confirma, aunque el
      bit del estudiante esté encendido.
- [ ] `grep -rn "sessionShortId" lib/core/crypto/ble_packet_codec.dart` solo
      queda si otra función lo sigue usando (dilo en tu respuesta).
- [ ] Pasan: `flutter test test/eco_sesion_test.dart`,
      `flutter test test/ble_packet_codec_test.dart`,
      `flutter test test/ble_crypto_and_enrollment_test.dart`,
      `flutter test test/enrollment_codec_test.dart`,
      `flutter test test/attendance_session_controller_test.dart`,
      `flutter test test/ui/estudiante_marcar_test.dart`,
      `flutter test test/radar_docente_test.dart`.

## Qué probará el humano

Marcar asistencia normal en los dos celulares: el estudiante sigue recibiendo
su «¡Presente!» (las dos apps deben tener esta versión).
