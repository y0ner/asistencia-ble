# Brief R1-B · Servicio BLE: menos eventos repetidos y recuperarse si se apaga el Bluetooth

- **Rama:** `fix/servicio-ble` · **Worktree:** `../worktrees/fix-servicio-ble`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `lib/data/services/ble_attendance_service.dart` (completo),
  `lib/features/student/student_live_beacon_screen.dart` (completo),
  `lib/core/crypto/ble_packet_codec.dart` (no lo edites),
  `test/ble_attendance_service_test.dart`, `test/support/fake_ble_air.dart`
  (no lo edites: `AirBle` extiende el servicio y otras pruebas dependen de él).
  API real de flutter_blue_plus en
  `~/.pub-cache/hosted/pub.dev/flutter_blue_plus-1.34.5/lib/src/flutter_blue_plus.dart`.
- **Objetivo:** que el radar no reenvíe miles de eventos repetidos por segundo
  y que el escaneo y la emisión vuelvan solos cuando se apaga y se enciende el
  Bluetooth.

## Archivos permitidos

- `lib/data/services/ble_attendance_service.dart`
- `lib/features/student/student_live_beacon_screen.dart`
- `test/ble_attendance_service_test.dart`
- `test/ui/estudiante_marcar_test.dart` (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **Avalancha de eventos.** `startScan` escucha `FlutterBluePlus.onScanResults`
   con `continuousUpdates: true`; sin `oneByOne`, cada anuncio de cualquier
   celular reenvía la **lista completa** de dispositivos, y `_processScanResult`
   emite un evento por cada uno. **Arreglo:**
   - Llama a `startScan` con `oneByOne: true` (conserva `continuousUpdates: true`).
   - En el punto donde se emite el evento (`_emitIfNearby`), descarta un paquete
     **idéntico** (mismos 16 bytes) que ya se emitió hace menos de
     `duplicateWindow` (parámetro opcional del constructor, por defecto 2 s).
     Usa un mapa por paquete con la hora de la última emisión y límpialo para
     que no crezca sin límite (p. ej. quita las entradas viejas cuando supere
     256). Un paquete distinto (otro estudiante, otro tick) pasa siempre.
   - Para probarlo sin radio: agrega al constructor un reloj opcional
     `DateTime Function()? now` y un método `@visibleForTesting`
     `void debugHandleAdvertisedPacket(Uint8List packet16, int rssi)` que pase
     por el mismo camino que un resultado de escaneo.
2. **Si se apaga el Bluetooth, el radar no vuelve.** Al apagarse el adaptador,
   flutter_blue_plus detiene el escaneo, pero `_scanSubscription` sigue con
   valor y `startScan` ya no arranca nada. La emisión tampoco se reanuda:
   `_isAdvertising` sigue en `true` con el mismo paquete y el eco lo salta.
   **Arreglo:**
   - Recuerda el paquete que se **quiere** anunciar (se fija en
     `startAdvertisingPacket` y se borra en `stopAdvertising`) aparte de
     `_lastAdvertisedPacket`.
   - En `_listenAdapterState`: cuando el estado deja de ser `on`, pon
     `_isAdvertising = false` y `_lastAdvertisedPacket = null`. Cuando vuelve a
     `on` después de haber estado apagado: si el escaneo estaba pedido
     (`_scanSubscription != null`), vuelve a llamar a `FlutterBluePlus.startScan`
     con los mismos parámetros; si hay un paquete deseado, vuelve a anunciarlo
     por la cola `_adQueue`. Reporta los fallos con `_reportIssue`, sin lanzar.
   - Para probarlo: agrega al constructor parámetros opcionales
     `Stream<BluetoothAdapterState>? adapterStates` y
     `Future<void> Function()? startScanOverride` (por defecto, los de
     flutter_blue_plus). No cambies el comportamiento cuando son nulos.
   - Comprueba que `_listenAdapterState` también se active cuando solo se
     anuncia (sin escanear).
3. **Pantalla del estudiante:**
   - Doble toque en «Continuar» (`_startBroadcasting`, ~línea 144): no hay
     bandera de ocupado, así que se crean dos `_bleSubscription` y la primera
     nunca se cancela. **Arreglo:** bandera `_isStartingBroadcast`; si ya está
     arrancando, no hagas nada; el botón queda desactivado mientras tanto.
     Cancela una `_bleSubscription` previa antes de crear otra.
   - Falta `if (!mounted) return;` antes del `setState` que pasa a
     `StudentBeaconPhase.broadcasting` (después de `await ensureReady()`).
   - `_handleIncomingPacket` toma como señal del profesor (`_lastTeacherRssi`)
     el RSSI de **cualquier** paquete, también los beacons de otros
     estudiantes, y hace `setState` con cada uno. **Arreglo:** actualiza
     `_lastTeacherRssi` solo si el paquete es un eco del docente de **esta**
     clase (usa lo que ya ofrece `BlePacketCodec`, por ejemplo
     `verifyTeacherEchoBytes(...).isValid`) y haz `setState` solo si el valor cambió.

## Criterios de aceptación (además de los comunes)

En `test/ble_attendance_service_test.dart` (grupo nuevo):

- [ ] El mismo paquete entregado 100 veces dentro de 2 s produce **un** evento;
      pasado `duplicateWindow` (reloj falso) produce otro.
- [ ] Dos paquetes distintos entregados juntos producen dos eventos.
- [ ] Anunciando un paquete: el adaptador pasa a `off` y luego a `on`
      (`adapterStates` falso) → el periférico falso recibe un nuevo `start`
      con el mismo paquete.
- [ ] Escaneando: `off` → `on` → `startScanOverride` se llama otra vez.
- [ ] Después de `stopAdvertising()`, un `off` → `on` **no** vuelve a anunciar.
- [ ] Pasan: `flutter test test/ble_attendance_service_test.dart`,
      `flutter test test/ui/estudiante_marcar_test.dart`,
      `flutter test test/enrollment_flow_test.dart`,
      `flutter test test/attendance_session_controller_test.dart`.

## Qué probará el humano

Con una sesión abierta, apagar y encender el Bluetooth del docente y del
estudiante: la asistencia vuelve a funcionar sin salir de la pantalla.
