# Brief R2-F · Inscripción: solicitudes en espera estables y pruebas que de verdad prueben

- **Rama:** `fix/inscripcion-espera` · **Worktree:** `../worktrees/fix-inscripcion-espera`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md` (valen igual
  para R2), `docs/agentes/briefs/R1-E-inscripcion-ble.md`,
  `lib/data/services/enrollment_host_service.dart` (completo),
  `lib/data/services/enrollment_client_service.dart` (para entender cuándo
  reintenta), `lib/data/services/ble_attendance_service.dart` (`injectSimulatedPacket`,
  filtro de duplicados; **no lo edites**), `test/support/fake_ble_air.dart`
  (**no lo edites**) y `test/inscripcion_correcciones_test.dart`.
- **Objetivo:** corregir dos arreglos incompletos de R1-E y endurecer sus pruebas.

## Archivos permitidos

- `lib/data/services/enrollment_host_service.dart`
- `test/inscripcion_correcciones_test.dart`
- `test/inscripcion_espera_test.dart` (**nuevo**)

## Fallos a corregir

1. **La tarjeta «Por aprobar» parpadea cada 90 s.** El vencimiento
   (`_pruneExpiredPending`, ~línea 183) se cuenta desde `receivedAt`. Pero el
   estudiante que espera sigue enviando fragmentos (su espera se renueva con
   cada «pending»): a los 90 s el host borra la solicitud, los fragmentos
   siguientes la vuelven a armar y la tarjeta reaparece con otra hora. Si el
   docente estaba escribiendo el nombre, le sale «La solicitud ya no está
   disponible». **Arreglo:** la solicitud vence solo si **no se oyó ningún
   fragmento suyo** durante `pendingTtl` (usa `_decisions[id].lastHeard`, que
   `_onPacket` ya actualiza). Mientras el estudiante siga pidiendo, la tarjeta
   se queda.
2. **Dos celulares con el mismo código se quitan la solicitud uno al otro.**
   Al llegar una solicitud nueva con el mismo código se borra la anterior **y
   su decisión**. El celular desplazado sigue anunciando, sus fragmentos se
   vuelven a armar y desplazan al otro, en bucle; la tarjeta cambia de
   `requestId` y `approve` cae en un id viejo. **Arreglo:** no borres la
   decisión vieja: márcala como final (`rejected`) para que `_onPacket` absorba
   sus fragmentos (ya lo hace con decisiones conocidas) y el celular viejo
   reciba «rechazada». La solicitud en espera visible es la más reciente.

## Pruebas débiles a reforzar

3. En `test/inscripcion_correcciones_test.dart`:
   - «start() con startScan que lanza» (~línea 298): usa
     `await expectLater(brokenHost.start(), throwsA(...))` y después
     comprueba que un paquete de solicitud que llega **después** de `stop()`
     no crea ninguna solicitud en espera.
   - La prueba del vencimiento (~línea 248): con el arreglo 1, comprueba que
     **mientras el teléfono sigue anunciando** la solicitud **no** vence aunque
     pase `pendingTtl`, y que vence cuando el teléfono deja de anunciar (cancela
     el cliente) y pasa `pendingTtl`.
4. Prueba nueva `test/inscripcion_espera_test.dart`: un flujo de inscripción
   completo **con el filtro de duplicados activo** y los intervalos reales del
   cliente (400 ms) y del host (600 ms). Si el aire falso no permite activar el
   filtro sin editarlo, usa `BleAttendanceService.debugHandleAdvertisedPacket`
   o `injectSimulatedPacket(filterDuplicates: true)` para entregar los
   paquetes. Debe terminar en «aceptado» en menos de 10 s de reloj simulado (o
   real, si no hay reloj falso).

## Criterios de aceptación (además de los comunes)

- [ ] Una solicitud de un teléfono que sigue anunciando no vence a los 90 s.
- [ ] Una solicitud de un teléfono que dejó de anunciar vence tras `pendingTtl`.
- [ ] Dos teléfonos con el mismo código: queda **una** tarjeta estable y el
      teléfono desplazado recibe «rechazada».
- [ ] Las pruebas reforzadas del punto 3 y la nueva del punto 4.
- [ ] Pasan: `flutter test test/inscripcion_correcciones_test.dart`,
      `flutter test test/inscripcion_espera_test.dart`,
      `flutter test test/enrollment_flow_test.dart`,
      `flutter test test/ui/inscripcion_pantallas_test.dart`.

## Qué probará el humano

Un estudiante fuera de la lista pide unirse y el docente tarda en aprobar:
la tarjeta no desaparece mientras el estudiante espera.
