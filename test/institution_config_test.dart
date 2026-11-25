import 'package:asistencia_uniguajira/core/config/institution_config.dart';
import 'package:asistencia_uniguajira/data/services/cloud_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstitutionConfig y perfiles institucionales', () {
    test('byId retorna el perfil correspondiente o general por defecto', () {
      expect(InstitutionConfig.byId('general').id, 'general');
      expect(InstitutionConfig.byId('general').appName, 'AsistenciaBLE');
      expect(
        InstitutionConfig.byId('general').headerSubtitle,
        'Asistencia por proximidad',
      );
      expect(InstitutionConfig.byId('general').emailDomain, isNull);
      expect(
        InstitutionConfig.byId('general').emblemAsset,
        'assets/brand/asistenciable_icono.png',
      );
      expect(
        InstitutionConfig.byId('general').emblemSemanticLabel,
        'Ícono de AsistenciaBLE',
      );

      expect(InstitutionConfig.byId('uniguajira').id, 'uniguajira');
      expect(InstitutionConfig.byId('uniguajira').appName, 'AsistenciaBLE');
      expect(
        InstitutionConfig.byId('uniguajira').headerSubtitle,
        'Universidad de La Guajira',
      );
      expect(
        InstitutionConfig.byId('uniguajira').emailDomain,
        '@uniguajira.edu.co',
      );
      expect(
        InstitutionConfig.byId('uniguajira').emblemAsset,
        'assets/brand/escudo_uniguajira.png',
      );
      expect(
        InstitutionConfig.byId('uniguajira').emblemSemanticLabel,
        'Escudo de la Universidad de La Guajira',
      );

      // IDs desconocidos devuelven el perfil general
      expect(InstitutionConfig.byId('desconocido').id, 'general');
      expect(InstitutionConfig.byId('').id, 'general');
      expect(InstitutionConfig.byId('otro').id, 'general');
    });

    test(
      'Perfil general acepta correos válidos y rechaza malformados',
      () {
        final generalSync = CloudSyncService(
          institution: InstitutionConfig.general,
        );

        // Acepta correos válidos con cualquier dominio estructurado
        expect(
          generalSync.isValidInstitutionalEmail('ana.perez@gmail.com'),
          isTrue,
        );
        expect(
          generalSync.isValidInstitutionalEmail('docente@cualquiera.edu.co'),
          isTrue,
        );

        // Rechaza formatos inválidos según las reglas
        expect(generalSync.isValidInstitutionalEmail('sin-arroba'), isFalse);
        expect(generalSync.isValidInstitutionalEmail('a@b'), isFalse);
        expect(generalSync.isValidInstitutionalEmail('.a@x.co'), isFalse);
        expect(generalSync.isValidInstitutionalEmail('a..b@x.co'), isFalse);
        expect(generalSync.isValidInstitutionalEmail('a b@x.co'), isFalse);
        expect(generalSync.isValidInstitutionalEmail('a@@x.co'), isFalse);
      },
    );

    test('Perfil uniguajira exige dominio exacto y rechaza correos externos', () {
      final uniguajiraSync = CloudSyncService(
        institution: InstitutionConfig.uniguajira,
      );

      expect(
        uniguajiraSync.isValidInstitutionalEmail('docente@uniguajira.edu.co'),
        isTrue,
      );
      expect(
        uniguajiraSync.isValidInstitutionalEmail('docente@gmail.com'),
        isFalse,
      );
    });
  });
}
