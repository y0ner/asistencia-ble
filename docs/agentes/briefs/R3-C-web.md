# Brief R3-C · Página web estática de AsistenciaBLE (para Vercel)

- **Rama:** `feat/web` · **Worktree:** `~/Desktop/Projects/worktrees/asistencia-feat-web` · **Base:** `release/v1.0.0`
- **Lee primero:** `AGENTS.md`, `README.md` y `README.es.md` (fuente de **todos** los
  textos y datos), `docs/diseno/SISTEMA.md` y `lib/ui/tokens/ui_colors.dart` (colores
  claro/oscuro), `docs/especificaciones/como-funciona.md` y los SVG de
  `docs/diseno/referencias/como-funciona/` (dibujos que puedes reutilizar).
- **Ejemplo terminado para imitar estructura y calidad (solo lectura, no copiar
  textos):** `/home/yoner/Desktop/Projects/folio/website/index.html`.
- **Objetivo:** una landing de una sola página, en `website/`, con la identidad de
  la app, clara/oscura y bilingüe ES/EN, lista para `vercel deploy`.

## Archivos permitidos (todos **nuevos**)

- `website/index.html` (HTML + CSS + JS en el mismo archivo, sin frameworks ni CDN)
- `website/vercel.json`, `website/.gitignore`
- `website/fonts/Figtree-*.ttf` (cópialas de `assets/fonts/`, solo los pesos que uses) y `website/fonts/OFL.txt`
- `website/img/*.svg` (dibujos copiados/adaptados de `docs/diseno/referencias/como-funciona/`)
- **No** crees los `.png`/`.webp`: el jefe pone `website/img/icon.png`, `favicon.png`,
  `og.png`, `s1.webp … s8.webp` (capturas, 540 px de ancho, 1080×2400 a escala:
  540×1200) y `d1.webp`, `d2.webp` (capturas en oscuro). Enlázalos igual.

Orden de capturas: s1 inicio del docente · s2 sesión en vivo del docente · s3
estudiante marcando · s4 «¡Presente!» · s5 inscripción por QR · s6 cierre/reporte ·
s7 ayuda · s8 inicio del docente en oscuro. d1 sesión en vivo (oscuro), d2 estudiante (oscuro).

## Qué hacer

1. **Identidad:** colores de `ui_colors.dart` (turquesa `primary`, ocre de
   «a mano», coral de «falta», fondos y tinta de claro y oscuro) como variables CSS
   en `:root` y bajo `@media (prefers-color-scheme: dark)` + `[data-theme=dark]`
   con un botón de tema. Tipografía Figtree con `@font-face` local. Tarjetas
   redondeadas y frases cortas como en `SISTEMA.md` §1-2 (tuteo, sin tecnicismos
   en los titulares; los detalles técnicos van en una sección propia).
2. **Idiomas:** diccionario JS `{es:{…}, en:{…}}` con atributos `data-i18n`;
   español por defecto, botón ES/EN, recuerda la elección en `localStorage`
   (envuelto en `try/catch`) y cambia `<html lang>`.
3. **Secciones** (en este orden):
   - Navegación fija: ícono + «AsistenciaBLE», anclas, ES/EN, tema, botón «Descargar».
   - Héroe: frase («Pasa lista en segundos, sin internet y sin servidor»), subfrase,
     dos CTA: «Descargar app del docente» y «Descargar app del estudiante» (enlaces
     directos de la release) + «Código fuente»; meta: Android 7.0+, `{{APK_SIZE_MB}}` MB,
     sin internet, Apache-2.0; dos capturas inclinadas (s1 y s4).
   - «Cómo funciona»: dos bloques, «Una sola vez · Inscribir» (QR → código →
     aprobar) y «En cada clase» (PIN → acercar → ¡Presente!), con los SVG
     reutilizados y el rótulo de quién hace cada paso (docente/estudiante) como
     en `como-funciona.md` §2.
   - Funciones: cuadrícula de tarjetas (importar lista, inscripción por QR,
     proximidad Bluetooth, lista invertida a un toque, acta firmada y Excel de 4
     hojas, respaldo opcional en Google, ayuda con dibujos, sin internet en clase).
   - Franja oscura «Por dentro» con los datos técnicos verificados del README
     (etiqueta HMAC-SHA256 que rota cada 30 s, paquetes de 16 bytes, eco con mapa
     de bits de 64 posiciones cada segundo, umbral RSSI −75 dBm, X25519 + HKDF al
     inscribir, hasta 64 estudiantes por clase) y las capturas d1 y d2.
   - Galería con s1…s8 (desplazamiento horizontal con scroll-snap en celular).
   - Privacidad: sin servidor, sin rastreo, datos en el celular, Google solo si el
     docente lo activa, permisos y para qué sirve cada uno.
   - Proyecto académico: título del proyecto, autores, director, programa,
     Universidad de La Guajira (piloto), «no es una app oficial de la universidad».
   - Ficha de descarga: versión 1.0.0, fecha 25 nov 2026, tamaño `{{APK_SIZE_MB}}` MB,
     Android 7.0+ con Bluetooth LE, licencia Apache-2.0, huella SHA-256 del
     certificado (la del README) con botón «Copiar» (`navigator.clipboard` con
     `try/catch` y mensaje «Copiado»), dos botones de descarga.
   - Pie: GitHub, Releases, Changelog, licencia, créditos de Figtree (OFL).
4. **Enlaces exactos:**
   `https://github.com/y0ner/asistencia-ble/releases/latest/download/asistenciable-docente-v1.0.0-arm64.apk`,
   `…/asistenciable-estudiante-v1.0.0-arm64.apk`, repo `https://github.com/y0ner/asistencia-ble`.
5. **`<head>` completo:** doctype, `lang="es"`, charset, viewport, `<title>AsistenciaBLE</title>`,
   `description`, `theme-color` (claro y oscuro), favicon `img/favicon.png`,
   `og:title`, `og:description`, `og:type`, `og:url` = `https://asistencia-ble.vercel.app/`,
   `og:image` = `https://asistencia-ble.vercel.app/img/og.png` (URL **absoluta**),
   `twitter:card` = `summary_large_image`.
6. **Responsive:** sin desplazamiento horizontal a 360 px; margen lateral de 16 px en
   celular; imágenes con `width`/`height` y `loading="lazy"` (menos las del héroe);
   respeta `prefers-reduced-motion`.
7. `website/vercel.json`: `{"cleanUrls": true, "headers": [caché de 1 año inmutable para "/img/(.*)" y "/fonts/(.*)"]}`.
   `website/.gitignore`: `.vercel` y `.env*`.

## Criterios de aceptación

- [ ] `git diff --stat release/v1.0.0` solo muestra `website/`.
- [ ] `grep -c "data-i18n" website/index.html` ≥ 60, y cada clave existe en `es` y en `en`.
- [ ] `grep -n "http" website/index.html` solo muestra enlaces de github.com, asistencia-ble.vercel.app, shields/ninguno de CDN (sin `<script src=http…>` ni Google Fonts).
- [ ] `grep -c "{{APK_SIZE_MB}}" website/index.html` ≥ 2.
- [ ] Ningún dato que no esté en el README. Sin `TODO` ni lorem.
- [ ] HTML válido: abre y cierra todas las etiquetas; sin errores en la consola (revisa el JS a mano).
