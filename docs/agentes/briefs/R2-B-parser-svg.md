# Brief R2-B · Parser de trazos SVG de los dibujos: comandos que faltan y caché

- **Rama:** `fix/parser-svg` · **Worktree:** `../worktrees/fix-parser-svg`
- **Lee primero:** `AGENTS.md`, `docs/agentes/briefs/R1-comun.md` (valen igual
  para R2), `lib/ui/components/scenes/ui_scene_canvas.dart` (completo,
  sobre todo `parseSvgPath`, `svgPathLength` y `UiSceneCanvas.path`) y
  `test/ui/escena_base_test.dart`.
- **Objetivo:** que el parser acepte cualquier trazo SVG válido de los que
  exportan Figma o svgo y que no vuelva a parsear el mismo trazo en cada cuadro
  de la animación.

## Archivos permitidos

- `lib/ui/components/scenes/ui_scene_canvas.dart` (**solo** `parseSvgPath`,
  `svgPathLength`, la expresión `_svgNumber` y la caché nueva; no cambies la API
  de `UiSceneCanvas`)
- `test/ui/escena_base_test.dart` (agrega pruebas; no quites ninguna)

## Fallos a corregir

1. **Faltan `S/s` y `T/t`.** Hoy lanzan `FormatException('Comando SVG no admitido')`.
   **Arreglo:**
   - `S`: cúbica suave. El primer punto de control es el reflejo del segundo
     control de la `C`/`S` anterior respecto al punto actual; si el comando
     anterior no fue `C`/`S`, es el punto actual.
   - `T`: cuadrática suave, con la misma regla de reflejo usando el control
     de la `Q`/`T` anterior.
   - Guarda el último punto de control y el último comando para poder reflejar.
2. **Banderas de arco compactas.** En `A`, las banderas *large-arc* y *sweep*
   son **un solo carácter** `0` o `1` y pueden ir pegadas entre sí y al número
   siguiente. Ejemplo: `a16 16 0 0116 16` = rx 16, ry 16, rotación 0, large 0,
   sweep 1, x 16, y 16. Hoy se leen como números y se rompe. **Arreglo:** lee
   cada bandera como un carácter `0`/`1` (saltando separadores antes); si no
   es `0` ni `1`, `FormatException`.
3. **Números pegados.** Comprueba que `_svgNumber` acepte `1.5.5` como `1.5` y
   `.5`, `10-5` como `10` y `-5`, y exponentes (`1e-3`, `2E2`). Ajústala si no.
4. **Caché.** `UiSceneCanvas.path` llama a `parseSvgPath(d)` en cada cuadro
   (60 por segundo y por dibujo). **Arreglo:** caché de `Path` por cadena `d`
   (un `Map` con tope, p. ej. 256 entradas; al pasarse, vacíala o quita la más
   vieja). Garantiza que nadie pueda modificar el `Path` guardado: si algún
   llamador lo transforma o le agrega figuras, entrégale una copia
   (`Path.from`). `svgPathLength` usa la misma caché.

## Criterios de aceptación (además de los comunes)

En `test/ui/escena_base_test.dart` (grupo nuevo):

- [ ] `M0 0 C10 0 20 10 20 20 S30 40 40 40` no lanza y su longitud es la
      misma que la de la ruta equivalente escrita con dos `C` explícitas (calcula
      tú el reflejo: `S30 40 40 40` equivale a `C20 30 30 40 40 40`).
- [ ] `M0 0 Q10 0 10 10 T20 20` equivale a `M0 0 Q10 0 10 10 Q10 20 20 20`.
- [ ] `M0 0 a16 16 0 0116 16` equivale a `M0 0 a16 16 0 0 1 16 16`.
- [ ] `M0 0L1.5.5` termina en (2, 0.5) y `M10-5L20-5` es válido.
- [ ] Llamar dos veces `parseSvgPath` con el mismo `d` no vuelve a parsear (o,
      si no puedes observarlo sin cambiar la API, que modificar el `Path`
      devuelto no altere el resultado de la siguiente llamada).
- [ ] Los 13 dibujos siguen idénticos: pasan
      `flutter test test/ui/escena_base_test.dart`,
      `flutter test test/ui/escenas_inscripcion_test.dart` y
      `flutter test test/ui/escenas_asistencia_test.dart`.

## Qué probará el humano

Abrir «Ayuda» y el recorrido: los dibujos se ven y se mueven igual que antes.
