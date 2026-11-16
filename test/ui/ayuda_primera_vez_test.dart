import 'dart:io';

import 'package:asistencia_uniguajira/app/app_flavor.dart';
import 'package:asistencia_uniguajira/data/services/first_run_store.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_content.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_gate.dart';
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

class _FailingFirstRunStore implements FirstRunStore {
  @override
  Future<bool> hasSeenTour() async {
    throw Exception('Error al acceder al almacenamiento');
  }

  @override
  Future<void> markTourSeen() async {
    throw Exception('Error al guardar');
  }
}

class _FailingSaveFirstRunStore implements FirstRunStore {
  @override
  Future<bool> hasSeenTour() async => false;

  @override
  Future<void> markTourSeen() async {
    throw Exception('Error al guardar');
  }
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required FirstRunStore store,
  HowItWorksContent content = HowItWorksContent.teacher,
  Widget child = const Text('INICIO'),
  bool dark = false,
  Size size = const Size(360, 640),
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? UiTheme.dark() : UiTheme.light(),
      home: HowItWorksGate(
        content: content,
        store: store,
        child: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(_loadFigtree);

  group('HowItWorksGate y primera apertura', () {
    test('AppFlavor define el helpContent correspondiente a cada rol', () {
      expect(AppFlavor.docente.helpContent, HowItWorksContent.teacher);
      expect(AppFlavor.estudiante.helpContent, HowItWorksContent.student);
    });

    testWidgets(
      'con MemoryFirstRunStore() muestra HowItWorksTourScreen con firstRun==true y steps de content.tour; no muestra INICIO',
      (tester) async {
        final store = MemoryFirstRunStore();
        await _pumpGate(tester, store: store, content: HowItWorksContent.teacher);

        expect(find.byType(HowItWorksTourScreen), findsOneWidget);
        final tour = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
        expect(tour.firstRun, isTrue);
        expect(tour.steps, HowItWorksContent.teacher.tour);
        expect(find.text('INICIO'), findsNothing);
      },
    );

    testWidgets(
      'al llamar onFinished aparece INICIO, desaparece el recorrido y store.seen es true',
      (tester) async {
        final store = MemoryFirstRunStore();
        await _pumpGate(tester, store: store, content: HowItWorksContent.teacher);

        expect(find.byType(HowItWorksTourScreen), findsOneWidget);
        expect(find.text('INICIO'), findsNothing);

        final tour = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
        expect(tour.onFinished, isNotNull);
        tour.onFinished!();

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('INICIO'), findsOneWidget);
        expect(find.byType(HowItWorksTourScreen), findsNothing);
        expect(store.seen, isTrue);
      },
    );

    testWidgets(
      'con MemoryFirstRunStore(seen: true) muestra INICIO directamente',
      (tester) async {
        final store = MemoryFirstRunStore(seen: true);
        await _pumpGate(tester, store: store, content: HowItWorksContent.teacher);

        expect(find.text('INICIO'), findsOneWidget);
        expect(find.byType(HowItWorksTourScreen), findsNothing);
      },
    );

    testWidgets(
      'con FirstRunStore que falla en hasSeenTour() muestra INICIO y tester.takeException() es nulo',
      (tester) async {
        final store = _FailingFirstRunStore();
        await _pumpGate(tester, store: store, content: HowItWorksContent.teacher);

        expect(find.text('INICIO'), findsOneWidget);
        expect(find.byType(HowItWorksTourScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'soporta tema oscuro y contenido de estudiante sin desbordes',
      (tester) async {
        final store = MemoryFirstRunStore();
        await _pumpGate(
          tester,
          store: store,
          content: HowItWorksContent.student,
          dark: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(HowItWorksTourScreen), findsOneWidget);
        final tour = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
        expect(tour.firstRun, isTrue);
        expect(tour.steps, HowItWorksContent.student.tour);
      },
    );

    testWidgets(
      'al fallar markTourSeen() no lanza error no controlado',
      (tester) async {
        final store = _FailingSaveFirstRunStore();
        await _pumpGate(tester, store: store);

        final tour = tester.widget<HowItWorksTourScreen>(find.byType(HowItWorksTourScreen));
        expect(tour.onFinished, isNotNull);
        tour.onFinished!();

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('INICIO'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
