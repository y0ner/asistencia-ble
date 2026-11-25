# Brief R1-F · Permisos en Android 11 o anterior, diagnóstico y manifiesto

- **Rama:** `fix/permisos-android` · **Worktree:** `../worktrees/fix-permisos-android`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `lib/data/services/ble_permission_service.dart`,
  `lib/data/services/app_permissions_service.dart`,
  `lib/features/shared/permissions_gate.dart`,
  `lib/features/shared/ble_ready_gate.dart`,
  `lib/features/shared/hardware_diagnostic_dialog.dart`,
  `lib/core/platform/android_sdk.dart`,
  `android/app/src/main/AndroidManifest.xml`, `run.sh`,
  `test/ble_permission_service_test.dart`, `test/ui/permisos_inicio_test.dart`.
  API real de permission_handler en `~/.pub-cache/hosted/pub.dev/permission_handler-*/lib/`
  y `permission_handler_platform_interface-*/lib/` (`Permission.location.serviceStatus`, `ServiceStatus`).
- **Objetivo:** que en Android 7–11 la app avise cuando falta la ubicación del
  sistema (sin ella el Bluetooth no encuentra nada), que el diagnóstico no
  marque «Falta» en permisos que no existen, y que la app Docente no pida cámara.

## Archivos permitidos

- `lib/data/services/ble_permission_service.dart`
- `lib/data/services/app_permissions_service.dart`
- `lib/features/shared/permissions_gate.dart`
- `lib/features/shared/ble_ready_gate.dart`
- `lib/features/shared/hardware_diagnostic_dialog.dart`
- `lib/features/shared/how_it_works/help_center_screen.dart` (**solo** la
  llamada a `showHardwareDiagnosticDialog`, para pasar `needsCamera`)
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/docente/AndroidManifest.xml` (**nuevo**)
- `run.sh`
- `test/permisos_android_test.dart` (**nuevo**)
- `test/ble_permission_service_test.dart`, `test/ui/permisos_inicio_test.dart`,
  `test/ui/ayuda_centro_test.dart` (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **Ubicación del sistema apagada en Android ≤ 11.** Con SDK ≤ 30 el escaneo
   BLE no devuelve nada si el interruptor de ubicación está apagado, aunque el
   permiso esté concedido, y hoy la app dice «listo».
   **Arreglo:**
   - En `BlePermissionService.ensureReady` y en `AppPermissionsService.check`
     (y donde decidan «listo»): con SDK ≤ 30, además de los permisos, exige
     que `Permission.location.serviceStatus` sea `ServiceStatus.enabled`.
     Agrega un proveedor inyectable (como los que ya existen) para poder
     probarlo, con el de permission_handler por defecto.
   - Si está apagada, el resultado no está listo y el mensaje es:
     «Activa la ubicación del celular. En Android 11 o anterior el Bluetooth
     la necesita para encontrar otros celulares; la app no guarda tu ubicación.»
   - En `PermissionsGate` y `BleReadyGate` ese caso muestra el mensaje y un
     botón «Revisar de nuevo» que vuelve a comprobar. Si permission_handler no
     ofrece abrir los ajustes de ubicación, no inventes otra forma.
   - Con SDK ≥ 31 no cambies nada.
2. **Diagnóstico «Permisos del celular»** (`hardware_diagnostic_dialog.dart`
   ~líneas 77-97):
   - En Android ≤ 11 las filas de Bluetooth cercano (scan, advertise, connect)
     salen siempre «Falta» porque esos permisos no existen antes de SDK 31.
     **Arreglo:** con SDK ≥ 31 muestra esas filas; con SDK ≤ 30 muestra en su
     lugar «Ubicación» (permiso) y «Ubicación del celular encendida» (servicio).
   - La app Docente ve la fila «Cámara» y «Dar permisos» le pide la cámara.
     **Arreglo:** agrega a `showHardwareDiagnosticDialog` el parámetro opcional
     `bool needsCamera = true`; la fila y la petición de cámara solo van si es
     `true`. En `help_center_screen.dart` pásale `needsCamera: content.studentView`.
3. **Texto de `BleReadyGate` en Android ≤ 11** (~líneas 91-92): dice que
   permita «Dispositivos cercanos», que no existe en esas versiones.
   **Arreglo:** con SDK ≤ 30 el texto habla de «Ubicación».
4. **`PermissionsGate` se queda en un círculo de carga** si `service.check()`
   lanza (~líneas 57 y 88): `_status` queda nulo y no hay botón. **Arreglo:**
   guarda el error (con `debugPrint`) y muestra «No pudimos revisar los
   permisos.» con un botón «Reintentar».
5. **Manifiesto:**
   - La app Docente no usa la cámara, pero `CAMERA` está en `main` y además el
     plugin mobile_scanner la declara (se fusiona en las dos apps). **Arreglo:**
     deja `CAMERA` en `main` (la necesita Estudiante) y crea
     `android/app/src/docente/AndroidManifest.xml` que la quite con
     `<uses-permission android:name="android.permission.CAMERA" tools:node="remove"/>`
     (declara `xmlns:tools`).
   - `ACCESS_FINE_LOCATION` hace que Google Play exija GPS. Agrega en `main`
     `<uses-feature android:name="android.hardware.location" android:required="false"/>`
     y `<uses-feature android:name="android.hardware.location.gps" android:required="false"/>`.
6. **`run.sh`:** las opciones `build-apk`/`apk` y la ejecución por defecto
   compilan sin `--flavor` y fallan con los flavors. **Arreglo:** `build-apk`/`apk`
   compila las dos apps (llama a las ramas `apk-docente` y `apk-estudiante`
   que ya existen) y la ejecución por defecto muestra la ayuda de uso en vez
   de correr sin flavor.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/permisos_android_test.dart`:

- [ ] SDK 30, permiso de ubicación concedido y servicio apagado →
      `ensureReady` no está listo y su mensaje habla de activar la ubicación.
- [ ] SDK 30, permiso concedido y servicio encendido → listo.
- [ ] SDK 33 con los permisos de Bluetooth concedidos → listo sin consultar
      el servicio de ubicación.
- [ ] `PermissionsGate` con un servicio cuyo `check()` lanza muestra
      «Reintentar»; al tocarlo con un servicio que ya responde, avanza.
- [ ] El diálogo de diagnóstico con SDK 30 no muestra las filas de Bluetooth
      cercano y con `needsCamera: false` no muestra «Cámara» (si el diálogo no
      permite inyectar el SDK, agrega un parámetro opcional para eso).
- [ ] `grep -c 'tools:node="remove"' android/app/src/docente/AndroidManifest.xml` da 1.
- [ ] `bash -n run.sh` sin errores.
- [ ] Pasan: `flutter test test/permisos_android_test.dart`,
      `flutter test test/ble_permission_service_test.dart`,
      `flutter test test/ui/permisos_inicio_test.dart`,
      `flutter test test/ui/ayuda_centro_test.dart`,
      `flutter test test/app_flavor_test.dart`.

## Qué probará el humano

En un celular con Android 11 o anterior (si hay uno): con la ubicación apagada
la app lo avisa. En la app Docente, Ajustes → Apps → permisos: no aparece la
cámara.
