# Brief R1-E · Inscripción por Bluetooth: sin solicitudes duplicadas ni pantallas colgadas

- **Rama:** `fix/inscripcion-ble` · **Worktree:** `../worktrees/fix-inscripcion-ble`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md`,
  `docs/especificaciones/oleada-2-inscripcion.md` (secciones 3 a 6),
  `lib/data/services/enrollment_client_service.dart` (completo),
  `lib/data/services/enrollment_host_service.dart` (completo),
  `lib/features/teacher/enrollment_host_screen.dart` (completo),
  `lib/core/crypto/enrollment_crypto.dart` (`EnrollmentKeyPair`; no lo edites),
  `lib/data/services/first_run_store.dart` (modelo de almacén con
  shared_preferences; no lo edites), `test/enrollment_flow_test.dart`.
- **Objetivo:** que un estudiante que repite la solicitud no aparezca dos veces
  ni le salga «Reemplazar celular», y que ningún error deje una pantalla
  esperando para siempre.

## Archivos permitidos

- `lib/data/services/enrollment_key_store.dart` (**nuevo**)
- `lib/data/services/enrollment_client_service.dart`
- `lib/data/services/enrollment_host_service.dart`
- `lib/features/teacher/enrollment_host_screen.dart`
- `test/inscripcion_correcciones_test.dart` (**nuevo**)
- `test/enrollment_flow_test.dart`, `test/ui/inscripcion_pantallas_test.dart`
  (solo si una comprobación choca con un arreglo; dilo)

## Fallos a corregir

1. **Cada solicitud usa claves nuevas.** `EnrollmentClientService._run`
   (~línea 157) genera un par de claves en cada intento, así que el docente no
   reconoce al mismo celular (el filtro por `publicKeyHex` del host, ~línea 321,
   y `deviceKeyId == keyId`, ~línea 327, nunca se cumplen al reintentar).
   Casos: quien quedó vinculado pero no oyó el «aceptado» ve «Reemplazar
   celular» al reintentar; quien no está en la lista y reintenta sale dos veces
   en «Por aprobar». **Arreglo:**
   - Archivo nuevo `enrollment_key_store.dart`, al estilo de `first_run_store.dart`:
     `abstract class EnrollmentKeyStore { Future<EnrollmentKeyPair?> load(String courseId, String studentCode); Future<void> save(String courseId, String studentCode, EnrollmentKeyPair pair); }`,
     `PrefsEnrollmentKeyStore` (shared_preferences, clave
     `enrollment_keypair_v1_<courseId>_<studentCode>`, guarda las dos claves en
     hex) y `MemoryEnrollmentKeyStore`. Si shared_preferences falla (por
     ejemplo en pruebas), `load` devuelve `null` y `save` no hace nada, ambos
     con `debugPrint` del error.
   - `EnrollmentClientService` recibe `EnrollmentKeyStore? keyStore` (opcional;
     por defecto `const PrefsEnrollmentKeyStore()` o equivalente) y reutiliza
     el par guardado para esa clase y ese código; si no hay, lo genera y lo guarda.
2. **Solicitudes en espera duplicadas o vencidas** (host):
   - Al llegar una solicitud nueva, quita de `_pending` (y de `_decisions`) las
     anteriores con el **mismo `studentCode`**, aunque la clave sea distinta.
   - Las solicitudes en espera vencen: agrega `Duration pendingTtl` al
     constructor (por defecto 90 s, un poco más que la espera de 60 s del
     estudiante) y un reloj opcional si no existe ya. Quita las vencidas al
     llegar una solicitud y en cada tic del temporizador de respuestas, y
     emite el estado nuevo para que la tarjeta desaparezca.
   - `approve` de una solicitud vencida lanza `StateError('La solicitud ya no está disponible.')`
     como hoy (no vincules una clave muerta).
3. **Dos «Agregar» al mismo tiempo** (`approve`, ~líneas 187-224): los dos
   calculan la misma casilla libre; el segundo falla con un mensaje genérico y
   su tarjeta se queda. **Arreglo:** ejecuta `approve` y `reject` de a uno (una
   cola de `Future`). Antes de insertar, si ya existe un estudiante con ese
   código en la clase, lanza `StateError('Ese código ya está en la clase.')` y
   quita la solicitud.
4. **Arranque y parada del host** (~líneas 154-170):
   - `_running` se pone en `true` al final de `start()`: si `startScan` falla,
     queda abierta `_subscription` y `stop()` no hace nada. **Arreglo:** marca
     el arranque al principio; si algo falla, limpia (cancela suscripción y
     temporizador, `_running = false`) y relanza. `stop()` limpia aunque el
     arranque haya quedado a medias.
   - En la pantalla, «Volver a intentar» (~línea 195) vuelve a suscribir
     `_stateSub`, `_issueSub` y los paquetes sin cancelar los anteriores
     (~líneas 75-80): cancélalos antes.
   - Si la pantalla se cierra mientras `start()` sigue en curso, al terminar
     queda vivo el temporizador: después del `await` de `start()`, si la
     pantalla ya no está montada, llama a `stop()`.
5. **Errores asíncronos sin capturar:**
   - Cliente (~línea 249): si `upsertStudentEnrollment` lanza, la pantalla se
     queda en «Buscando» para siempre. **Arreglo:** captúralo, emite un error
     en el stream (`addError`) y cierra el flujo; la pantalla del estudiante ya
     muestra un error cuando el stream falla (compruébalo leyendo
     `student_qr_enrollment_screen.dart`; **no la edites**; si no lo maneja,
     dilo en tu respuesta).
   - Host (~línea 298): los errores de `_handleRequest` no se capturan.
     **Arreglo:** captúralos con `debugPrint` sin cortar la escucha.
6. **Aviso de clase llena** (`enrollment_host_screen.dart` ~línea 172): cuenta
   solo activos, pero el cupo de 64 incluye a los retirados (conservan su
   casilla). **Arreglo:** cuenta con `getAllStudentsByCourse`.

## Criterios de aceptación (además de los comunes)

Prueba nueva `test/inscripcion_correcciones_test.dart` (usa el aire falso como
`test/enrollment_flow_test.dart`):

- [ ] Con `MemoryEnrollmentKeyStore`, dos solicitudes seguidas del mismo
      estudiante para la misma clase usan la **misma** clave pública.
- [ ] Estudiante de la lista ya vinculado con esa clave que vuelve a pedir:
      queda aceptado sin pasar a «Reemplazar celular».
- [ ] Estudiante fuera de la lista que pide dos veces (claves distintas):
      el host tiene **una** sola solicitud en espera.
- [ ] Una solicitud en espera desaparece después de `pendingTtl` (reloj falso)
      y `approve` sobre ella lanza `StateError`.
- [ ] Dos `approve` simultáneos de solicitudes distintas terminan con dos
      estudiantes en casillas distintas.
- [ ] `start()` con un `startScan` que lanza: relanza y luego `stop()` deja
      todo limpio (sin suscripción activa).
- [ ] Pasan: `flutter test test/inscripcion_correcciones_test.dart`,
      `flutter test test/enrollment_flow_test.dart`,
      `flutter test test/student_enrollment_service_test.dart`,
      `flutter test test/ui/inscripcion_pantallas_test.dart`.

## Qué probará el humano

Inscribir un estudiante, cancelar a mitad y volver a intentar: no sale dos
veces ni le pide reemplazar el celular.
