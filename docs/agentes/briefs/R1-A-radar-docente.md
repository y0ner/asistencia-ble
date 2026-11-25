# Brief R1-A · Radar del docente: sin avalancha, sin sobrescribir y sin sesiones viejas

- **Rama:** `fix/radar-docente` · **Worktree:** `../worktrees/fix-radar-docente`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `lib/data/services/attendance_session_controller.dart` (completo),
  `lib/features/teacher/live_attendance_session_screen.dart` (completo),
  `lib/data/local/app_database.dart` (métodos de sesiones y asistencias; **no lo edites**),
  `test/attendance_session_controller_test.dart`, `test/support/fake_ble_air.dart`.
- **Objetivo:** que tomar asistencia con un salón lleno no congele la app, que
  una detección repetida no borre lo que ya se registró y que no se retome una
  sesión de otro día.

## Archivos permitidos

- `lib/data/services/attendance_session_controller.dart`
- `lib/features/teacher/live_attendance_session_screen.dart`
- `test/radar_docente_test.dart` (**nuevo**)
- `test/attendance_session_controller_test.dart` y `test/ui/docente_sesion_test.dart`
  (solo si una comprobación existente choca con un arreglo; dilo)

## Fallos a corregir

1. **Detección repetida = escritura repetida.** En `_processIncomingStudentPacket`
   (~línea 540), cada anuncio válido escribe en SQLite (`upsertAttendanceRecord`),
   recalcula el bitmap y vuelve a emitir el eco, aunque el estudiante ya esté
   presente. Con 30 celulares anunciando ~10 veces por segundo, la cola
   `_operationQueue` crece sin límite y «Cerrar y firmar» queda esperando.
   **Arreglo:** después de verificar el paquete y encontrar al estudiante, si
   su bit ya está encendido en `state.bitmap8`, devuelve un
   `StudentDetectionOutcome` aceptado **sin escribir en la base ni volver a
   emitir el eco**.
2. **Una detección repetida o editar la nota sobrescribe el registro.**
   - Con el arreglo 1, el radar ya no toca un registro existente. Comprueba
     que un estudiante marcado a mano con nota «llegó tarde» conserve
     `method`, `observation` y `recordedAt` cuando después llega su beacon.
   - En `_toggleManualAttendance` (~línea 658) con `isPresent: true`, si el
     estudiante **ya tiene registro**, conserva su `method`, `recordedAt`,
     `timeTick`, `hmacTag` y `rssiAvg`, y cambia **solo** `observation`.
     Lee el registro existente con los métodos que ya tiene `AppDatabase`.
3. **Se retoma una sesión abierta de otro día.** En `_startTeacherSession`
   (~línea 483), `consolidateOpenSession` devuelve la sesión abierta y se
   retoma aunque sea de la semana pasada, así que el acta mezcla dos clases.
   **Arreglo:**
   - Agrega a `startTeacherSession` el parámetro opcional `DateTime? nowOverride`
     (para pruebas; por defecto `DateTime.now()`).
   - Si la sesión abierta empezó **otro día local** (compara año, mes y día de
     `DateTime.parse(startedAt).toLocal()` con `now`):
     - sin registros de asistencia → bórrala (`deleteSession`);
     - con registros → **ciérrala con su acta firmada**, igual que
       `closeAndSignSession`, con `closedAt` = el `recordedAt` más reciente de
       sus registros. Para no duplicar código, saca la construcción y el
       guardado del acta a un método privado que usen los dos caminos.
     - Después crea una sesión nueva normal.
   - Si es del mismo día, se retoma como hoy.
4. **Salir mientras dice «Abriendo la sesión…» deja el radar encendido.**
   - En el controlador, `dispose()` detiene el BLE y luego espera la cola;
     si `_startTeacherSession` estaba en curso, enciende el escaneo después.
     **Arreglo:** en `dispose()`, después de `await _operationQueue`, llama
     otra vez a `_stopBleRuntime()`. En `_startTeacherSession`, después de
     cada `await`, si `_disposed` es `true` no sigas (no suscribas ni escanees).
   - En la pantalla, `_initializeSession` crea `_bleEventsSub`, `_bleIssuesSub`
     y `_periodicRefreshTimer` aunque la pantalla ya se haya cerrado.
     **Arreglo:** después de cada `await`, `if (!mounted) return;` antes de
     crear suscripciones o temporizadores.
   - La pantalla crea un `BleAttendanceService` propio cuando
     `widget.bleService` es nulo y nunca lo libera (el controlador no es su
     dueño). **Arreglo:** recuerda si la pantalla lo creó y, en `dispose`,
     libéralo **después** de que termine `_controller.dispose()`.
5. **Una recarga de la base por cada anuncio.** `_bleEventsSub` programa un
   `_reloadRecords()` por cada evento BLE. **Arreglo:** como máximo una recarga
   pendiente a la vez (una bandera; la siguiente se programa cuando termine la
   anterior). El temporizador periódico de 1,5 s se queda.
6. **Si falla el cierre, la sesión queda abierta pero sin radar.** En
   `_closeAndSignSession`, `_stopBleRuntime()` corre antes de guardar el acta;
   si el guardado lanza, nadie reactiva el escaneo ni el eco. **Arreglo:** si
   falla y la sesión sigue abierta y el controlador no está liberado, vuelve a
   suscribir el BLE, arranca el escaneo y el eco, y relanza el error.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/radar_docente_test.dart` (usa la base en memoria y el aire
falso como `test/attendance_session_controller_test.dart`):

- [ ] Procesar 50 veces el mismo paquete válido de un estudiante deja **un**
      registro y su `recordedAt` es el de la **primera** detección (usa `nowOverride`).
- [ ] Estudiante marcado a mano con nota «llegó tarde» y luego llega su
      beacon: el registro sigue con método manual, la nota y la hora original.
- [ ] Editar la nota de un presente (`toggleManualAttendance(isPresent: true, observation: 'x')`)
      cambia la nota y conserva `method` y `recordedAt`.
- [ ] Sesión abierta de ayer con un registro: `startTeacherSession(nowOverride: hoy)`
      crea una sesión **nueva**; la de ayer queda cerrada, con acta guardada y
      `closedAt` igual a la hora de su registro.
- [ ] Sesión abierta de ayer sin registros: se borra y se crea una nueva.
- [ ] Sesión abierta de hoy: se retoma (mismo id y PIN).
- [ ] Si guardar el acta falla (subclase de `AppDatabase` que lanza en
      `closeSessionWithActa`), `closeAndSignSession` lanza y el escaneo vuelve
      a estar activo.
- [ ] Pasan: `flutter test test/radar_docente_test.dart`,
      `flutter test test/attendance_session_controller_test.dart`,
      `flutter test test/ui/docente_sesion_test.dart`,
      `flutter test test/defense_demo_e2e_test.dart`.

## Qué probará el humano

Tomar asistencia con varios celulares a la vez: la lista se actualiza sin
trabarse y «Cerrar y firmar» responde al instante. Marcar a uno a mano con nota
y verificar que la nota sigue después de que llega su señal.
