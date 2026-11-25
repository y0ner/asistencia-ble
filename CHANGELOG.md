# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-25

### Added
- Serverless, offline proximity attendance tracking via Bluetooth Low Energy (BLE Legacy advertising, 16-byte packets).
- Student attendance beacon with rotating HMAC-SHA256 token (30-second window).
- Teacher echo beacon with 8-byte bitmap (64 student positions) re-broadcasted every second.
- Proximity detection with customizable RSSI threshold (-75 dBm default).
- First-day optical enrollment flow using QR code, X25519 key exchange, and HKDF-SHA256 device secret derivation.
- Course roster ingestion: direct import from Excel (.xlsx) and CSV (.csv), clipboard batch pasting, and manual student entry.
- Inverted exception roll call for students without a smartphone or with exhausted batteries (zero exclusion).
- Official 4-sheet Excel (.xlsx) report generation (Resumen, Detalle, Sesiones, Metadatos) and cryptographically signed session minutes.
- Native sheet export and file sharing via `share_plus`.
- Optional asynchronous cloud sync with Google Sheets and Google Drive using the instructor's Google account.
- Two distinct application flavors from a single Flutter codebase:
  - AsistenciaBLE Docente (`co.edu.uniguajira.asistencia_uniguajira.docente`)
  - AsistenciaBLE Estudiante (`co.edu.uniguajira.asistencia_uniguajira.estudiante`)
- Animated onboarding walkthrough and comprehensive help center with 13 custom animated vector scenes.
- Interactive permission diagnostics for Bluetooth, Location, and Camera.
- Fully offline-first local persistence powered by SQLite (`sqflite`, schema version 4).
- Custom design system with light and dark mode support, Figtree typography, and accessible touch targets (min 44x44 dp).

### Changed
- Project rebranded to **AsistenciaBLE** to serve higher education institutions generally.
- Institutional identity (University of La Guajira shield and `@uniguajira.edu.co` domain restriction) moved to dedicated pilot build profile (`INSTITUCION=uniguajira`).
- Licensed under the Apache License 2.0 (`LICENSE`).

### Fixed
- The "Signed session" sheet showed the closing time in UTC and could show the next day's date (a class at 10:42 p.m. on Friday appeared as "Saturday 5:42 a.m."); it now shows the session start in local time, matching "Recent sessions".
- Remaining old app names ("Asistencia Estudiante/Docente") in the enrollment QR instructions, the help walkthrough and the app titles.
- Demo data now uses fictitious names, emails and student codes instead of real people's data.
