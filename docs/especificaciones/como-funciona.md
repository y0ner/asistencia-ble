# «Cómo funciona» · ayuda con dibujos en las dos apps

- **Estado:** aprobada por Yoner el 15 de noviembre de 2026 (formato A + C).
- **Diseño de referencia:** lienzo «Asistencia · Cómo funciona» y los SVG de
  `docs/diseno/referencias/como-funciona/`.

## 1. Qué es

Una ayuda **solo informativa**, hecha con dibujos, que explica el flujo
completo. Tiene dos piezas:

1. **Recorrido** (formato A): una pantalla por paso, con dibujo animado, quién
   hace el paso, título, una frase y un consejo. Se muestra **sola una vez**, la
   primera vez que se abre la app (después de los permisos), y se puede saltar.
2. **Centro de ayuda** (formato C): pantalla «Ayuda» con el acceso al
   recorrido, tarjetas por tema, «Bueno saber» y «Si algo falla». Se abre con el
   botón de ayuda del inicio. Cada tema abre un recorrido corto.

## 2. Regla principal: que se sepa quién hace cada cosa

Son dos apps. Cada una explica el flujo **completo** (también lo que hace la
otra persona), pero cada paso dice sin ambigüedad quién lo hace:

| Rótulo | Cuándo | Cómo se ve |
|---|---|---|
| **Lo haces tú** | Lo hace quien usa esta app | Con el estilo del rol de esa persona (ver abajo) |
| **Lo hace el estudiante** / **Lo hace tu profesor** | Lo hace la otra persona | Con el estilo del rol de la otra persona |
| **Pasa solo** | No lo hace nadie | Pastilla ocre |

El estilo depende del **rol**, no de quién mira, igual que en los dibujos:

- **Profesor:** turquesa relleno (celular relleno).
- **Estudiante:** borde oscuro sobre fondo claro (celular con borde).

Así, en la app del docente «Lo haces tú» es turquesa relleno y «Lo hace el
estudiante» lleva borde; en la app del estudiante es al revés.

## 3. Contenido

Los textos viven en `lib/features/shared/how_it_works/how_it_works_content.dart`
(`HowItWorksContent.teacher` y `HowItWorksContent.student`). Las pantallas no
escriben textos propios.

| App | Recorrido | Temas |
|---|---|---|
| Docente | 7 pasos: QR → código → aprobar → PIN → acercar → la lista se marca sola → cerrar y enviar | Inscribir estudiantes, Tomar asistencia, Sin celular, Cerrar y enviar, Cambió de celular, Retirar o eliminar |
| Estudiante | 6 pasos: escanear → código → el profesor dicta el PIN → escribir el PIN → acercar → ¡Presente! | Unirme a una clase, Marcar asistencia, Cambié de celular, Sin celular |

El límite de **64 estudiantes por clase** se explica en «Bueno saber» y en el
último paso del recorrido del docente.

## 4. Dibujos

Trece dibujos (`UiSceneKind`), pintados en un lienzo de 320 × 220 con
`UiSceneCanvas`. Cada uno tiene su archivo `lib/ui/components/scenes/scene_<nombre>.dart`.

Reglas:

- El celular **relleno** es siempre el del profesor; el **con borde**, el del
  estudiante. El **ocre** marca lo que se mueve; el **coral**, quitar o rechazar.
- La animación es **suave** y dura un ciclo de 3,6 s que se repite. `t` va de 0 a 1.
- En reposo (`UiScene.restT` = 0,9) el dibujo se ve **completo**, en su estado
  final. Con «reducir movimiento» se queda en ese cuadro.
- Nada se sale del lienzo ni parpadea bruscamente.

### Animación de cada dibujo

`wave`, `appear`, `bump`, `step` y `mix` son de `UiSceneAnim`.

