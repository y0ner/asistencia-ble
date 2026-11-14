import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/course_model.dart';
import '../../data/local/app_database.dart';
import '../../data/services/ble_attendance_service.dart';
import '../../data/services/ble_permission_service.dart';
import '../../data/services/enrollment_host_service.dart';
import '../../ui/ui.dart';
import '../shared/ble_ready_gate.dart';

/// "Inscribir estudiantes": un solo QR para toda la clase.
///
/// Los estudiantes de la lista entran solos; lo demás (fuera de lista, cambio
/// de celular, retirados que vuelven) espera la decisión del docente.
class EnrollmentHostScreen extends StatefulWidget {
  const EnrollmentHostScreen({
    super.key,
    required this.course,
    this.database,
    this.bleService,
    this.permissionService,
    this.hostService,
  });

  final CourseModel course;
  final AppDatabase? database;
  final BleAttendanceService? bleService;
  final BlePermissionService? permissionService;

  /// Para pruebas: reemplaza el servicio de inscripción.
  final EnrollmentHostService? hostService;

  @override
  State<EnrollmentHostScreen> createState() => _EnrollmentHostScreenState();
}

class _EnrollmentHostScreenState extends State<EnrollmentHostScreen> {
  late final BleAttendanceService _ble;
  late final bool _ownsBle;
  late final BlePermissionService _permissions;
  late final EnrollmentHostService _host;

  StreamSubscription<EnrollmentHostState>? _stateSub;
  StreamSubscription<BleRuntimeIssue>? _issueSub;
  EnrollmentHostState _state = const EnrollmentHostState();
  String? _qrPayload;
  String? _startError;
  String? _bleIssue;

  @override
  void initState() {
    super.initState();
    _ownsBle = widget.bleService == null;
    _ble = widget.bleService ?? BleAttendanceService(minRssiDbm: AppConstants.enrollmentMinRssiDbm);
    _permissions = widget.permissionService ?? BlePermissionService();
    _host = widget.hostService ??
        EnrollmentHostService(
          course: widget.course,
          database: widget.database ?? AppDatabase.instance,
          bleService: _ble,
        );
  }

