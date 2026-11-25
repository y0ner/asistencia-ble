# Brief R2-E · Avisos de permisos cuando faltan Bluetooth y ubicación a la vez

- **Rama:** `fix/permisos-combinados` · **Worktree:** `../worktrees/fix-permisos-combinados`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md` (valen igual
  para R2), `docs/agentes/briefs/R1-F-permisos-android.md`,
  `lib/data/services/ble_permission_service.dart`,
  `lib/features/shared/ble_ready_gate.dart`,
  `lib/features/shared/permissions_gate.dart`,
  `lib/data/services/app_permissions_service.dart`,
  y las partes de permisos de `lib/features/teacher/live_attendance_session_screen.dart`
  (~líneas 555-600) y `lib/features/student/student_live_beacon_screen.dart`
  (~líneas 520-600).
- **Objetivo:** que, con Bluetooth y ubicación apagados a la vez, o en Android
  ≤ 11, cada pantalla diga lo que de verdad falta y ofrezca el botón correcto.

## Archivos permitidos

- `lib/data/services/ble_permission_service.dart`
- `lib/features/shared/ble_ready_gate.dart`
- `lib/features/teacher/live_attendance_session_screen.dart` (**solo** el bloque del aviso de permisos)
- `lib/features/student/student_live_beacon_screen.dart` (**solo** el bloque del aviso de permisos)
- `test/permisos_combinados_test.dart` (**nuevo**)
- `test/permisos_android_test.dart`, `test/ble_permission_service_test.dart`,
  `test/ui/docente_sesion_test.dart`, `test/ui/estudiante_marcar_test.dart`
  (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **Bluetooth y ubicación apagados a la vez.** `onlyBluetoothOff` exige la
   ubicación encendida y `onlyLocationServiceOff` exige el Bluetooth
   encendido. Con los dos apagados, ambos dan `false` y `BleReadyGate` muestra
   «Falta un permiso · Permite el acceso a «Ubicación»» aunque el permiso está
   concedido, y desaparece el botón «Encender Bluetooth». **Arreglo:** agrega
   a `BlePermissionResult` getters claros:
   - `isBluetoothOffBlocking` (sin permisos que falten y Bluetooth apagado);
   - `isLocationServiceOffBlocking` (sin permisos que falten, SDK ≤ 30 y ubicación apagada).
   Las pantallas resuelven **primero** el Bluetooth (botón «Encender
   Bluetooth») y, cuando ya está encendido, la ubicación (mensaje y «Revisar de
   nuevo»). Conserva `onlyBluetoothOff` y `onlyLocationServiceOff` si otro
   código los usa, o reemplaza sus usos.
2. **Textos de «Dispositivos cercanos» en Android ≤ 11.** En
   `live_attendance_session_screen.dart` (~570) y `student_live_beacon_screen.dart`
   (~559) el aviso dice «permite «Dispositivos cercanos»», un permiso que no
   existe antes de Android 12. **Arreglo:** usa «Ubicación» cuando
   `result.isAndroid11OrLower`, y con la ubicación del sistema apagada muestra
   el `failureMessage` del servicio. Si los tres sitios (las dos pantallas y
   `BleReadyGate`) repiten la misma lógica, sácala a una función pública en
   `ble_permission_service.dart` (por ejemplo `blePermissionAdvice(result, purpose)`
   que devuelva título, mensaje y acción) y úsala en los tres.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/permisos_combinados_test.dart`:

- [ ] SDK 30, permiso concedido, Bluetooth y ubicación apagados → `BleReadyGate`
      muestra «Encender Bluetooth» (no «Falta un permiso»).
- [ ] SDK 30, Bluetooth encendido y ubicación apagada → mensaje de ubicación y
      «Revisar de nuevo».
- [ ] SDK 30 con el permiso de ubicación sin conceder → el texto dice «Ubicación»,
      no «Dispositivos cercanos».
- [ ] SDK 33 con permisos sin conceder → el texto dice «Dispositivos cercanos».
- [ ] Las dos pantallas de asistencia (docente y estudiante) con SDK 30 y el
      permiso sin conceder no muestran «Dispositivos cercanos».
- [ ] Pasan: `flutter test test/permisos_combinados_test.dart`,
      `flutter test test/permisos_android_test.dart`,
      `flutter test test/ble_permission_service_test.dart`,
      `flutter test test/ui/docente_sesion_test.dart`,
      `flutter test test/ui/estudiante_marcar_test.dart`.

## Qué probará el humano

Con el Bluetooth apagado, abrir la toma de asistencia: sale «Encender Bluetooth».
