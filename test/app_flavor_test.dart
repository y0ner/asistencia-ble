import 'package:asistencia_uniguajira/app/app_flavor.dart';
import 'package:asistencia_uniguajira/app/asistencia_app.dart';
import 'package:asistencia_uniguajira/data/services/first_run_store.dart';
import 'package:asistencia_uniguajira/features/shared/hardware_diagnostic_dialog.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/help_center_screen.dart';
import 'package:asistencia_uniguajira/features/shared/how_it_works/how_it_works_content.dart';
import 'package:asistencia_uniguajira/features/student/student_courses_screen.dart';
import 'package:asistencia_uniguajira/features/teacher/courses_dashboard_screen.dart';
import 'package:asistencia_uniguajira/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pruebas de AppFlavor y Puntos de Entrada', () {
    test('AppFlavor define títulos y pantallas correctas', () {
      expect(AppFlavor.docente.title, 'Asistencia Docente');
      expect(AppFlavor.estudiante.title, 'Asistencia Estudiante');

      expect(AppFlavor.docente.homeScreen, isA<CoursesDashboardScreen>());
      expect(AppFlavor.estudiante.homeScreen, isA<StudentCoursesScreen>());

      expect(AppFlavor.docente.helpContent, HowItWorksContent.teacher);
      expect(AppFlavor.estudiante.helpContent, HowItWorksContent.student);
    });

    testWidgets(
      'Flavor Docente monta CoursesDashboardScreen con botón de ayuda',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          AsistenciaApp(
            flavor: AppFlavor.docente,
            firstRunStore: MemoryFirstRunStore(seen: true),
          ),
        );
        await tester.pump();

        expect(find.byType(CoursesDashboardScreen), findsOneWidget);
        expect(find.byType(StudentCoursesScreen), findsNothing);
        expect(find.text('Asistencia'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Flavor Estudiante monta StudentCoursesScreen con botón de ayuda',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          AsistenciaApp(
            flavor: AppFlavor.estudiante,
            firstRunStore: MemoryFirstRunStore(seen: true),
          ),
        );
        await tester.pump();

        expect(find.byType(StudentCoursesScreen), findsOneWidget);
        expect(find.byType(CoursesDashboardScreen), findsNothing);
        expect(find.text('Asistencia'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'El botón de ayuda abre el centro de ayuda del docente',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          AsistenciaApp(
            flavor: AppFlavor.docente,
            firstRunStore: MemoryFirstRunStore(seen: true),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.help_outline_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(HelpCenterScreen), findsOneWidget);
        final screen =
            tester.widget<HelpCenterScreen>(find.byType(HelpCenterScreen));
        expect(screen.content, HowItWorksContent.teacher);
      },
    );
  });

  group('Pruebas de HardwareDiagnosticDialog (Filtro Android 12+)', () {
    testWidgets(
      'HardwareDiagnosticDialog excluye ubicación en Android 12 o superior',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: Scaffold(
              body: HardwareDiagnosticDialog(
                isAndroid12OrHigherOverride: true,
                permissionChecker: (_) async => PermissionStatus.granted,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Buscar celulares cercanos'), findsOneWidget);
        expect(find.text('Avisar a celulares cercanos'), findsOneWidget);
        expect(find.text('Conectar con celulares cercanos'), findsOneWidget);
        expect(find.textContaining('Cámara ('), findsOneWidget);
        expect(find.textContaining('Ubicación'), findsNothing);
      },
    );

    testWidgets(
      'HardwareDiagnosticDialog incluye ubicación en Android 11 o inferior',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.light(),
            home: Scaffold(
              body: HardwareDiagnosticDialog(
                isAndroid12OrHigherOverride: false,
                permissionChecker: (_) async => PermissionStatus.granted,
                locationServiceChecker: () async => ServiceStatus.enabled,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Antes de Android 12 los permisos de Bluetooth cercano no existen:
        // mostrarlos los dejaba siempre en «Falta».
        expect(find.text('Buscar celulares cercanos'), findsNothing);
        expect(find.text('Avisar a celulares cercanos'), findsNothing);
        expect(find.text('Conectar con celulares cercanos'), findsNothing);
        expect(find.textContaining('Cámara ('), findsOneWidget);
        expect(find.text('Ubicación'), findsOneWidget);
        expect(find.text('Ubicación del celular encendida'), findsOneWidget);
      },
    );
  });
}