  Future<void> _start() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      debugPrint('No se pudo mantener la pantalla encendida: $error');
    }
    _stateSub = _host.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _issueSub = _ble.issues.listen((issue) {
      if (mounted) setState(() => _bleIssue = issue.message);
    });
    try {
      final payload = await _host.buildClassQrPayload();
      await _host.start();
      if (!mounted) return;
      setState(() {
        _qrPayload = payload;
        _state = _host.state;
        _startError = null;
      });
    } catch (error) {
      debugPrint('No se pudo abrir la inscripción: $error');
      if (mounted) setState(() => _startError = 'No se pudo abrir la inscripción. Inténtalo de nuevo.');
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _issueSub?.cancel();
    unawaited(_host.dispose().then((_) async {
      if (_ownsBle) await _ble.dispose();
    }));
    unawaited(WakelockPlus.disable().catchError((Object error) {
      debugPrint('No se pudo liberar la pantalla: $error');
    }));
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on StateError catch (error) {
      if (mounted) showUiSnack(context, error.message);
    } catch (error) {
      debugPrint('Inscripción: acción fallida: $error');
      if (mounted) showUiSnack(context, 'No se pudo completar. Inténtalo de nuevo.');
    }
  }

  Future<void> _approve(PendingEnrollment pending) async {
    final existing = pending.existingStudent;
    final result = await showUiSheet<({String name, String? email})>(
      context,
      builder: (_) => _ApproveSheet(
        studentCode: pending.studentCode,
        initialName: existing?.fullName ?? '',
        initialEmail: existing?.email ?? '',
        returning: pending.kind == PendingEnrollmentKind.retiredReturning,
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final student = await _host.approve(pending.requestId, fullName: result.name, email: result.email);
      if (mounted) showUiSnack(context, '${student.fullName} ya está en la clase.');
    });
  }

  Future<void> _replace(PendingEnrollment pending) async {
    final name = pending.existingStudent?.fullName ?? 'Este estudiante';
    final ok = await showUiConfirm(
      context,
      title: '¿Reemplazar el celular?',
      message: '$name ya tiene un celular vinculado. Si lo reemplazas, el anterior dejará de servir para marcar asistencia.',
      confirmLabel: 'Reemplazar',
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await _host.replaceDevice(pending.requestId);
      if (mounted) showUiSnack(context, 'Celular reemplazado.');
    });
  }

  Future<void> _reject(PendingEnrollment pending) => _run(() => _host.reject(pending.requestId));

  @override
  Widget build(BuildContext context) {
    return BleReadyGate(
      permissionService: _permissions,
      title: 'Inscribir estudiantes',
      subtitle: widget.course.name,
      purpose: 'inscribir a tus estudiantes',
      onBack: () => Navigator.of(context).pop(),
      onReady: _start,
      builder: _buildReady,
    );
  }

  Widget _buildReady(BuildContext context) {
    final c = UiColors.of(context);
    final total = _state.totalStudents;
    final bound = _state.boundCount;
    final isFull = total >= AppConstants.bitmapBitCount;

    return UiPage(
      header: UiTopBar(
        title: 'Inscribir estudiantes',
        subtitle: widget.course.name,
        close: true,
        backTooltip: 'Terminar inscripción',
        onBack: () => Navigator.of(context).pop(),
      ),
      bottom: UiButton(
        label: 'Terminar inscripción',
        variant: UiButtonVariant.outline,
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.xl),
        children: [
          if (_startError != null) ...[
            UiBanner(
              tone: UiBannerTone.error,
              message: _startError!,
              actionLabel: 'Volver a intentar',
              onAction: _start,
            ),
            const SizedBox(height: UiSpace.md),
          ],
          if (_bleIssue != null) ...[
            UiBanner(tone: UiBannerTone.warning, message: _bleIssue!),
            const SizedBox(height: UiSpace.md),
          ],
          UiCard(
            radius: UiRadius.xl,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(UiSpace.md),
                  decoration: BoxDecoration(
                    color: UiColors.light.surface,
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    border: Border.all(color: c.line),
                  ),
                  // Tamaño fijo: QrImageView no puede medirse por adelantado.
                  child: SizedBox.square(
                    dimension: 220,
                    child: _qrPayload == null
                        ? const Center(child: CircularProgressIndicator())
                        : QrImageView(
                            data: _qrPayload!,
                            version: QrVersions.auto,
                            size: 220,
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: UiColors.light.ink),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: UiColors.light.ink,
                            ),
                            semanticsLabel: 'Código QR de la clase',
                          ),
                  ),
                ),
                const SizedBox(height: UiSpace.md),
                Text('Código de la clase', style: UiText.title.copyWith(color: c.ink)),
                const SizedBox(height: UiSpace.xs),
                Text(
                  'Muéstralo o proyéctalo. Cada estudiante abre Asistencia Estudiante, toca «Unirme a una clase», lo escanea y escribe su código.',
                  textAlign: TextAlign.center,
                  style: UiText.label.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: UiSpace.md),
          UiCard(
            radius: UiRadius.xl,
            child: Row(
              children: [
                UiProgressRing.count(count: bound, total: total, size: 96),
                const SizedBox(width: UiSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inscritos', style: UiText.title.copyWith(color: c.ink)),
                      const SizedBox(height: UiSpace.xs),
                      Text(
                        total == 0
                            ? 'Aún no tienes lista. Cada estudiante que escanee aparecerá abajo para que lo apruebes.'
                            : bound == total
                                ? 'Todos los de tu lista ya vincularon su celular.'
                                : 'Los de tu lista entran solos. Faltan ${total - bound}.',
                        style: UiText.label.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isFull) ...[
            const SizedBox(height: UiSpace.md),
            const UiBanner(
              tone: UiBannerTone.warning,
              title: 'La clase ya está completa',
              message: 'Una clase admite hasta 64 estudiantes. No se pueden agregar más.',
            ),
          ],
          if (_state.pending.isNotEmpty) ...[
            _SectionLabel('Por aprobar (${_state.pending.length})'),
            for (final pending in _state.pending) ...[
              _PendingCard(
                pending: pending,
                onApprove: () => _approve(pending),
                onReplace: () => _replace(pending),
                onReject: () => _reject(pending),
              ),
              const SizedBox(height: UiSpace.sm),
            ],
          ],
          if (_state.recentlyEnrolled.isNotEmpty) ...[
            const _SectionLabel('Acaban de inscribirse'),
            UiListGroup(
              children: [
                for (final student in _state.recentlyEnrolled.take(8))
                  UiPersonRow(
                    name: student.fullName,
                    subtitle: student.studentCode,
                    trailing: const UiPill(label: 'Vinculado', icon: Icons.check_rounded),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: UiSpace.xl, bottom: UiSpace.sm),
      child: Semantics(header: true, child: Text(text, style: UiText.title.copyWith(color: c.ink))),
    );
  }
}

/// Tarjeta de una solicitud que espera la decisión del docente.
class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.pending,
    required this.onApprove,
    required this.onReplace,
    required this.onReject,
  });

  final PendingEnrollment pending;
  final VoidCallback onApprove;
  final VoidCallback onReplace;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    final name = pending.existingStudent?.fullName;
    final (String title, String message, String action, VoidCallback onAction) = switch (pending.kind) {
      PendingEnrollmentKind.notInRoster => (
          'Código ${pending.studentCode}',
          'No está en tu lista. Pregunta quién es y agrégalo con su nombre.',
          'Agregar',
          onApprove,
        ),
      PendingEnrollmentKind.deviceConflict => (
          name ?? 'Código ${pending.studentCode}',
          'Ya tiene un celular vinculado y está pidiendo entrar con otro.',
          'Reemplazar',
          onReplace,
        ),
      PendingEnrollmentKind.retiredReturning => (
          name ?? 'Código ${pending.studentCode}',
          'Lo retiraste de la clase y quiere volver.',
          'Aceptar',
          onApprove,
        ),
    };
    return UiCard(
      tone: UiTone.manual,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UiText.bodyStrong),
          const SizedBox(height: 2),
          Text(message, style: UiText.label),
          const SizedBox(height: UiSpace.md),
          Row(
            children: [
              Expanded(child: UiButton(label: action, compact: true, onPressed: onAction)),
              const SizedBox(width: UiSpace.sm),
              Expanded(
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: UiButton(
                    label: 'Rechazar',
                    variant: UiButtonVariant.outline,
                    compact: true,
                    onPressed: onReject,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hoja para escribir el nombre y el correo de quien se va a aceptar.
class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({
    required this.studentCode,
    required this.initialName,
    required this.initialEmail,
    required this.returning,
  });

  final String studentCode;
  final String initialName;
  final String initialEmail;
  final bool returning;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final emailOk = email.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    setState(() {
      _nameError = name.isEmpty ? 'Escribe el nombre completo.' : null;
      _emailError = emailOk ? null : 'Revisa el correo.';
    });
    if (name.isEmpty || !emailOk) return;
    Navigator.of(context).pop((name: name, email: email.isEmpty ? null : email));
  }

  @override
  Widget build(BuildContext context) {
    final c = UiColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.returning ? 'Volver a la clase' : 'Agregar a la clase', style: UiText.h2.copyWith(color: c.ink)),
        const SizedBox(height: UiSpace.xs),
        Text('Código ${widget.studentCode}', style: UiText.label.copyWith(color: c.muted)),
        const SizedBox(height: UiSpace.lg),
        TextField(
          controller: _name,
          autofocus: widget.initialName.isEmpty,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: 'Nombre completo', errorText: _nameError),
        ),
        const SizedBox(height: UiSpace.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Correo (opcional)',
            hintText: 'nombre${AppConstants.institutionalDomain}',
            errorText: _emailError,
          ),
        ),
        const SizedBox(height: UiSpace.lg),
        UiButton(label: widget.returning ? 'Aceptar' : 'Agregar y aceptar', onPressed: _submit),
      ],
    );
  }
}
