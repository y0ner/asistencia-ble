import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'how_it_works_content.dart';

/// Recorrido paso a paso de "Cómo funciona": un dibujo, quién lo hace y qué
/// se hace en cada paso.
///
/// Pendiente de construir (brief `H1-C`). El constructor ya es definitivo.
class HowItWorksTourScreen extends StatefulWidget {
  const HowItWorksTourScreen({
    super.key,
    required this.content,
    required this.steps,
    this.title = HowItWorksContent.screenTitle,
    this.firstRun = false,
    this.onFinished,
  });

  final HowItWorksContent content;

  /// Pasos a mostrar: el recorrido completo o los de un tema.
  final List<HowStep> steps;
  final String title;

  /// `true` cuando se muestra sola la primera vez que se abre la app: ofrece
  /// «Saltar» y no tiene botón de volver.
  final bool firstRun;

  /// Se llama al tocar «Entendido» o «Saltar». Si es nulo, la pantalla se
  /// cierra con `Navigator.pop`.
  final VoidCallback? onFinished;

  @override
  State<HowItWorksTourScreen> createState() => _HowItWorksTourScreenState();
}

class _HowItWorksTourScreenState extends State<HowItWorksTourScreen> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.steps.isNotEmpty, 'widget.steps no puede estar vacío');
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(HowItWorksTourScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.steps.isNotEmpty, 'widget.steps no puede estar vacío');
    if (widget.steps != oldWidget.steps) {
      _index = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } else if (_index >= widget.steps.length) {
      _index = widget.steps.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPage(int page) {
    setState(() => _index = page);
    if (_pageController.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pageController.jumpToPage(page);
      } else {
        _pageController.animateToPage(
          page,
          duration: UiMotion.base,
          curve: UiMotion.curve,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.steps.isNotEmpty, 'widget.steps no puede estar vacío');
    final colors = UiColors.of(context);
    final totalSteps = widget.steps.length;

    final Widget bar;
    if (!widget.firstRun) {
      bar = UiTopBar(
        title: widget.title,
        titleMaxLines: 1,
        onBack: () => Navigator.of(context).pop(),
      );
    } else {
      bar = Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UiSize.touch),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UiText.label.copyWith(color: colors.muted),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: UiSize.touch),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: UiSpace.sm),
                    minimumSize: const Size(0, UiSize.touch),
                  ),
                  child: Text(
                    HowItWorksContent.skip,
                    style: UiText.button.copyWith(color: colors.primaryText),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Widget? progress;
    if (totalSteps > 1) {
      final tramos = <Widget>[];
      for (var i = 0; i < totalSteps; i++) {
        if (i > 0) {
          final isGap = widget.steps[i].section == HowSection.everyClass &&
              widget.steps[i - 1].section == HowSection.once;
          tramos.add(SizedBox(width: isGap ? 14 : 6));
        }
        final Color tramoColor;
        if (i <= _index) {
          tramoColor = widget.steps[i].section == HowSection.once
              ? colors.manualDot
              : colors.primary;
        } else {
          tramoColor = colors.line;
        }
        tramos.add(
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: tramoColor,
                borderRadius: BorderRadius.circular(UiRadius.pill),
              ),
            ),
          ),
        );
      }

      progress = Semantics(
        label: HowItWorksContent.stepCounter(_index + 1, totalSteps),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: Row(children: tramos),
          ),
        ),
      );
    } else {
      progress = null;
    }

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        if (progress != null) ...[
          const SizedBox(height: 6),
          progress,
          const SizedBox(height: 6),
        ],
      ],
    );

    final body = PageView.builder(
      controller: _pageController,
      onPageChanged: (page) => setState(() => _index = page),
      itemCount: totalSteps,
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            UiSpace.page,
            UiSpace.lg,
            UiSpace.page,
            UiSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step.section != null) ...[
                UiPill(
                  label: widget.content.sectionLabel(step.section!),
                  tone: step.section == HowSection.once
                      ? UiTone.manual
                      : UiTone.tint,
                ),
                const SizedBox(height: UiSpace.md),
              ],
              SizedBox(
                width: double.infinity,
                child: UiScene(
                  kind: step.scene,
                  studentView: widget.content.studentView,
                ),
              ),
              const SizedBox(height: UiSpace.md),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: UiSpace.sm,
                  runSpacing: UiSpace.xs,
                  children: [
                    _ActorBadge(step: step, content: widget.content),
                    if (totalSteps > 1)
                      Text(
                        HowItWorksContent.stepCounter(index + 1, totalSteps),
                        style: UiText.label.copyWith(color: colors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: UiSpace.md),
              Text(step.title, style: UiText.h1.copyWith(color: colors.ink)),
              const SizedBox(height: UiSpace.md),
              Text(step.body, style: UiText.body.copyWith(color: colors.muted)),
              if (step.tip != null) ...[
                const SizedBox(height: UiSpace.md),
                Container(
                  padding: const EdgeInsets.all(UiSpace.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.line),
                    borderRadius: BorderRadius.circular(UiRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 22,
                        color: colors.manualText,
                      ),
                      const SizedBox(width: UiSpace.md),
                      Expanded(
                        child: Text(
                          step.tip!,
                          style: UiText.label.copyWith(color: colors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    final isLast = _index == totalSteps - 1;
    final bottom = Row(
      children: [
        if (_index > 0) ...[
          Expanded(
            child: UiButton(
              label: HowItWorksContent.back,
              variant: UiButtonVariant.outline,
              onPressed: () => _goToPage(_index - 1),
            ),
          ),
          const SizedBox(width: UiSpace.md),
        ],
        Expanded(
          flex: 2,
          child: UiButton(
            label: isLast ? HowItWorksContent.done : HowItWorksContent.next,
            onPressed: isLast ? _finish : () => _goToPage(_index + 1),
          ),
        ),
      ],
    );

    return UiPage(
      header: header,
      body: body,
      bottom: bottom,
    );
  }
}

class _ActorBadge extends StatelessWidget {
  const _ActorBadge({required this.step, required this.content});

  final HowStep step;
  final HowItWorksContent content;

  @override
  Widget build(BuildContext context) {
    final colors = UiColors.of(context);
    final text = content.actorLabel(step.actor);

    final Color bgColor;
    final Color textColor;
    final Border? border;
    final Widget icon;

    if (step.actor == HowActor.auto) {
      bgColor = colors.manualBg;
      textColor = colors.manualText;
      border = null;
      icon = Icon(
        Icons.check_circle_outline_rounded,
        size: 16,
        color: colors.manualText,
      );
    } else {
      final esProfesor = (step.actor == HowActor.you) != content.studentView;
      if (esProfesor) {
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        border = null;
        icon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            color: colors.onPrimary,
            borderRadius: BorderRadius.circular(3.5),
          ),
        );
      } else {
        bgColor = colors.surface;
        textColor = colors.ink;
        border = Border.all(color: colors.ink, width: 1.5);
        icon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(color: colors.ink, width: 2),
          ),
        );
      }
    }

    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: UiSpace.md, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(UiRadius.pill),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: UiSpace.sm),
              Text(
                text,
                style: UiText.label.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
