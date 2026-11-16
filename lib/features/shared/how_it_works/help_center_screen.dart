import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../hardware_diagnostic_dialog.dart';
import 'how_it_works_content.dart';
import 'how_it_works_tour_screen.dart';

/// Centro de ayuda: acceso al recorrido, temas, "Bueno saber" y "Si algo
/// falla".
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key, required this.content, this.onOpenPermissions});

  final HowItWorksContent content;

  /// Qué hacer al tocar «Permisos del celular». Por defecto abre
  /// `showHardwareDiagnosticDialog`. Las pruebas pasan uno propio.
  final void Function(BuildContext context)? onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    final colors = UiColors.of(context);

    return UiPage(
      header: UiTopBar(
        title: HowItWorksContent.helpTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: UiSpace.xxl),
        children: [
          // 1. Tarjeta del recorrido
          Padding(
            padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final isNarrow = constraints.maxWidth < 300 || textScale > 1.15;

                final textBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      HowItWorksContent.firstTime,
                      style: UiText.label.copyWith(color: colors.onPrimary),
                    ),
                    const SizedBox(height: UiSpace.xs),
                    Text(
                      content.tourIntro,
                      style: UiText.h2.copyWith(color: colors.onPrimary),
                    ),
                  ],
                );

                final scene = SizedBox(
                  width: isNarrow
                      ? (constraints.maxWidth < 220 ? constraints.maxWidth : 220)
                      : 132,
                  child: UiScene(
                    kind: UiSceneKind.acercar,
                    studentView: content.studentView,
                  ),
                );

                return UiHeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isNarrow)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: textBlock),
                            const SizedBox(width: UiSpace.md),
                            scene,
                          ],
                        )
                      else ...[
                        textBlock,
                        const SizedBox(height: UiSpace.md),
                        scene,
                      ],
                      const SizedBox(height: UiSpace.lg),
                      UiButton(
                        label: HowItWorksContent.openTour,
                        variant: UiButtonVariant.onHero,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HowItWorksTourScreen(
                                content: content,
                                steps: content.tour,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 2. Título de temas
          const UiSectionTitle(HowItWorksContent.topicsTitle),

          // 3. Temas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSingleColumn = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.15;

                if (isSingleColumn) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < content.topics.length; i++) ...[
                        if (i > 0) const SizedBox(height: UiSpace.md),
                        _TopicTile(topic: content.topics[i], content: content),
                      ],
                    ],
                  );
                }

                final rows = <Widget>[];
                for (var i = 0; i < content.topics.length; i += 2) {
                  if (i > 0) {
                    rows.add(const SizedBox(height: UiSpace.md));
                  }
                  final first = content.topics[i];
                  final second = i + 1 < content.topics.length ? content.topics[i + 1] : null;

                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _TopicTile(topic: first, content: content),
                          ),
                          const SizedBox(width: UiSpace.md),
                          if (second != null)
                            Expanded(
                              child: _TopicTile(topic: second, content: content),
                            )
                          else
                            const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ),
                  );
                }

                return Column(children: rows);
              },
            ),
          ),

          // 4. Título de Bueno saber
          const UiSectionTitle(HowItWorksContent.factsTitle),

          // 5. Bueno saber
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: UiListGroup(
              children: [
                for (final fact in content.facts) _FactRow(fact: fact),
              ],
            ),
          ),

          // 6. Título de Si algo falla
          const UiSectionTitle(HowItWorksContent.troubleTitle),

          // 7. Si algo falla
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpace.page),
            child: UiListGroup(
              children: [
                for (final topic in content.troubleshooting)
                  UiNavRow(
                    title: topic.title,
                    subtitle: topic.subtitle,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HowItWorksTourScreen(
                            content: content,
                            steps: topic.steps,
                            title: topic.title,
                          ),
                        ),
                      );
                    },
                  ),
                UiNavRow(
                  title: HowItWorksContent.permissionsTitle,
                  subtitle: HowItWorksContent.permissionsSubtitle,
                  onTap: () {
                    if (onOpenPermissions != null) {
                      onOpenPermissions!(context);
                    } else {
                      showHardwareDiagnosticDialog(context);
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
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.content});

  final HowTopic topic;
  final HowItWorksContent content;

  @override
  Widget build(BuildContext context) {
    final colors = UiColors.of(context);
    final tonePair = colors.tone(topic.tone);

    return Semantics(
      button: true,
      label: '${topic.title}. ${topic.subtitle}',
      child: UiCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HowItWorksTourScreen(
                content: content,
                steps: topic.steps,
                title: topic.title,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tonePair.background,
                borderRadius: BorderRadius.circular(UiRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(topic.icon, size: 22, color: tonePair.foreground),
            ),
            const SizedBox(height: UiSpace.md),
            Text(
              topic.title,
              style: UiText.bodyStrong.copyWith(color: colors.ink),
            ),
            const SizedBox(height: UiSpace.xs),
            Text(
              topic.subtitle,
              style: UiText.caption.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final HowFact fact;

  @override
  Widget build(BuildContext context) {
    final colors = UiColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(UiSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.tint,
              borderRadius: BorderRadius.circular(UiRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(fact.icon, size: 22, color: colors.tintText),
          ),
          const SizedBox(width: UiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact.title,
                  style: UiText.bodyStrong.copyWith(color: colors.ink),
                ),
                const SizedBox(height: UiSpace.xs),
                Text(
                  fact.body,
                  style: UiText.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
