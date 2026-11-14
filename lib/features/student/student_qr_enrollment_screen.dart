import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/crypto/enrollment_packet_codec.dart';
import '../../core/models/student_enrollment_model.dart';
import '../../data/local/app_database.dart';
import '../../data/services/ble_attendance_service.dart';
import '../../data/services/ble_permission_service.dart';
import '../../data/services/enrollment_client_service.dart';
import '../../ui/ui.dart';
import '../shared/ble_ready_gate.dart';

enum _JoinStep { scan, form, waiting, done }

/// "Unirme a una clase": escanear el QR de la clase, escribir el código
/// estudiantil y esperar la respuesta del profesor por Bluetooth.
///
/// Devuelve la inscripción guardada al cerrarse con éxito.
class StudentQrEnrollmentScreen extends StatefulWidget {
  const StudentQrEnrollmentScreen({
    super.key,
    this.database,
    this.bleService,
    this.permissionService,
    this.initialInvite,
    this.clientService,
  });

  final AppDatabase? database;
  final BleAttendanceService? bleService;
  final BlePermissionService? permissionService;

  /// Salta el escaneo (pruebas, o si el código llega por otro medio).
  final ClassInvite? initialInvite;

  /// Para pruebas: reemplaza el servicio de inscripción.
  final EnrollmentClientService? clientService;

  @override
  State<StudentQrEnrollmentScreen> createState() => _StudentQrEnrollmentScreenState();
}

class _StudentQrEnrollmentScreenState extends State<StudentQrEnrollmentScreen> {
  late final AppDatabase _database;
  late final BleAttendanceService _ble;
  late final bool _ownsBle;
  late final BlePermissionService _permissions;
  late final EnrollmentClientService _client;

  MobileScannerController? _scanner;
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _paste = TextEditingController();

  _JoinStep _step = _JoinStep.scan;
  ClassInvite? _invite;
  bool _torchOn = false;
  bool _handlingScan = false;
  String? _scanError;
  String? _codeError;
  String? _nameError;
  String? _bleIssue;

  StreamSubscription<EnrollmentClientUpdate>? _updates;
  StreamSubscription<BleRuntimeIssue>? _issueSub;
  EnrollmentClientPhase _phase = EnrollmentClientPhase.searching;
  StudentEnrollmentModel? _enrollment;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase.instance;
    _ownsBle = widget.bleService == null;
    _ble = widget.bleService ?? BleAttendanceService(minRssiDbm: AppConstants.enrollmentMinRssiDbm);
    _permissions = widget.permissionService ?? BlePermissionService();
    _client = widget.clientService ?? EnrollmentClientService(database: _database, bleService: _ble);
    _issueSub = _ble.issues.listen((issue) {
      if (mounted) setState(() => _bleIssue = issue.message);
    });
    final invite = widget.initialInvite;
    if (invite != null) {
      _invite = invite;
      _step = _JoinStep.form;
    } else {
      _scanner = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _issueSub?.cancel();
    unawaited(_client.cancel().then((_) async {
      if (_ownsBle) await _ble.dispose();
    }));
    _releaseScreen();
    _scanner?.dispose();
    _code.dispose();
    _name.dispose();
    _paste.dispose();
    super.dispose();
  }

  void _keepScreenOn() {
    unawaited(WakelockPlus.enable().catchError((Object error) {
      debugPrint('No se pudo mantener la pantalla encendida: $error');
    }));
  }

  void _releaseScreen() {
    unawaited(WakelockPlus.disable().catchError((Object error) {
      debugPrint('No se pudo liberar la pantalla: $error');
    }));
  }

