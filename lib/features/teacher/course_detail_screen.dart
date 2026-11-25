import 'package:flutter/material.dart';

import '../../core/models/course_model.dart';
import '../../core/models/session_model.dart';
import '../../core/models/student_model.dart';
import '../../data/local/app_database.dart';
import '../../data/services/course_overview_service.dart';
import '../../data/services/roster_import_service.dart';
import '../../data/services/student_admin_service.dart';
import '../../ui/ui.dart';
import 'course_reports_screen.dart';
import 'enrollment_host_screen.dart';
import 'live_attendance_session_screen.dart';
import 'roster_import_modal.dart';
import 'signed_acta_dialog.dart';

/// Detalle de la clase seleccionada por el docente:
/// - Hero card para tomar asistencia o volver a la sesión activa.
/// - Banner informativo cuando no hay estudiantes en la clase.
/// - Métricas consolidadas (sesiones, asistencia, en riesgo) con acceso a Reportes.
/// - Historial de últimas sesiones con navegación al acta firmada o sesión en vivo.
/// - Acceso directo a la gestión de estudiantes y exportación del Excel oficial.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.course,
    this.database,
    this.rosterService,
    this.overviewService,
  });

  final CourseModel course;
  final AppDatabase? database;
  final RosterImportService? rosterService;
  final CourseOverviewService? overviewService;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final AppDatabase _database;
  late final RosterImportService _rosterService;
  late final CourseOverviewService _overviewService;

  bool _isLoading = true;
  CourseOverview? _overview;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase.instance;
    _rosterService = widget.rosterService ?? RosterImportService();
    _overviewService = widget.overviewService ??
        CourseOverviewService(database: _database);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final overview = await _overviewService.load(widget.course.id);
      if (mounted) {
        setState(() {
          _overview = overview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showUiSnack(context, 'No se pudieron cargar los datos de la clase.');
      }
    }
  }

  Future<void> _openEnrollment() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EnrollmentHostScreen(course: widget.course, database: _database),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _openImportModal() async {
    final changed = await RosterImportModal.show(context, widget.course);
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _onStartBleSession() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => LiveAttendanceSessionScreen(
          course: widget.course,
          database: _database,
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _openReportsScreen({bool exportOnOpen = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CourseReportsScreen(
          course: widget.course,
          database: _database,
          exportOnOpen: exportOnOpen,
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _openStudentsScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _CourseStudentsScreen(
          course: widget.course,
          database: _database,
          rosterService: _rosterService,
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _showCourseOptionsSheet() async {
    await showUiSheet<void>(
      context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: UiSpace.sm),
            UiNavRow(
              title: 'Inscribir estudiantes',
              subtitle: 'Un solo QR para toda la clase',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openEnrollment();
              },
            ),
            UiNavRow(
              title: 'Agregar a la lista',
              subtitle: 'Pegar, desde un archivo o uno por uno',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openImportModal();
              },
            ),
            UiNavRow(
              title: 'Eliminar clase',
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteCourse();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteCourse() async {
    final confirmed = await showUiConfirm(
      context,
      destructive: true,
      title: '¿Eliminar esta clase?',
      message:
          'Se borran sus estudiantes y sus sesiones. No se puede deshacer.',
      confirmLabel: 'Eliminar',
    );

    if (confirmed == true) {
      try {
        await _database.deleteCourse(widget.course.id);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          showUiSnack(context, 'No se pudo eliminar la clase.');
        }
      }
    }
  }

  Future<void> _viewSessionActa(SessionModel session) async {
    try {
      final actaJson = await _database.getSessionActaJson(session.id);
      if (!mounted) return;
      if (actaJson != null && actaJson.isNotEmpty) {
        await SignedActaDialog.showFromJson(
          context,
          actaJson: actaJson,
          courseSecretHex: widget.course.courseSecret,
        );
      } else {
        showUiSnack(context, 'No se encontró el acta guardada para esta sesión.');
      }
    } catch (e) {
      if (!mounted) return;
      showUiSnack(context, 'No se pudo abrir el acta de la sesión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    final overview = _overview;

    final Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (overview == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(UiSpace.page),
          child: UiBanner(
            tone: UiBannerTone.error,
            message: 'No se pudieron cargar los datos de la clase.',
            actionLabel: 'Reintentar',
            onAction: _loadData,
          ),
        ),
      );
    } else {
      final hasStudents = overview.hasStudents;
      final hasOpenSession = overview.openSession != null;

      body = RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.only(bottom: UiSpace.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.page,
                UiSpace.sm,
                UiSpace.page,
                0,
              ),
              child: hasStudents
                  ? UiHeroCard(
                      onTap: _onStartBleSession,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasOpenSession
                                      ? 'Volver a la sesión'
                                      : 'Tomar asistencia',
                                  style: UiText.h2.copyWith(color: c.onPrimary),
                                ),
                                const SizedBox(height: UiSpace.xs),
                                Text(
                                  '${UiFormat.count(overview.studentCount, 'estudiante', 'estudiantes')}'
                                  ' · ${overview.boundCount} con celular vinculado',
                                  style: UiText.label.copyWith(color: c.onPrimary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: UiSpace.md),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: c.onPrimary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: c.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    )
                  : UiBanner(
                      tone: UiBannerTone.info,
                      message:
                          'Inscribe a tus estudiantes con el código de la clase. Puedes empezar aunque no tengas la lista.',
                      actionLabel: 'Inscribir estudiantes',
                      onAction: _openEnrollment,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.page,
                UiSpace.md,
                UiSpace.page,
                0,
              ),
              child: Semantics(
                button: true,
                label: 'Ver reportes',
                child: InkWell(
                  onTap: () => _openReportsScreen(),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: UiStatTile(
                          value: '${overview.closedSessionCount}',
                          label: 'sesiones',
                        ),
                      ),
                      const SizedBox(width: UiSpace.sm),
                      Expanded(
                        child: UiStatTile(
                          value: overview.attendancePercent != null
                              ? '${overview.attendancePercent!.round()} %'
                              : '—',
                          label: 'asistencia',
                        ),
                      ),
                      const SizedBox(width: UiSpace.sm),
                      Expanded(
                        child: UiStatTile(
                          value: '${overview.atRiskCount}',
                          label: 'en riesgo',
                          tone: overview.atRiskCount > 0 ? UiTone.absent : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const UiSectionTitle('Últimas sesiones'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
              child: overview.recentSessions.isEmpty
                  ? Text(
                      'Aún no has tomado asistencia en esta clase.',
                      style: UiText.body.copyWith(color: c.muted),
                    )
                  : UiListGroup(
                      children: [
                        for (final row in overview.recentSessions)
                          UiNavRow(
                            title: UiFormat.longDate(
                              DateTime.tryParse(row.session.startedAt)
                                      ?.toLocal() ??
                                  DateTime.now(),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${row.presentCount} de ${row.totalStudents}',
                                  style: UiText.label.copyWith(color: c.muted),
                                ),
                                const SizedBox(width: UiSpace.sm),
                                if (row.isOpen)
                                  const UiPill(label: 'En vivo', dot: true)
                                else
                                  SizedBox(
                                    width: 52,
                                    child: UiProgressBar(
                                      value: row.ratio,
                                      height: 6,
                                      semanticLabel:
                                          '${(row.ratio * 100).round()} por ciento',
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (row.isOpen) {
                                _onStartBleSession();
                              } else {
                                _viewSessionActa(row.session);
                              }
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return UiPage(
      header: UiTopBar(
        title: widget.course.name,
        subtitle:
            '${widget.course.code} · Grupo ${widget.course.groupCode} · ${widget.course.semester}',
        onBack: () => Navigator.of(context).pop(),
        trailing: UiRoundIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'Opciones de la clase',
          onPressed: _showCourseOptionsSheet,
        ),
      ),
      bottom: _isLoading || overview == null
          ? null
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1.0);
                final stackVertical =
                    scale > 1.15 || constraints.maxWidth < 290;
                if (stackVertical) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UiButton(
                        label: 'Estudiantes',
                        variant: UiButtonVariant.tonal,
                        icon: Icons.person_outline_rounded,
                        onPressed: _openStudentsScreen,
                      ),
                      const SizedBox(height: UiSpace.sm),
                      UiButton(
                        label: 'Enviar Excel',
                        variant: UiButtonVariant.tonal,
                        icon: Icons.ios_share_rounded,
                        onPressed: () => _openReportsScreen(exportOnOpen: true),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: UiButton(
                        label: 'Estudiantes',
                        variant: UiButtonVariant.tonal,
                        icon: Icons.person_outline_rounded,
                        onPressed: _openStudentsScreen,
                      ),
                    ),
                    const SizedBox(width: UiSpace.sm),
                    Expanded(
                      child: UiButton(
                        label: 'Enviar Excel',
                        variant: UiButtonVariant.tonal,
                        icon: Icons.ios_share_rounded,
                        onPressed: () => _openReportsScreen(exportOnOpen: true),
                      ),
                    ),
                  ],
                );
              },
            ),
      body: body,
    );
  }
}

/// Pantalla interna para la gestión y consulta de los estudiantes de la clase.
class _CourseStudentsScreen extends StatefulWidget {
  const _CourseStudentsScreen({
    required this.course,
    required this.database,
    required this.rosterService,
  });

  final CourseModel course;
  final AppDatabase database;
  final RosterImportService rosterService;

  @override
  State<_CourseStudentsScreen> createState() => _CourseStudentsScreenState();
}

class _CourseStudentsScreenState extends State<_CourseStudentsScreen> {
  late final StudentAdminService _admin = StudentAdminService(database: widget.database);
  bool _isLoading = true;
  List<StudentModel> _students = <StudentModel>[];
  List<StudentModel> _retired = <StudentModel>[];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final all = await widget.database.getAllStudentsByCourse(widget.course.id);
      if (!mounted) return;
      int byName(StudentModel a, StudentModel b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      setState(() {
        _students = all.where((s) => s.isActive).toList()..sort(byName);
        _retired = all.where((s) => s.isRetired).toList()..sort(byName);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('No se pudo cargar la lista de estudiantes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showUiSnack(context, 'No se pudo cargar la lista de estudiantes.');
      }
    }
  }

  Future<void> _openImportModal() async {
    final changed = await RosterImportModal.show(context, widget.course);
    if (changed == true) await _loadStudents();
  }

  Future<void> _openEnrollment() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EnrollmentHostScreen(course: widget.course, database: widget.database),
      ),
    );
    if (mounted) await _loadStudents();
  }

  Future<void> _showStudentOptions(StudentModel student) async {
    final kind = await _admin.removalKindFor(student);
    if (!mounted) return;
    await showUiSheet<void>(
      context,
      builder: (sheetContext) {
        final c = UiColors.of(sheetContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(student.fullName, style: UiText.h2.copyWith(color: c.ink)),
            const SizedBox(height: UiSpace.xs),
            Text(_subtitleFor(student), style: UiText.label.copyWith(color: c.muted)),
            const SizedBox(height: UiSpace.md),
            if (student.hasDevice)
              UiNavRow(
                title: 'Desvincular celular',
                subtitle: 'Podrá vincular otro desde «Inscribir estudiantes»',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmUnbind(student);
                },
              ),
            UiNavRow(
              title: kind == StudentRemovalKind.delete ? 'Eliminar de la clase' : 'Retirar de la clase',
              subtitle: kind == StudentRemovalKind.delete
                  ? 'No tiene asistencias: se borra por completo'
                  : 'Su historial se conserva en los reportes',
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmRemoval(student, kind);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmUnbind(StudentModel student) async {
    final ok = await showUiConfirm(
      context,
      title: '¿Desvincular el celular?',
      message:
          'El celular de ${student.fullName} dejará de servir para marcar asistencia en esta clase. Podrá vincular otro desde «Inscribir estudiantes».',
      confirmLabel: 'Desvincular',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _admin.unbindDevice(student);
      if (mounted) showUiSnack(context, 'Celular desvinculado.');
    } catch (e) {
      debugPrint('No se pudo desvincular: $e');
      if (mounted) showUiSnack(context, 'No se pudo desvincular. Inténtalo de nuevo.');
    }
    await _loadStudents();
  }

  /// Doble confirmación: aviso con las consecuencias y luego escribir el primer nombre.
  Future<void> _confirmRemoval(StudentModel student, StudentRemovalKind kind) async {
    final isDelete = kind == StudentRemovalKind.delete;
    final count = isDelete ? 0 : await _admin.attendanceCount(student);
    if (!mounted) return;
    final first = await showUiConfirm(
      context,
      title: isDelete ? '¿Eliminar a ${student.fullName}?' : '¿Retirar a ${student.fullName}?',
      message: isDelete
          ? 'No tiene asistencias registradas. Se borrará de la clase y su celular dejará de servir.'
          : 'Tiene ${UiFormat.count(count, 'asistencia registrada', 'asistencias registradas')}. '
              'Saldrá de la lista y de las sesiones nuevas, pero su historial se conserva en los reportes y el Excel. '
              'Su celular dejará de servir para esta clase.',
      confirmLabel: 'Continuar',
      destructive: true,
    );
    if (!first || !mounted) return;

    final confirmed = await showUiSheet<bool>(
      context,
      builder: (_) => _TypeNameToConfirm(student: student, actionLabel: isDelete ? 'Eliminar' : 'Retirar'),
    );
    if (confirmed != true) return;
    try {
      final done = await _admin.remove(student);
      if (mounted) {
        showUiSnack(
          context,
          done == StudentRemovalKind.delete
              ? '${student.fullName} fue eliminado de la clase.'
              : '${student.fullName} fue retirado de la clase.',
        );
      }
    } catch (e) {
      debugPrint('No se pudo quitar al estudiante: $e');
      if (mounted) showUiSnack(context, 'No se pudo completar. Inténtalo de nuevo.');
    }
    await _loadStudents();
  }

  String _subtitleFor(StudentModel student) {
    final parts = <String>[student.studentCode];
    if (student.isRetired) {
      final when = DateTime.tryParse(student.retiredAt ?? '');
      parts.add(when == null ? 'Retirado' : 'Retirado el ${UiFormat.shortDate(when.toLocal())}');
    } else {
      parts.add(student.hasDevice ? 'Celular vinculado' : 'Sin celular');
      if (student.wasAddedInClass) parts.add('Agregado en clase');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    final bound = _students.where((s) => s.hasDevice).length;
    final Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_students.isEmpty && _retired.isEmpty) {
      body = UiEmptyState(
        icon: Icons.group_add_outlined,
        title: 'Aún no hay estudiantes',
        message: 'Inscríbelos con el código de la clase, o carga primero tu lista.',
        actionLabel: 'Inscribir estudiantes',
        onAction: _openEnrollment,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadStudents,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.xl),
          children: [
            if (_students.isNotEmpty) ...[
              Text(
                '${UiFormat.count(_students.length, 'estudiante', 'estudiantes')} · $bound con celular vinculado',
                style: UiText.label.copyWith(color: c.muted),
              ),
              const SizedBox(height: UiSpace.sm),
              UiListGroup(
                children: [
                  for (final student in _students)
                    UiPersonRow(
                      name: student.fullName,
                      subtitle: _subtitleFor(student),
                      avatarTone: student.hasDevice ? UiTone.tint : UiTone.neutral,
                      onTap: () => _showStudentOptions(student),
                      trailing: UiRoundIconButton(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'Opciones de ${student.fullName}',
                        onPressed: () => _showStudentOptions(student),
                      ),
                    ),
                ],
              ),
            ],
            if (_retired.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: UiSpace.xl, bottom: UiSpace.sm),
                child: Text('Retirados (${_retired.length})', style: UiText.title.copyWith(color: c.ink)),
              ),
              UiListGroup(
                children: [
                  for (final student in _retired)
                    UiPersonRow(
                      name: student.fullName,
                      subtitle: _subtitleFor(student),
                      avatarTone: UiTone.neutral,
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: UiSpace.sm),
                child: Text(
                  'Si alguno vuelve, se inscribe de nuevo y lo apruebas.',
                  style: UiText.label.copyWith(color: c.muted),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return UiPage(
      header: UiTopBar(
        title: 'Estudiantes',
        subtitle: widget.course.name,
        onBack: () => Navigator.of(context).pop(),
        trailing: UiRoundIconButton(
          icon: Icons.playlist_add_rounded,
          tooltip: 'Agregar a la lista',
          onPressed: _openImportModal,
        ),
      ),
      bottom: UiButton(
        label: 'Inscribir estudiantes',
        icon: Icons.qr_code_2_rounded,
        onPressed: _openEnrollment,
      ),
      body: body,
    );
  }
}

/// Segunda confirmación: escribir el primer nombre del estudiante.
class _TypeNameToConfirm extends StatefulWidget {
  const _TypeNameToConfirm({required this.student, required this.actionLabel});

  final StudentModel student;
  final String actionLabel;

  @override
  State<_TypeNameToConfirm> createState() => _TypeNameToConfirmState();
}

class _TypeNameToConfirmState extends State<_TypeNameToConfirm> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    final firstName = StudentAdminService.firstNameOf(widget.student);
    final matches = StudentAdminService.confirmsFirstName(widget.student, _typed.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirma escribiendo su nombre', style: UiText.h2.copyWith(color: c.ink)),
        const SizedBox(height: UiSpace.xs),
        Text('Escribe «$firstName» para continuar.', style: UiText.body.copyWith(color: c.muted)),
        const SizedBox(height: UiSpace.lg),
        TextField(
          controller: _typed,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Primer nombre'),
        ),
        const SizedBox(height: UiSpace.lg),
        UiButton(
          label: widget.actionLabel,
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
