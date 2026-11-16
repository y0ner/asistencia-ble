import 'dart:io';

import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_content.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_tour_screen.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga Figtree para que las pruebas midan el texto con la letra real.
Future<void> _loadFigtree() async {
  final loader = FontLoader(UiText.family);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _pumpStep(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(_loadFigtree);

  testWidgets('docente recorrido completo muestra pasos, quien lo hace y navegacion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: HowItWorksContent.teacher.tour,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Paso 1
    expect(find.text(HowItWorksContent.teacher.tour[0].title), findsOneWidget);
    expect(find.text('Lo haces tú'), findsOneWidget);
    expect(find.text('Paso 1 de 7'), findsOneWidget);
    expect(find.text('Una sola vez · Inscribir'), findsOneWidget);
    expect(find.text(HowItWorksContent.back), findsNothing);

    // Tocar Siguiente -> Paso 2
    await tester.tap(find.text(HowItWorksContent.next));
    await _pumpStep(tester);

    expect(find.text(HowItWorksContent.teacher.tour[1].title), findsOneWidget);
    expect(find.text('Lo hace el estudiante'), findsOneWidget);
    expect(find.text(HowItWorksContent.back), findsOneWidget);

    // Tocar Atrás -> vuelve al Paso 1
    await tester.tap(find.text(HowItWorksContent.back));
    await _pumpStep(tester);

    expect(find.text(HowItWorksContent.teacher.tour[0].title), findsOneWidget);
    expect(find.text(HowItWorksContent.back), findsNothing);
  });

  testWidgets('avanzando hasta el paso 7 el boton dice Entendido y llama onFinished una vez', (tester) async {
    var finishedCalled = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: HowItWorksContent.teacher.tour,
          onFinished: () => finishedCalled++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    for (var i = 0; i < 6; i++) {
      expect(find.text(HowItWorksContent.next), findsOneWidget);
      await tester.tap(find.text(HowItWorksContent.next));
      await _pumpStep(tester);
    }

    expect(find.text(HowItWorksContent.done), findsOneWidget);
    expect(find.text(HowItWorksContent.next), findsNothing);

    await tester.tap(find.text(HowItWorksContent.done));
    await _pumpStep(tester);

    expect(finishedCalled, 1);
  });

  testWidgets('con firstRun true aparece Saltar sin boton de volver y llama onFinished una vez', (tester) async {
    var finishedCalled = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: HowItWorksContent.teacher.tour,
          firstRun: true,
          onFinished: () => finishedCalled++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(HowItWorksContent.skip), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Volver'), findsNothing);
    expect(find.byTooltip('Cerrar'), findsNothing);

    await tester.tap(find.text(HowItWorksContent.skip));
    await _pumpStep(tester);

    expect(finishedCalled, 1);
  });

  testWidgets('con onFinished nulo dentro de un Navigator Entendido cierra la pantalla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HowItWorksTourScreen(
                        content: HowItWorksContent.teacher,
                        steps: [HowItWorksContent.teacher.tour.first],
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Abrir'));
    await _pumpStep(tester);
    expect(find.byType(HowItWorksTourScreen), findsOneWidget);

    await tester.tap(find.text(HowItWorksContent.done));
    await _pumpStep(tester);
    expect(find.byType(HowItWorksTourScreen), findsNothing);
  });

  testWidgets('tema de un solo paso sin-celular no muestra Paso 1 de 1 ni Atras y boton dice Entendido', (tester) async {
    final topic = HowItWorksContent.teacher.topics.firstWhere((t) => t.id == 'sin-celular');
    expect(topic.steps.length, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: topic.steps,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paso 1 de 1'), findsNothing);
    expect(find.text(HowItWorksContent.back), findsNothing);
    expect(find.text(HowItWorksContent.done), findsOneWidget);
  });

  testWidgets('estudiante paso 3 muestra Lo hace tu profesor y paso 6 Pasa solo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.student,
          steps: HowItWorksContent.student.tour,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Avanza a paso 2
    await tester.tap(find.text(HowItWorksContent.next));
    await _pumpStep(tester);

    // Avanza a paso 3
    await tester.tap(find.text(HowItWorksContent.next));
    await _pumpStep(tester);

    expect(find.text('Lo hace tu profesor'), findsOneWidget);

    // Avanza a pasos 4, 5, 6
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(HowItWorksContent.next));
      await _pumpStep(tester);
    }

    expect(find.text('Pasa solo'), findsOneWidget);
  });

  testWidgets('hay un UiScene visible en cada paso con el kind del paso', (tester) async {
    // Verificar en docente
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: HowItWorksContent.teacher.tour,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    for (var i = 0; i < HowItWorksContent.teacher.tour.length; i++) {
      final expectedKind = HowItWorksContent.teacher.tour[i].scene;
      expect(
        find.byWidgetPredicate((w) => w is UiScene && w.kind == expectedKind),
        findsOneWidget,
        reason: 'UiScene en paso $i debe ser $expectedKind',
      );
      if (i < HowItWorksContent.teacher.tour.length - 1) {
        await tester.tap(find.text(HowItWorksContent.next));
        await _pumpStep(tester);
      }
    }
  });

  testWidgets('en claro y oscuro a 360x640 con letra al 130% recorre todos los pasos sin error', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    for (final theme in [UiTheme.light(), UiTheme.dark()]) {
      for (final content in [HowItWorksContent.teacher, HowItWorksContent.student]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: HowItWorksTourScreen(
              key: UniqueKey(),
              content: content,
              steps: content.tour,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        for (var i = 0; i < content.tour.length; i++) {
          expect(
            tester.takeException(),
            isNull,
            reason: 'Excepción en paso ${i + 1} de ${content.tour.length} (tema: ${theme.brightness})',
          );
          if (i < content.tour.length - 1) {
            await tester.tap(find.text(HowItWorksContent.next));
            await _pumpStep(tester);
          }
        }
      }
    }
  });

  testWidgets('deslizar entre paginas actualiza el paso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: HowItWorksTourScreen(
          content: HowItWorksContent.teacher,
          steps: HowItWorksContent.teacher.tour,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Lo haces tú'), findsOneWidget);
    expect(find.text(HowItWorksContent.back), findsNothing);

    // Desliza a la izquierda para ir a la siguiente página
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await _pumpStep(tester);

    expect(find.text('Lo hace el estudiante'), findsOneWidget);
    expect(find.text(HowItWorksContent.back), findsOneWidget);
  });
}