  // ---------------------------------------------------------------------------
  // Paso 1 · Escanear
  // ---------------------------------------------------------------------------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingScan || _step != _JoinStep.scan) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _handlingScan = true;
        _readInvite(raw);
        _handlingScan = false;
        break;
      }
    }
  }

  void _readInvite(String raw) {
    try {
      final invite = ClassInvite.parse(raw);
      unawaited(_scanner?.stop());
      setState(() {
        _invite = invite;
        _scanError = null;
        _step = _JoinStep.form;
      });
    } on FormatException {
      setState(() {
        _scanError = 'Ese código no es de una clase. Pídele a tu profesor que abra «Inscribir estudiantes» y te lo muestre.';
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scanner?.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (error) {
      debugPrint('No se pudo cambiar la linterna: $error');
      if (mounted) showUiSnack(context, 'No se pudo activar la linterna.');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scanner?.switchCamera();
    } catch (error) {
      debugPrint('No se pudo cambiar de cámara: $error');
      if (mounted) showUiSnack(context, 'No se pudo cambiar de cámara.');
    }
  }

  Future<void> _showPasteSheet() async {
    _paste.clear();
    final raw = await showUiSheet<String>(
      context,
      builder: (sheetContext) {
        final c = UiColors.of(sheetContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pegar el código', style: UiText.h2.copyWith(color: c.ink)),
            const SizedBox(height: UiSpace.xs),
            Text(
              'Si tu profesor te envió el código de la clase como texto, pégalo aquí.',
              style: UiText.label.copyWith(color: c.muted),
            ),
            const SizedBox(height: UiSpace.lg),
            TextField(
              controller: _paste,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Código de la clase'),
            ),
            const SizedBox(height: UiSpace.md),
            UiButton(
              label: 'Pegar',
              icon: Icons.content_paste_rounded,
              variant: UiButtonVariant.tonal,
              compact: true,
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                _paste.text = data?.text ?? '';
              },
            ),
            const SizedBox(height: UiSpace.sm),
            UiButton(label: 'Usar este código', onPressed: () => Navigator.of(sheetContext).pop(_paste.text)),
          ],
        );
      },
    );
    if (raw != null && raw.trim().isNotEmpty && mounted) _readInvite(raw);
  }

  // ---------------------------------------------------------------------------
  // Paso 2 · Código y nombre
  // ---------------------------------------------------------------------------

  void _submitForm() {
    final code = _code.text.trim();
    final name = _name.text.trim();
    setState(() {
      _codeError = EnrollmentPacketCodec.isValidStudentCode(code) ? null : 'Escribe tu código estudiantil, solo números.';
      _nameError = name.isEmpty ? 'Escribe tu nombre.' : null;
    });
    if (_codeError != null || _nameError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = _JoinStep.waiting);
  }

  // ---------------------------------------------------------------------------
  // Paso 3 · Esperar al profesor
  // ---------------------------------------------------------------------------

  void _startRequest() {
    _keepScreenOn();
    setState(() {
      _phase = EnrollmentClientPhase.searching;
      _bleIssue = null;
    });
    _updates?.cancel();
    _updates = _client
        .request(invite: _invite!, studentCode: _code.text.trim(), displayName: _name.text.trim())
        .listen(
      (update) {
        if (!mounted) return;
        setState(() {
          _phase = update.phase;
          _enrollment = update.enrollment ?? _enrollment;
          if (update.isFinal) _step = _JoinStep.done;
        });
        if (update.isFinal) {
          _releaseScreen();
          if (update.phase == EnrollmentClientPhase.accepted) {
            unawaited(HapticFeedback.mediumImpact().catchError((Object error) {
              debugPrint('Sin vibración disponible: $error');
            }));
          }
        }
      },
      onError: (Object error) {
        debugPrint('Inscripción: error en la solicitud: $error');
        if (!mounted) return;
        setState(() {
          _phase = EnrollmentClientPhase.timedOut;
          _step = _JoinStep.done;
        });
        _releaseScreen();
      },
    );
  }

  Future<void> _cancelRequest() async {
    await _updates?.cancel();
    _updates = null;
    await _client.cancel();
    _releaseScreen();
    if (mounted) setState(() => _step = _JoinStep.form);
  }

  void _retry() => setState(() => _step = _JoinStep.waiting);

  void _close() => Navigator.of(context).pop(_enrollment);

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _JoinStep.scan => _buildScan(context),
      _JoinStep.form => _buildForm(context),
      _JoinStep.waiting => BleReadyGate(
          permissionService: _permissions,
          title: 'Unirme a una clase',
          subtitle: _invite?.courseName,
          purpose: 'unirte a la clase',
          onBack: () => setState(() => _step = _JoinStep.form),
          onReady: _startRequest,
          builder: _buildWaiting,
        ),
      _JoinStep.done => _buildDone(context),
    };
  }

  Widget _buildScan(BuildContext context) {
    final c = UiColors.of(context);
    return UiPage(
      header: UiTopBar(
        title: 'Unirme a una clase',
        onBack: () => Navigator.of(context).pop(),
        below: const UiStepBar(current: 1, total: 3),
      ),
      bottom: UiButton(label: 'Pegar el código', variant: UiButtonVariant.outline, onPressed: _showPasteSheet),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.lg),
        children: [
          if (_scanError != null) ...[
            UiBanner(tone: UiBannerTone.error, message: _scanError!),
            const SizedBox(height: UiSpace.md),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(UiRadius.xxl),
                  border: Border.all(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scanner,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        debugPrint('Error de cámara: $error');
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(UiSpace.md),
                            child: UiBanner(
                              tone: UiBannerTone.warning,
                              title: 'Cámara no disponible',
                              message: 'Revisa el permiso de la cámara o pega el código de la clase.',
                              actionLabel: 'Pegar el código',
                              onAction: _showPasteSheet,
                            ),
                          ),
                        );
                      },
                    ),
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(UiRadius.lg),
                            border: Border.all(color: c.primary, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: UiSpace.md),
          Text(
            'Apunta al código QR que te muestra tu profesor.',
            textAlign: TextAlign.center,
            style: UiText.body.copyWith(color: c.muted),
          ),
          const SizedBox(height: UiSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UiRoundIconButton(
                icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                tooltip: _torchOn ? 'Apagar linterna' : 'Encender linterna',
                onPressed: _toggleTorch,
              ),
              const SizedBox(width: UiSpace.md),
              UiRoundIconButton(
                icon: Icons.cameraswitch_rounded,
                tooltip: 'Cambiar cámara',
                onPressed: _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final c = UiColors.of(context);
    final invite = _invite!;
    return UiPage(
      header: UiTopBar(
        title: 'Unirme a una clase',
        onBack: () => Navigator.of(context).pop(),
        below: const UiStepBar(current: 2, total: 3),
      ),
      bottom: UiButton(label: 'Unirme', onPressed: _submitForm),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.lg),
        children: [
          UiCard(
            tone: UiTone.tint,
            radius: UiRadius.lg,
            child: Row(
              children: [
                UiAvatar(name: invite.courseName, square: true, tone: UiTone.primary),
                const SizedBox(width: UiSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Te vas a unir a', style: UiText.label),
                      Text(invite.courseName, style: UiText.title),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: UiSpace.xl),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            decoration: InputDecoration(
              labelText: 'Tu código estudiantil',
              hintText: 'Ej. 0182120016',
              errorText: _codeError,
            ),
          ),
          const SizedBox(height: UiSpace.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitForm(),
            decoration: InputDecoration(labelText: 'Tu nombre', hintText: 'Como quieres verlo en la app', errorText: _nameError),
          ),
          const SizedBox(height: UiSpace.md),
          Text(
            'El nombre es solo para ti. Tu profesor te identifica por el código.',
            style: UiText.label.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
    final c = UiColors.of(context);
    final pending = _phase == EnrollmentClientPhase.pending;
    return UiPage(
      header: UiTopBar(
        title: _invite!.courseName,
        titleMaxLines: 1,
        close: true,
        backTooltip: 'Cancelar',
        onBack: _cancelRequest,
        below: const UiStepBar(current: 3, total: 3),
      ),
      bottom: UiButton(label: 'Cancelar', variant: UiButtonVariant.outline, onPressed: _cancelRequest),
      body: ListView(
        padding: const EdgeInsets.only(bottom: UiSpace.lg),
        children: [
          UiPageHeading(title: pending ? 'Tu profesor está revisando tu solicitud' : 'Buscando a tu profesor'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCard(
                  tone: UiTone.tint,
                  radius: UiRadius.xxl,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: UiSpace.sm,
                          runSpacing: UiSpace.sm,
                          children: [
                            UiPill(label: 'Código ${_code.text.trim()}', background: c.surface, foreground: c.ink),
                            UiPill(
                              label: pending ? 'Esperando aprobación' : 'Enviando solicitud',
                              dot: true,
                              tone: UiTone.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: UiSpace.xxl),
                      UiTwoPhones(signal: pending ? 3 : 2),
                    ],
                  ),
                ),
                const SizedBox(height: UiSpace.lg),
                Text(
                  pending
                      ? 'Tu código no estaba en su lista o ya tenía otro celular. Acércate y dile quién eres.'
                      : 'Quédate en el salón con esta pantalla abierta. Tu profesor debe tener abierto «Inscribir estudiantes».',
                  style: UiText.body.copyWith(color: c.muted),
                ),
                if (_bleIssue != null) ...[
                  const SizedBox(height: UiSpace.md),
                  UiBanner(tone: UiBannerTone.warning, message: _bleIssue!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final c = UiColors.of(context);
    if (_phase == EnrollmentClientPhase.accepted) {
      return UiPage(
        header: UiTopBar(title: 'Unirme a una clase', onBack: _close, close: true),
        bottom: UiButton(label: 'Ir a mis clases', onPressed: _close),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.lg),
          children: [
            UiHeroCard(
              motifSize: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: c.onPrimary, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 34, color: c.primary),
                  ),
                  const SizedBox(height: 72),
                  const Text('Ya estás en', style: UiText.bodyStrong),
                  Text(_invite!.courseName, style: UiText.h1),
                ],
              ),
            ),
            const SizedBox(height: UiSpace.md),
            UiListGroup(
              children: [
                UiInfoRow(label: 'Código', value: _code.text.trim()),
                UiInfoRow(label: 'Tu nombre', value: _name.text.trim()),
              ],
            ),
            const SizedBox(height: UiSpace.lg),
            Text(
              'Desde ahora, en cada clase solo escribes el PIN y acercas el celular.',
              style: UiText.body.copyWith(color: c.muted),
            ),
          ],
        ),
      );
    }

    final (IconData icon, String title, String message) = switch (_phase) {
      EnrollmentClientPhase.rejected => (
          Icons.person_off_outlined,
          'Tu profesor no aprobó la solicitud',
          'Habla con él y vuelve a intentarlo.',
        ),
      EnrollmentClientPhase.classFull => (
          Icons.groups_2_outlined,
          'La clase ya está completa',
          'Una clase admite hasta 64 estudiantes. Habla con tu profesor.',
        ),
      _ => (
          Icons.bluetooth_searching_rounded,
          'No encontramos a tu profesor',
          'Acércate y pídele que abra «Inscribir estudiantes». Luego inténtalo de nuevo.',
        ),
    };
    return UiPage(
      header: UiTopBar(title: 'Unirme a una clase', onBack: () => Navigator.of(context).pop(), close: true),
      body: UiEmptyState(
        icon: icon,
        title: title,
        message: message,
        actionLabel: 'Intentar de nuevo',
        onAction: _retry,
      ),
    );
  }
}
