# Reglas comunes de la Oleada R1 (corrección de fallos)

Aplican a todos los briefs `R1-*`, además de `AGENTS.md`.

Esta oleada **corrige fallos encontrados en una revisión de código**. No es
una oleada de diseño: no cambies pantallas, textos ni comportamientos que tu
brief no nombre.

1. **Lee primero, completos,** los archivos que cite tu brief. Antes de
   cambiar una función, lee quién la llama (`grep -rn`).
2. **Toca solo tus «Archivos permitidos».** Otros agentes corrigen otros
   archivos en paralelo. Si crees que hace falta tocar otro archivo, **no lo
   hagas**: explícalo en tu respuesta final.
3. **No cambies firmas públicas** (constructores, nombres o parámetros de
   métodos públicos) salvo que tu brief lo pida. Puedes **agregar** parámetros
   opcionales con valor por defecto.
4. **Nada de trampas:** no silencies errores (`catch (_) {}`; si capturas, usa
   `debugPrint` o repórtalo), no dejes `TODO` ni código simulado, no debilites
   ni borres comprobaciones de pruebas existentes. Si una prueba existente
   contradice el arreglo que pide tu brief, cámbiala lo mínimo y dilo en tu
   respuesta.
5. **Textos visibles en español,** cortos y en el tono de la app (tuteo, sin
   tecnicismos). Colores y tamaños solo con tokens (`UiColors.of(context)`,
   `UiSpace`, `UiText`…).
6. **No formatees archivos enteros** (`dart format` no). El diff debe mostrar
   solo tu cambio.
7. **Comandos permitidos:** `flutter analyze --no-pub` y
   `flutter test <archivo>` **solo** con los archivos de prueba que nombra tu
   brief, uno por vez. Si una prueba tarda, espera a que termine.
8. **Pruebas nuevas:** cada arreglo lleva al menos una prueba que **fallaría
   sin el arreglo**. Nómbralas en español, describiendo el escenario.
9. **Commits** pequeños, uno por arreglo, con mensaje en español
   (`fix(radar): …`).

## Criterios comunes de aceptación

- [ ] `git diff --stat dev` muestra solo tus archivos permitidos.
- [ ] `grep -nE "TODO|catch \(_\)" <tus archivos>` no devuelve nada nuevo.
- [ ] `flutter analyze --no-pub` sin problemas.
- [ ] Los archivos de prueba que nombra tu brief pasan.