| Dibujo | Qué se mueve |
|---|---|
| `acercar` (modelo, ya hecho) | Los celulares se acercan 5 px (`wave`) y las ondas laten, primero las de adentro. |
| `qr` | Las dos líneas punteadas «corren» del QR hacia los estudiantes (`dashOffset: -20 * t`). Las esquinas ocres de cada estudiante laten: opacidad `mix(0.45, 1, wave(t, phase: 0.6))` la primera y `phase: 0.35` la segunda. |
| `escanear` | La línea de escaneo sube y baja: grupo con `dy: mix(-22, 22, wave(t, phase: 0.35))`. La línea punteada entre los celulares corre (`dashOffset: -20 * t`). Las esquinas ocres laten: opacidad `mix(0.5, 1, wave(t, phase: 0.6))`. |
| `codigo` | Los cinco puntos del código aparecen uno tras otro: el punto `i` (0 a 4) con opacidad `appear(t, 0.10 + 0.12 * i, 0.16 + 0.12 * i)`. La tecla ocre se hunde con cada punto: escala `mix(1, 0.85, golpe)` alrededor de su centro (160, 135), donde `golpe` es el mayor de `bump(t, 0.13 + 0.12 * i, width: 0.1)`. El cursor parpadea: opacidad 1 si `step(t, 8)` es impar, 0.15 si es par. La línea punteada corre (`dashOffset: -18 * t`). |
| `aprobar` | La tarjeta blanca con todo su contenido entra desde la derecha: grupo con `dx: mix(24, 0, appear(t, 0.05, 0.25))` y opacidad `appear(t, 0.05, 0.2)`. El visto turquesa late una vez: escala `mix(1, 1.18, bump(t, 0.55, width: 0.2))` alrededor de (246, 130). |
| `pin` | El globo con «4 7» aparece: grupo con escala `mix(0.9, 1, appear(t, 0.05, 0.2))` alrededor de (228, 104) y opacidad `appear(t, 0.05, 0.18)`. Las dos ondas de voz laten: la pequeña con opacidad `mix(0.35, 1, wave(t, phase: 0.6))` y la grande con `mix(0.25, 0.8, wave(t, phase: 0.35))`. |
| `teclado` | El «4» de la primera casilla aparece: opacidad `appear(t, 0.2, 0.28)`. La tecla ocre se hunde: escala `mix(1, 0.85, bump(t, 0.22, width: 0.14))` alrededor de (177, 153). El cursor de la segunda casilla parpadea igual que en `codigo`. Las ondas de voz laten igual que en `pin`. |
| `listo` | El círculo turquesa crece: escala `mix(0.6, 1, appear(t, 0.05, 0.25))` alrededor de (160, 88). El visto se escribe: `progress: appear(t, 0.2, 0.4)`. Los rayos ocres laten: opacidad `mix(0.25, 1, wave(t, phase: 0.6))`. |
| `presente` | El arco del anillo se llena: `progress: appear(t, 0.1, 0.6)`. El visto del centro se escribe: `progress: appear(t, 0.55, 0.75)`. El visto de la primera fila (círculo y trazo) aparece con opacidad `appear(t, 0.10, 0.20)` y el de la segunda con `appear(t, 0.35, 0.45)`. La tercera fila sigue pendiente. |
| `amano` | La mano (palma, dedo y el parche que los une) llega: grupo con `dx: mix(14, 0, appear(t, 0.1, 0.3))`. El aro ocre late al tocar: radio `mix(15, 21, bump(t, 0.38, width: 0.2))` y opacidad `mix(1, 0.4, bump(t, 0.38, width: 0.2))`. Después del toque la fila del medio queda marcada: encima del círculo punteado se pinta un círculo `UiScenePalette.paperTeal` de radio 8 en (124, 103) con su visto `M120 103 l3 3 l5 -6` (`UiScenePalette.paper`, grosor 2.4), ambos con opacidad `appear(t, 0.4, 0.5)`. |
| `excel` | El sello de abajo (círculo turquesa) aparece con opacidad `appear(t, 0.1, 0.2)` y su visto se escribe: `progress: appear(t, 0.15, 0.35)`. El botón ocre de enviar (círculo y flecha) da un saltito hacia arriba a la derecha: grupo con `dx: 4 * bump(t, 0.6, width: 0.3)` y `dy: -4 * bump(t, 0.6, width: 0.3)`. |
| `cambio` | El celular anterior (borde punteado, círculo coral, raya y barra) se atenúa: grupo con opacidad `mix(1, 0.5, appear(t, 0.1, 0.4))`. La flecha ocre se mece: grupo con `dx: mix(-4, 4, wave(t, phase: 0.35))`. El visto del celular nuevo: el círculo crece con escala `mix(0.7, 1, appear(t, 0.3, 0.5))` alrededor de (234, 98) y el trazo se escribe con `progress: appear(t, 0.4, 0.6)`. |
| `retirar` | La insignia coral con el signo menos late una vez: escala `mix(1, 1.2, bump(t, 0.3, width: 0.2))` alrededor de (236, 110). Luego la fila del medio (rectángulo, avatar, barra e insignia) se va: grupo con `dx: mix(0, 26, appear(t, 0.45, 0.7))` y opacidad `mix(1, 0.35, appear(t, 0.45, 0.7))`. |

## 5. Pantallas

### Recorrido (`HowItWorksTourScreen`)

- Arriba: en la primera apertura, el título pequeño y «Saltar»; si no, barra
  normal con volver. Debajo, una barra de progreso con un tramo por paso: ocre
  los de «una sola vez», turquesa los de «en cada clase», con un espacio mayor
  entre los dos grupos.
- Cada paso: pastilla de momento («Una sola vez · Inscribir»), dibujo, rótulo
  de quién lo hace + «Paso 2 de 7», título, texto y consejo.
- Abajo: «Atrás» y «Siguiente»; en el último paso, «Entendido».
- Se puede deslizar entre pasos.

### Centro de ayuda (`HelpCenterScreen`)

- Tarjeta destacada «¿Primera vez?» con «Ver el recorrido».
- «Temas» en cuadrícula de dos columnas (una columna con letra grande).
- «Bueno saber» y «Si algo falla» (incluye «Permisos del celular», que abre
  el diagnóstico que ya existe).

### Dónde aparece

- **Primera apertura:** permisos → recorrido → inicio. Se recuerda con
  `FirstRunStore` (preferencias del celular).
- **Después:** botón «Ayuda» (signo de interrogación) en el encabezado del
  inicio de las dos apps. Reemplaza al botón de diagnóstico, que ahora se abre
  desde «Permisos del celular» en la ayuda.

## 6. Plan de trabajo

| Encargo | Qué | Quién |
|---|---|---|
| Base | Lienzo de dibujo, dibujos quietos, textos, pantallas vacías, recuerdo de primera apertura | Agente jefe |
| H1-A | Animar `qr`, `escanear`, `codigo`, `aprobar`, `cambio`, `retirar` | Gemini |
| H1-B | Animar `pin`, `teclado`, `listo`, `presente`, `amano`, `excel` | Gemini |
| H1-C | Pantalla del recorrido | Gemini |
| H1-D | Pantalla del centro de ayuda | Gemini |
| H1-E | Primera apertura y botón de ayuda en las dos apps | Gemini |
