# Contribuir a AsistenciaBLE

¡Gracias por tu interés en contribuir a AsistenciaBLE! Este documento describe el flujo de desarrollo, el modelo de ramas, los estándares de código y las políticas de colaboración del proyecto.

---

## 1. Modelo de ramas y flujo de trabajo

El proyecto sigue una estrategia estructurada de ramas y revisiones:

- **`main`**: Rama de producción estable. Solo recibe código desde `dev` cuando una versión u oleada ha sido completamente probada y aprobada en **2 dispositivos Android físicos reales**.
- **`dev`**: Rama principal de desarrollo e integración activa. Todos los Pull Requests apuntan a `dev`.
- **Ramas de trabajo (`feat/*`, `fix/*`, `docs/*`)**:
  - Se ramifican siempre desde `dev`.
  - Se trabajan en aislamiento (preferiblemente en *worktrees* de Git).
  - Una tarea = una rama = un Pull Request.
  - No se realiza `push` directo ni `merge` a `dev` sin revisión.

---

## 2. Requisitos previos y compilación

### Requisitos del entorno
- **Flutter SDK:** 3.47.1 o compatible (Dart 3.13+).
- **JDK:** JDK 17 (o el JBR incluido con Android Studio).
- **Android SDK:** `minSdkVersion 24` (Android 7.0+). 
- **Dispositivos:** Teléfonos Android compatibles con Bluetooth Low Energy y modo periférico (BLE Advertising).

### Comandos de desarrollo (`./run.sh`)
El repositorio incluye un script centralizado `run.sh` para facilitar las tareas de desarrollo y compilación:

```bash
# Ejecutar la app del Docente en un dispositivo Android o Linux
./run.sh docente [dispositivo]

# Ejecutar la app del Estudiante en un dispositivo Android o Linux
./run.sh estudiante [dispositivo]

# Compilar APK Release del Docente
./run.sh apk-docente

# Compilar APK Release del Estudiante
./run.sh apk-estudiante

# Compilar ambos APKs Release (Docente y Estudiante)
./run.sh build-apk    # o también: ./run.sh apk

# Ejecutar análisis estático con el linter oficial
./run.sh analyze

# Ejecutar suite de pruebas unitarias y de integración
./run.sh test
```

### Perfiles de compilación
- **Perfil general (predeterminado):** Marca neutra para cualquier institución de educación superior.
- **Perfil piloto institucional:** Compila con el escudo y la restricción de dominio institucional de la prueba piloto:
  ```bash
  INSTITUCION=uniguajira ./run.sh apk
  ```

---

## 3. Política de commits

- Los mensajes de confirmación (*commits*) deben redactarse en **español**, con descripciones claras y atómicas.
- Utiliza la convención de prefijos semánticos:
  - `feat(módulo): ...` para nuevas funcionalidades.
  - `fix(módulo): ...` para correcciones de errores.
  - `docs(módulo): ...` para documentación.
  - `test(módulo): ...` para pruebas unitarias o de integración.
  - `refactor(módulo): ...` para refactorizaciones de código.
  - `chore(módulo): ...` para mantenimiento, licencias o scripts.

---

## 4. Estándares y calidad de código

Antes de enviar un cambio a revisión, asegúrate de cumplir con los siguientes criterios obligatorios:

1. **Código completo e íntegro:**
   - Queda estrictamente prohibido incluir comentarios de tareas incompletas o pendientes, simulaciones o datos falsos quemados en pantallas de producción y excepciones silenciadas (`catch (_) {}`).
2. **Pruebas obligatorias:**
   - Cualquier cambio de lógica de negocio o datos en `lib/core/` o `lib/data/` debe incluir su respectiva prueba automatizada en el directorio `test/`.
   - La suite `./run.sh test` debe finalizar con el 100 % de las pruebas en verde.
3. **Análisis estático:**
   - `./run.sh analyze` (o `flutter analyze --no-pub`) debe reportar **0 errores y 0 advertencias**.
4. **Sistema de diseño:**
   - Todas las pantallas deben construirse utilizando los tokens y componentes del sistema de diseño en `lib/ui/`, respetando los lineamientos de `docs/diseno/SISTEMA.md`.
   - Se prohíbe el uso de colores codificados en duro, fuentes personalizadas no registradas o tamaños de toque menores a 44x44 dp.
5. **Aislamiento de dependencias:**
   - No agregues dependencias a `pubspec.yaml` sin previa consulta y justificación técnica.

---

## 5. Estabilidad del protocolo BLE y Criptografía

El protocolo de asistencia por proximidad BLE y el mecanismo de enrolamiento son el núcleo crítico del sistema:
- Paquetes de anuncio de 16 bytes compatibles con BLE Legacy (límite de 31 bytes).
- Rotación de tokens HMAC-SHA256 cada 30 segundos.
- Eco del docente en mapa de bits de 8 bytes (64 posiciones).
- Intercambio de claves X25519 y derivación HKDF-SHA256 para el enrolamiento óptico/BLE.

**Regla estricta:** No modifiques los formatos de trama, encabezados, flags, temporizadores ni la lógica criptográfica en `lib/core/crypto/` sin una discusión técnica previa y aprobación expresa de los mantenedores del proyecto.
