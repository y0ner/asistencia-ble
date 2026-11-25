import 'package:flutter/foundation.dart';

/// Perfil institucional configurable para la marca, encabezados y dominios de correo.
@immutable
class InstitutionProfile {
  /// Crea un perfil institucional inmutable.
  const InstitutionProfile({
    required this.id,
    required this.appName,
    required this.headerSubtitle,
    required this.institutionName,
    required this.emailDomain,
    required this.emblemAsset,
    required this.emblemSemanticLabel,
  });

  /// Identificador único del perfil ('general' | 'uniguajira').
  final String id;

  /// Nombre de la aplicación ('AsistenciaBLE').
  final String appName;

  /// Texto bajo el nombre en el encabezado institucional.
  final String headerSubtitle;

  /// Nombre de la institución en los reportes oficiales (hoja Metadatos).
  final String institutionName;

  /// Dominio de correo institucional requerido o `null` si admite cualquier correo válido.
  final String? emailDomain;

  /// Ruta del asset con el emblema o ícono institucional.
  final String emblemAsset;

  /// Etiqueta semántica de accesibilidad del emblema.
  final String emblemSemanticLabel;
}

/// Proveedor de configuración institucional de AsistenciaBLE.
abstract final class InstitutionConfig {
  /// Perfil institucional general para cualquier institución de educación superior.
  static const InstitutionProfile general = InstitutionProfile(
    id: 'general',
    appName: 'AsistenciaBLE',
    headerSubtitle: 'Asistencia por proximidad',
    institutionName: 'Institución de Educación Superior',
    emailDomain: null,
    emblemAsset: 'assets/brand/asistenciable_icono.png',
    emblemSemanticLabel: 'Ícono de AsistenciaBLE',
  );

  /// Perfil institucional piloto para la Universidad de La Guajira.
  static const InstitutionProfile uniguajira = InstitutionProfile(
    id: 'uniguajira',
    appName: 'AsistenciaBLE',
    headerSubtitle: 'Universidad de La Guajira',
    institutionName: 'Universidad de La Guajira',
    emailDomain: '@uniguajira.edu.co',
    emblemAsset: 'assets/brand/escudo_uniguajira.png',
    emblemSemanticLabel: 'Escudo de la Universidad de La Guajira',
  );

  /// Identificador del perfil seleccionado al compilar (`--dart-define=INSTITUCION=...`).
  static const String selectedId = String.fromEnvironment(
    'INSTITUCION',
    defaultValue: 'general',
  );

  /// Retorna el perfil correspondiente a [id], o [general] si no coincide.
  static InstitutionProfile byId(String id) =>
      id == 'uniguajira' ? uniguajira : general;

  /// Perfil institucional vigente según la compilación.
  static InstitutionProfile get current => byId(selectedId);
}
