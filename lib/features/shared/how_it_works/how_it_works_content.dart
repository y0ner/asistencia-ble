import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Quién hace un paso. Es lo que más importa dejar claro en la ayuda.
enum HowActor {
  /// La persona que usa esta app.
  you,

  /// La otra persona (el estudiante en la app del docente y al revés).
  other,

  /// Nadie: ocurre solo.
  auto,
}

/// Momento al que pertenece un paso.
enum HowSection {
  /// Se hace una sola vez por clase.
  once,

  /// Se repite en cada clase.
  everyClass,
}

/// Un paso de la ayuda: un dibujo, quién lo hace y qué se hace.
@immutable
class HowStep {
  const HowStep({
    required this.scene,
    required this.actor,
    required this.title,
    required this.body,
    this.tip,
    this.section,
  });

  final UiSceneKind scene;
  final HowActor actor;
  final String title;
  final String body;

  /// Consejo corto bajo el texto.
  final String? tip;

  /// Nulo en los temas sueltos (p. ej. "Cambió de celular").
  final HowSection? section;
}

/// Un tema del centro de ayuda. Al tocarlo se abre un recorrido con [steps].
@immutable
class HowTopic {
  const HowTopic({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.tone = UiTone.tint,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<HowStep> steps;
  final UiTone tone;
}

/// Un dato de "Bueno saber".
@immutable
class HowFact {
  const HowFact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Todo el contenido de la ayuda de una app. Las pantallas no escriben textos
/// propios: los toman de aquí.
@immutable
class HowItWorksContent {
  const HowItWorksContent({
    required this.studentView,
    required this.otherLabel,
    required this.tourIntro,
    required this.tour,
    required this.topics,
    required this.facts,
    required this.troubleshooting,
  });

  /// `true` en la app del estudiante (cambia los rótulos de los dibujos).
  final bool studentView;

  /// Rótulo de [HowActor.other].
  final String otherLabel;

  /// Frase de la tarjeta que invita al recorrido en el centro de ayuda.
  final String tourIntro;

  /// Recorrido completo que se muestra la primera vez.
  final List<HowStep> tour;
  final List<HowTopic> topics;
  final List<HowFact> facts;

  /// Temas de "Si algo falla".
  final List<HowTopic> troubleshooting;

  static const String screenTitle = 'Cómo funciona';
  static const String helpTitle = 'Ayuda';
  static const String youLabel = 'Lo haces tú';
  static const String autoLabel = 'Pasa solo';
  static const String firstTime = '¿Primera vez?';
  static const String openTour = 'Ver el recorrido';
  static const String topicsTitle = 'Temas';
  static const String factsTitle = 'Bueno saber';
  static const String troubleTitle = 'Si algo falla';
  static const String permissionsTitle = 'Permisos del celular';
  static const String permissionsSubtitle = 'Revisar el Bluetooth y los permisos.';
  static const String skip = 'Saltar';
  static const String back = 'Atrás';
  static const String next = 'Siguiente';
  static const String done = 'Entendido';

  String actorLabel(HowActor actor) {
    return switch (actor) {
      HowActor.you => youLabel,
      HowActor.other => otherLabel,
      HowActor.auto => autoLabel,
    };
  }

  String sectionLabel(HowSection section) {
    return switch (section) {
      HowSection.once => studentView ? 'Una sola vez · Unirte' : 'Una sola vez · Inscribir',
      HowSection.everyClass => 'En cada clase · Asistencia',
    };
  }

  static String stepCounter(int current, int total) => 'Paso $current de $total';

  // ───────────────────────── App del docente ─────────────────────────

  static const _tShowQr = HowStep(
    scene: UiSceneKind.qr,
    section: HowSection.once,
    actor: HowActor.you,
    title: 'Muestra el QR de tu clase',
    body: 'Entra a la clase, toca «Inscribir estudiantes» y deja la pantalla abierta. Si quieres, proyéctala en el tablero.',
    tip: 'Esto se hace una sola vez por clase, no en cada sesión.',
  );

  static const _tStudentCode = HowStep(
    scene: UiSceneKind.codigo,
    section: HowSection.once,
    actor: HowActor.other,
    title: 'Cada estudiante escribe su código',
    body: 'Con la app Asistencia Estudiante escanea el QR y escribe su código estudiantil. Si está en tu lista, entra solo.',
    tip: 'Tiene que estar en el salón: la confirmación viaja por Bluetooth.',
  );

  static const _tApprove = HowStep(
    scene: UiSceneKind.aprobar,
    section: HowSection.once,
    actor: HowActor.you,
    title: 'Tú decides quién más entra',
    body: 'Quien no está en tu lista aparece en «Por aprobar». Pregúntale su nombre y su correo, y agrégalo o recházalo.',
    tip: 'Cada estudiante queda con un solo celular. Si lo cambia, tú apruebas el nuevo.',
  );

  static const _tPin = HowStep(
    scene: UiSceneKind.pin,
    section: HowSection.everyClass,
    actor: HowActor.you,
    title: 'Abre la sesión y di el PIN',
    body: 'Toca «Tomar asistencia». La app te da un PIN de dos números: díctalo o escríbelo en el tablero.',
    tip: 'Si lo necesitas, puedes cambiar el PIN desde la misma pantalla.',
  );

  static const _tStudentNear = HowStep(
    scene: UiSceneKind.acercar,
    section: HowSection.everyClass,
    actor: HowActor.other,
    title: 'Los estudiantes acercan su celular',
    body: 'Cada uno escribe el PIN en su app y acerca su celular al tuyo. No necesitan internet ni datos.',
    tip: 'Solo funciona de cerca: así nadie marca desde fuera del salón.',
  );

  static const _tListFills = HowStep(
    scene: UiSceneKind.presente,
    section: HowSection.everyClass,
    actor: HowActor.auto,
    title: 'La lista se marca sola',
    body: 'Cada nombre queda presente en tu lista apenas su celular encuentra el tuyo. Tú solo miras.',
    tip: '¿A alguien se le quedó o se le dañó el celular? Márcalo tú a mano en la lista.',
  );

  static const _tClose = HowStep(
    scene: UiSceneKind.excel,
    section: HowSection.everyClass,
    actor: HowActor.you,
    title: 'Cierra, firma y envía',
    body: 'Al terminar toca «Cerrar y firmar». La sesión queda guardada y puedes enviar el Excel con la asistencia.',
    tip: 'Cada clase admite hasta 64 estudiantes. La app te avisa si llegas al límite.',
  );

  static const _tByHand = HowStep(
    scene: UiSceneKind.amano,
    actor: HowActor.you,
    title: 'Márcalo tú a mano',
    body: 'Durante la sesión, toca el nombre del estudiante en tu lista para dejarlo presente.',
    tip: 'Queda anotado que la asistencia se registró a mano.',
  );

  static const _tUnlink = HowStep(
    scene: UiSceneKind.cambio,
    actor: HowActor.you,
    title: 'Desvincula el celular anterior',
    body: 'En «Estudiantes» abre las opciones del estudiante y toca «Desvincular celular».',
    tip: 'El celular anterior deja de servir para marcar asistencia en esta clase.',
  );

  static const _tRejoin = HowStep(
    scene: UiSceneKind.escanear,
    actor: HowActor.other,
    title: 'El estudiante se inscribe otra vez',
    body: 'Con su celular nuevo escanea el QR de «Inscribir estudiantes» y escribe su código.',
  );

  static const _tRemove = HowStep(
    scene: UiSceneKind.retirar,
    actor: HowActor.you,
    title: 'Retira o elimina a un estudiante',
    body: 'En «Estudiantes» abre sus opciones. Si no tiene asistencias, se elimina; si ya tiene, se retira y su historial se conserva.',
    tip: 'Para confirmar, la app te pide escribir su primer nombre.',
  );

  static const _tNotFound = HowStep(
    scene: UiSceneKind.acercar,
    actor: HowActor.other,
    title: 'Pídele que se acerque más',
    body: 'Que revise el PIN, que tenga el Bluetooth encendido y que acerque su celular al tuyo con la app abierta.',
    tip: 'Si sigue sin aparecer, márcalo tú a mano.',
  );

  static const teacher = HowItWorksContent(
    studentView: false,
    otherLabel: 'Lo hace el estudiante',
    tourIntro: 'Mira cómo funciona en 7 pasos',
    tour: [_tShowQr, _tStudentCode, _tApprove, _tPin, _tStudentNear, _tListFills, _tClose],
    topics: [
      HowTopic(
        id: 'inscribir',
        icon: Icons.qr_code_2_rounded,
        tone: UiTone.manual,
        title: 'Inscribir estudiantes',
        subtitle: 'El QR de la clase y quién entra.',
        steps: [_tShowQr, _tStudentCode, _tApprove],
      ),
      HowTopic(
        id: 'asistencia',
        icon: Icons.sensors_rounded,
        title: 'Tomar asistencia',
        subtitle: 'El PIN y acercar el celular.',
        steps: [_tPin, _tStudentNear, _tListFills],
      ),
      HowTopic(
        id: 'sin-celular',
        icon: Icons.edit_rounded,
        title: 'Sin celular',
        subtitle: 'Marcar a alguien a mano.',
        steps: [_tByHand],
      ),
      HowTopic(
        id: 'cerrar',
        icon: Icons.task_rounded,
        title: 'Cerrar y enviar',
        subtitle: 'Firmar la sesión y el Excel.',
        steps: [_tClose],
      ),
      HowTopic(
        id: 'cambio-celular',
        icon: Icons.sync_rounded,
        title: 'Cambió de celular',
        subtitle: 'Desvincular y volver a inscribir.',
        steps: [_tUnlink, _tRejoin],
      ),
      HowTopic(
        id: 'retirar',
        icon: Icons.person_remove_rounded,
        tone: UiTone.absent,
        title: 'Retirar o eliminar',
        subtitle: 'Sacar a alguien de la clase.',
        steps: [_tRemove],
      ),
    ],
    facts: [
      HowFact(
        icon: Icons.groups_rounded,
        title: 'Hasta 64 estudiantes por clase',
        body: 'La app te avisa cuando llegas al límite.',
      ),
      HowFact(
        icon: Icons.wifi_off_rounded,
        title: 'Funciona sin internet',
        body: 'Todo viaja por Bluetooth entre los celulares.',
      ),
      HowFact(
        icon: Icons.smartphone_rounded,
        title: 'Un celular por estudiante',
        body: 'Si lo cambia, tú apruebas el nuevo.',
      ),
    ],
    troubleshooting: [
      HowTopic(
        id: 'no-encuentra',
        icon: Icons.search_off_rounded,
        title: 'No encuentra a un estudiante',
        subtitle: 'Revisar el PIN, la cercanía y el Bluetooth.',
        steps: [_tNotFound],
      ),
    ],
  );

  // ──────────────────────── App del estudiante ────────────────────────

  static const _sScan = HowStep(
    scene: UiSceneKind.escanear,
    section: HowSection.once,
    actor: HowActor.you,
    title: 'Escanea el QR de tu profesor',
    body: 'Toca «Unirme a una clase» y apunta la cámara al QR que tu profesor muestra en su celular o en el tablero.',
    tip: 'Esto se hace una sola vez por clase.',
  );

  static const _sCode = HowStep(
    scene: UiSceneKind.codigo,
    section: HowSection.once,
    actor: HowActor.you,
    title: 'Escribe tu código y espera cerca',
    body: 'Escribe tu código estudiantil y tu nombre. Quédate en el salón: tu profesor te confirma por Bluetooth.',
    tip: 'Si no estás en su lista, tu profesor te aprueba ahí mismo.',
  );

  static const _sTeacherPin = HowStep(
    scene: UiSceneKind.pin,
    section: HowSection.everyClass,
    actor: HowActor.other,
    title: 'Tu profesor dicta el PIN',
    body: 'Al empezar la clase, tu profesor dice un PIN de dos números o lo escribe en el tablero.',
    tip: '¿Llegaste tarde? Pídele el PIN.',
  );

  static const _sTypePin = HowStep(
    scene: UiSceneKind.teclado,
    section: HowSection.everyClass,
    actor: HowActor.you,
    title: 'Escribe el PIN',
    body: 'En tu clase toca «Marcar asistencia» y escribe los dos números que dictó tu profesor.',
  );

  static const _sNear = HowStep(
    scene: UiSceneKind.acercar,
    section: HowSection.everyClass,
    actor: HowActor.you,
    title: 'Acerca tu celular al del profesor',
    body: 'Deja la app abierta y acércate. No necesitas internet ni datos.',
    tip: 'Solo funciona de cerca: no se puede marcar desde fuera del salón.',
  );

  static const _sPresent = HowStep(
    scene: UiSceneKind.listo,
    section: HowSection.everyClass,
    actor: HowActor.auto,
    title: '¡Presente!',
    body: 'Cuando veas «¡Presente!», tu asistencia ya quedó registrada. Puedes guardar el celular.',
    tip: 'Si no aparece, revisa el PIN y acércate más.',
  );

  static const _sAskUnlink = HowStep(
    scene: UiSceneKind.cambio,
    actor: HowActor.other,
    title: 'Tu profesor desvincula el anterior',
    body: 'Cuéntale que cambiaste de celular. Desde su app, él desvincula el celular anterior.',
  );

  static const _sRejoin = HowStep(
    scene: UiSceneKind.escanear,
    actor: HowActor.you,
    title: 'Únete otra vez con el nuevo',
    body: 'Con tu celular nuevo toca «Unirme a una clase», escanea el QR y escribe tu código.',
  );

  static const _sByHand = HowStep(
    scene: UiSceneKind.amano,
    actor: HowActor.other,
    title: 'Tu profesor te marca a mano',
    body: 'Si se te quedó o se te dañó el celular, avísale antes de que cierre la sesión.',
  );

  static const _sNotFound = HowStep(
    scene: UiSceneKind.acercar,
    actor: HowActor.you,
    title: 'Acércate más y revisa el PIN',
    body: 'Comprueba que el Bluetooth esté encendido, que el PIN sea el de hoy y acerca tu celular al del profesor.',
    tip: 'Si nada funciona, pídele a tu profesor que te marque a mano.',
  );

  static const student = HowItWorksContent(
    studentView: true,
    otherLabel: 'Lo hace tu profesor',
    tourIntro: 'Mira cómo funciona en 6 pasos',
    tour: [_sScan, _sCode, _sTeacherPin, _sTypePin, _sNear, _sPresent],
    topics: [
      HowTopic(
        id: 'unirme',
        icon: Icons.qr_code_scanner_rounded,
        tone: UiTone.manual,
        title: 'Unirme a una clase',
        subtitle: 'El QR y tu código.',
        steps: [_sScan, _sCode],
      ),
      HowTopic(
        id: 'marcar',
        icon: Icons.sensors_rounded,
        title: 'Marcar asistencia',
        subtitle: 'El PIN y acercar el celular.',
        steps: [_sTeacherPin, _sTypePin, _sNear, _sPresent],
      ),
      HowTopic(
        id: 'cambio-celular',
        icon: Icons.sync_rounded,
        title: 'Cambié de celular',
        subtitle: 'Volver a unirme con el nuevo.',
        steps: [_sAskUnlink, _sRejoin],
      ),
      HowTopic(
        id: 'sin-celular',
        icon: Icons.edit_rounded,
        title: 'Sin celular',
        subtitle: 'Que el profesor te marque.',
        steps: [_sByHand],
      ),
    ],
    facts: [
      HowFact(
        icon: Icons.wifi_off_rounded,
        title: 'Funciona sin internet',
        body: 'Todo viaja por Bluetooth entre los celulares.',
      ),
      HowFact(
        icon: Icons.near_me_rounded,
        title: 'Solo de cerca',
        body: 'Tienes que estar junto al celular de tu profesor.',
      ),
      HowFact(
        icon: Icons.smartphone_rounded,
        title: 'Un celular por estudiante',
        body: 'Tu celular queda vinculado a ti en cada clase.',
      ),
    ],
    troubleshooting: [
      HowTopic(
        id: 'no-encuentra',
        icon: Icons.search_off_rounded,
        title: 'No encuentra a mi profesor',
        subtitle: 'Revisar el PIN, la cercanía y el Bluetooth.',
        steps: [_sNotFound],
      ),
    ],
  );
}
