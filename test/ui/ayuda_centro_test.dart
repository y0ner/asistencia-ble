import 'dart:io';

import 'package:asistencia_uniguajira/features/shared/how_it_works/help_center_screen.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_content.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_tour_screen.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFigtree() async {
  final loader = FontLoader(UiText.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _pumpHelpCenter(
  WidgetTester tester, {
  required HowItWorksContent content,
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  void Function(BuildContext)? onOpenPermissions,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? UiTheme.light(),
      home: HelpCenterScreen(
        content: content,
        onOpenPermissions: onOpenPermissions ?? (_) {},
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(_loadFigtree);

  group('HelpCenterScreen - Docente', () {
    testWidgets('muestra todos los elementos principales del docente', (tester) async {
      await _pumpHelpCenter(tester, content: HowItWorksContent.teacher);

      expect(find.text(HowItWorksContent.helpTitle), findsOneWidget);
      expect(find.text(HowItWorksContent.firstTime), findsOneWidget);
      expect(find.text(HowItWorksContent.teacher.tourIntro), findsOneWidget);
      expect(find.text(HowItWorksContent.openTour), findsOneWidget);

      for (final topic in HowItWorksContent.teacher.topics) {
        await tester.scrollUntilVisible(find.text(topic.title), 200);
        expect(find.text(topic.title), findsOneWidget);
      }

      for (final fact in HowItWorksContent.teacher.facts) {
        await tester.scrollUntilVisible(find.text(fact.title), 200);
        expect(find.text(fact.title), findsOneWidget);
      }

      expect(
        HowItWorksContent.teacher.facts.any((f) => f.title.contains('64')),
        isTrue,
      );

      await tester.scrollUntilVisible(find.text('No encuentra a un estudiante'), 200);
      expect(find.text('No encuentra a un estudiante'), findsOneWidget);

      await tester.scrollUntilVisible(find.text(HowItWorksContent.permissionsTitle), 200);
      expect(find.text(HowItWorksContent.permissionsTitle), findsOneWidget);
    });

    testWidgets('tocar «Ver el recorrido» abre HowItWorksTourScreen con recorrido completo', (tester) async {
      await _pumpHelpCenter(tester, content: HowItWorksContent.teacher);

      await tester.tap(find.text(HowItWorksContent.openTour));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final tourScreen = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
      expect(tourScreen.steps, HowItWorksContent.teacher.tour);
      expect(tourScreen.firstRun, isFalse);
    });

    testWidgets('tocar el tema «Sin celular» abre HowItWorksTourScreen de ese tema', (tester) async {
      await _pumpHelpCenter(tester, content: HowItWorksContent.teacher);

      await tester.scrollUntilVisible(find.text('Sin celular'), 200);
      await tester.tap(find.text('Sin celular'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final tourScreen = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
      final topic = HowItWorksContent.teacher.topics.firstWhere((t) => t.title == 'Sin celular');
      expect(tourScreen.steps, topic.steps);
      expect(tourScreen.title, 'Sin celular');
    });

    testWidgets('tocar «No encuentra a un estudiante» abre el recorrido de ese tema', (tester) async {
      await _pumpHelpCenter(tester, content: HowItWorksContent.teacher);

      await tester.scrollUntilVisible(find.text('No encuentra a un estudiante'), 200);
      await tester.tap(find.text('No encuentra a un estudiante'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final tourScreen = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
      final topic = HowItWorksContent.teacher.troubleshooting
          .firstWhere((t) => t.title == 'No encuentra a un estudiante');
      expect(tourScreen.steps, topic.steps);
      expect(tourScreen.title, 'No encuentra a un estudiante');
    });

    testWidgets('tocar «Permisos del celular» llama onOpenPermissions una vez', (tester) async {
      var permissionsCalled = 0;
      await _pumpHelpCenter(
        tester,
        content: HowItWorksContent.teacher,
        onOpenPermissions: (_) => permissionsCalled++,
      );

      await tester.scrollUntilVisible(find.text(HowItWorksContent.permissionsTitle), 200);
      await tester.tap(find.text(HowItWorksContent.permissionsTitle));
      await tester.pump(const Duration(milliseconds: 600));

      expect(permissionsCalled, 1);
    });
  });

  group('HelpCenterScreen - Estudiante', () {
    testWidgets('muestra sus 4 temas y «No encuentra a mi profesor»', (tester) async {
      await _pumpHelpCenter(tester, content: HowItWorksContent.student);

      expect(HowItWorksContent.student.topics.length, 4);
      for (final topic in HowItWorksContent.student.topics) {
        await tester.scrollUntilVisible(find.text(topic.title), 200);
        expect(find.text(topic.title), findsOneWidget);
      }

      await tester.scrollUntilVisible(find.text('No encuentra a mi profesor'), 200);
      expect(find.text('No encuentra a mi profesor'), findsOneWidget);
    });
  });

  group('HelpCenterScreen - Adaptabilidad y temas', () {
    for (final theme in [UiTheme.light(), UiTheme.dark()]) {
      final themeName = theme.brightness.name;

      testWidgets('se dibuja sin desbordes a 360 × 640 con letra 130 % ($themeName)', (tester) async {
        await _pumpHelpCenter(
          tester,
          content: HowItWorksContent.teacher,
          theme: theme,
          size: const Size(360, 640),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });

      testWidgets('se dibuja sin desbordes a 390 × 844 con letra normal ($themeName)', (tester) async {
        await _pumpHelpCenter(
          tester,
          content: HowItWorksContent.teacher,
          theme: theme,
          size: const Size(390, 844),
          textScale: 1.0,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });

      testWidgets('estudiante se dibuja sin desbordes a 360 × 640 con letra 130 % ($themeName)', (tester) async {
        await _pumpHelpCenter(
          tester,
          content: HowItWorksContent.student,
          theme: theme,
          size: const Size(360, 640),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
