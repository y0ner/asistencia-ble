import 'dart:io';

import 'package:asistencia_uniguajira/data/services/first_run_store.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_content.dart';
import 'package:asistencia_uniguajira/ui/components/scenes/ui_scene_canvas.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/scene_probe.dart';

Future<void> _loadFigtree() async {
  final loader = FontLoader(UiText.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFigtree);

  group('parseSvgPath', () {
    test('líneas absolutas y relativas', () {
      expect(svgPathLength('M0 0 h10 v10 H0 Z'), closeTo(40, 0.001));
      expect(svgPathLength('M0 0 l3 4'), closeTo(5, 0.001));
      expect(svgPathLength('M0 0 L3 4 6 8'), closeTo(10, 0.001));
    });

    test('varios trazos en un mismo texto, sin espacios', () {
      expect(svgPathLength('M0 0h10M0 5h10'), closeTo(20, 0.001));
      expect(svgPathLength('M5 5 v-5 h5'), closeTo(10, 0.001));
    });

    test('curvas y arcos', () {
      // Cuarto de círculo de radio 10.
      expect(svgPathLength('M0 0 a10 10 0 0 1 10 10'), closeTo(15.708, 0.2));
      expect(svgPathLength('M0 0 q5 10 10 0'), greaterThan(10));
      expect(svgPathLength('M0 0 c0 10 10 10 10 0'), greaterThan(10));
      final bounds = parseSvgPath('M192 62 h72 a16 16 0 0 1 16 16 v36 a16 16 0 0 1 -16 16 h-44 l-18 16 v-16 '
              'h-10 a16 16 0 0 1 -16 -16 v-36 a16 16 0 0 1 16 -16 z')
          .getBounds();
      expect(bounds.left, closeTo(176, 0.01));
      expect(bounds.right, closeTo(280, 0.01));
      expect(bounds.top, closeTo(62, 0.01));
      expect(bounds.bottom, closeTo(146, 0.01));
    });

    test('rechaza texto que no es un trazo', () {
      expect(() => parseSvgPath('10 10'), throwsFormatException);
      expect(() => parseSvgPath('M0 0 X5'), throwsFormatException);
    });
  });

  group('UiSceneAnim', () {
    test('wave va y vuelve', () {
      expect(UiSceneAnim.wave(0), closeTo(0, 1e-9));
      expect(UiSceneAnim.wave(0.5), closeTo(1, 1e-9));
      expect(UiSceneAnim.wave(1), closeTo(0, 1e-9));
    });

    test('appear se queda en 1', () {
      expect(UiSceneAnim.appear(0.1, 0.2, 0.4), 0);
      expect(UiSceneAnim.appear(0.3, 0.2, 0.4), closeTo(0.5, 1e-9));
      expect(UiSceneAnim.appear(UiScene.restT, 0.2, 0.4), 1);
    });

    test('bump es un golpe corto', () {
      expect(UiSceneAnim.bump(0.5, 0.5), closeTo(1, 1e-9));
      expect(UiSceneAnim.bump(0.7, 0.5), 0);
    });

    test('step reparte el ciclo', () {
      expect(UiSceneAnim.step(0, 4), 0);
      expect(UiSceneAnim.step(0.49, 4), 1);
      expect(UiSceneAnim.step(1, 4), 3);
    });
  });

  for (final theme in [UiTheme.light(), UiTheme.dark()]) {
    testWidgets('todos los dibujos se pintan sin errores (${theme.brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final kind in UiSceneKind.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: Center(child: UiScene(kind: kind, studentView: kind.index.isEven))),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(UiScene.cycle ~/ 8);
        }
        expect(tester.takeException(), isNull, reason: kind.name);
        final size = tester.getSize(find.byType(UiScene));
        expect(size.width / size.height, closeTo(320 / 220, 0.01));
        expect(find.bySemanticsLabel(RegExp('.+')), findsWidgets);
      }
    });
  }

  testWidgets('el dibujo modelo cumple las reglas de un dibujo animado', (tester) async {
    await expectSceneAnimates(tester, UiSceneKind.acercar);
  });

  testWidgets('los rótulos del dibujo cambian según quién mira', (tester) async {
    final teacher = await sceneFrame(tester, UiSceneKind.acercar, UiScene.restT);
    final student = await sceneFrame(tester, UiSceneKind.acercar, UiScene.restT, studentView: true);
    expect(changedPixels(teacher, student), greaterThan(50));
  });

  testWidgets('con reducir movimiento el dibujo se queda quieto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: UiScene(kind: UiSceneKind.acercar)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('contenido de la ayuda', () {
    for (final content in [HowItWorksContent.teacher, HowItWorksContent.student]) {
      final app = content.studentView ? 'estudiante' : 'docente';

      test('$app: el recorrido deja claro quién hace cada paso', () {
        expect(content.tour, isNotEmpty);
        expect(content.tourIntro, contains('${content.tour.length} pasos'));
        expect(content.tour.map((s) => s.actor).toSet(), containsAll(HowActor.values));
        for (final step in content.tour) {
          expect(step.section, isNotNull, reason: step.title);
          expect(step.title.trim(), isNotEmpty);
          expect(step.body.trim(), isNotEmpty);
        }
        // Primero lo de una sola vez y después lo de cada clase.
        final sections = content.tour.map((s) => s.section!.index).toList();
        expect(sections, orderedEquals([...sections]..sort()));
      });

      test('$app: cada tema tiene pasos y un identificador único', () {
        final topics = [...content.topics, ...content.troubleshooting];
        expect(topics.map((t) => t.id).toSet().length, topics.length);
        for (final topic in topics) {
          expect(topic.steps, isNotEmpty, reason: topic.id);
        }
        expect(content.facts, isNotEmpty);
      });

      test('$app: los textos no usan jerga técnica', () {
        final texts = [
          for (final topic in [...content.topics, ...content.troubleshooting]) ...[topic.title, topic.subtitle],
          for (final step in [
            ...content.tour,
            for (final topic in [...content.topics, ...content.troubleshooting]) ...topic.steps,
          ]) ...[step.title, step.body, step.tip ?? ''],
          for (final fact in content.facts) ...[fact.title, fact.body],
        ];
        final jargon = RegExp(r'\bBLE\b|roster|enrol|token|hash|hmac|json|criptogr', caseSensitive: false);
        for (final text in texts) {
          expect(jargon.hasMatch(text), isFalse, reason: text);
        }
      });
    }

    test('el docente sabe del límite de 64 estudiantes', () {
      expect(HowItWorksContent.teacher.facts.any((f) => f.title.contains('64')), isTrue);
    });
  });

  group('FirstRunStore', () {
    test('recuerda en las preferencias que ya se vio el recorrido', () async {
      SharedPreferences.setMockInitialValues({});
      const store = PrefsFirstRunStore();
      expect(await store.hasSeenTour(), isFalse);
      await store.markTourSeen();
      expect(await store.hasSeenTour(), isTrue);
    });

    test('la versión en memoria sirve para pruebas', () async {
      final store = MemoryFirstRunStore();
      expect(await store.hasSeenTour(), isFalse);
      await store.markTourSeen();
      expect(await store.hasSeenTour(), isTrue);
    });
  });
}
