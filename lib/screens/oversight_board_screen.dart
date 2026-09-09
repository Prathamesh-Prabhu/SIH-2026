import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/ml_models.dart';
import '../services/auth_service.dart';
import '../services/ml_service.dart';

/// Ethics / Oversight Board console (PRD §8.3, architecture §4).
///
/// Styled from the "Serene Institutional Resilience" tokens — no invented
/// shades, no aggressive drop shadows, hairline structure over heavy borders.
///
/// Deliberately model-level only: the board reviews the *model*, never the
/// people. Nothing here is per-person — no names, no Service IDs, no pseudonym
/// tokens, no individual risk bands — so there is nothing that could
/// re-identify anyone.
class OversightBoardScreen extends StatefulWidget {
  const OversightBoardScreen({super.key});

  @override
  State<OversightBoardScreen> createState() => _OversightBoardScreenState();
}

class _OversightBoardScreenState extends State<OversightBoardScreen> {
  final _ml = MlService();

  @override
  void initState() {
    super.initState();
    _ml.addListener(_onMlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _ml.removeListener(_onMlChanged);
    super.dispose();
  }

  void _onMlChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _ml.checkHealth();
    await _ml.fetchModelCard();
  }

  @override
  Widget build(BuildContext context) {
    final card = _ml.modelCard;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model Oversight', style: AppText.headlineSm),
            Text('Ethics & Oversight Board Console',
                style: AppText.labelSm),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
            tooltip: 'Refresh model card',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/landing');
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            children: [
              _scopeNotice(),
              const SizedBox(height: AppSpacing.md),
              _serviceStatus(),
              const SizedBox(height: AppSpacing.md),
              if (card == null)
                _emptyState()
              else ...[
                _modelIdentity(card),
                const SizedBox(height: AppSpacing.md),
                _metrics(card),
                const SizedBox(height: AppSpacing.md),
                _features(card),
                const SizedBox(height: AppSpacing.md),
                _limitations(card),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Privacy & trust panel, per the design system's tinted-banner spec.
  Widget _scopeNotice() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.trustPanel,
        borderRadius: AppRadii.brLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined,
              size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Model-level review only. This console carries no personnel '
              'records, pseudonym tokens, or individual risk bands: the board '
              'governs the model, not the people it scores.',
              style: AppText.bodySm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatus() {
    final online = _ml.isOnline;
    return _card(
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? AppColors.statusPositive
                  : AppColors.statusCaution,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(_ml.statusMessage, style: AppText.labelMd),
          ),
          if (_ml.isChecking)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No active model card', style: AppText.headlineSm),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'The Analytics & ML microservice has not published a model card. '
            'Start the service and run the training pipeline, then refresh.',
            style: AppText.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _modelIdentity(ModelCard card) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(card.modelName, style: AppText.headlineSm),
              ),
              _pill(
                card.oversightBoardApproved
                    ? 'Board approved'
                    : 'Awaiting board sign-off',
                card.oversightBoardApproved
                    ? AppColors.statusPositive
                    : AppColors.statusCaution,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _kv('Version', '${card.version}${card.isActive ? '  •  active' : ''}'),
          _kv('Model type', card.modelType),
          _kv('Training window', card.trainingWindow),
          _kv('Training sample', '${card.sampleSize} pseudonymized records'),
          _kv('Last validated', card.lastValidatedDate),
        ],
      ),
    );
  }

  Widget _metrics(ModelCard card) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Validation metrics', style: AppText.headlineSm),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Tracked for false-positive / false-negative drift under the '
            'monthly clinical-review loop. Read these alongside the '
            'limitations below.',
            style: AppText.bodySm,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...card.metrics.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(e.key.replaceAll('_', ' '),
                        style: AppText.bodySm),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadii.brPill,
                      child: LinearProgressIndicator(
                        value: e.value.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(e.value.toStringAsFixed(3),
                      style: AppText.labelMd
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _features(ModelCard card) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Features the model is permitted to use',
              style: AppText.headlineSm),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Derived rolling-window features only: no raw HR records, no '
            'identities, no free-text journal content.',
            style: AppText.bodySm,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: card.featuresUtilized
                .map((f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs + 2),
                      decoration: const BoxDecoration(
                        color: AppColors.tertiaryFixed,
                        borderRadius: AppRadii.brPill,
                      ),
                      child: Text(
                        f,
                        style: AppText.labelSm
                            .copyWith(color: AppColors.primary),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _limitations(ModelCard card) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Known limitations', style: AppText.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          ...card.knownLimitations.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle,
                        size: 5, color: AppColors.statusCaution),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(l,
                        style: AppText.bodySm
                            .copyWith(color: AppColors.onSurface)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Elevated tile: white fill, hairline border, soft ambient diffusion —
  /// never a hard drop shadow (DESIGN.md → "Elevation & Depth").
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadii.brLg,
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: AppText.bodySm),
          ),
          Expanded(
            child: Text(v,
                style: AppText.labelMd
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: AppRadii.brPill,
      ),
      child: Text(label,
          style: AppText.labelSm.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}
