import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/layout.dart';
import '../models/attendance_breakdown.dart';
import '../models/report_period.dart';
import '../models/special_day.dart';
import '../providers/explain_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../themes/bird_art.dart';
import '../widgets/charts.dart';
import '../widgets/desktop_page.dart';
import '../widgets/garden_header.dart';
import '../widgets/garden_tag.dart';
import '../widgets/no_office_placeholder.dart';
import '../widgets/responsive_body.dart';
import '../widgets/rto_arc_card.dart';

/// The Insights tab: explains how the "Return to office" percentage is
/// calculated for a chosen month or financial year — every contributing count
/// plus the arithmetic that turns them into the final percentage.
class ExplainScreen extends ConsumerStatefulWidget {
  const ExplainScreen({super.key});

  @override
  ConsumerState<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends ConsumerState<ExplainScreen> {
  PeriodKind _kind = PeriodKind.month;
  // Any day inside the selected window; the ReportPeriod normalises it.
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final office = ref.watch(officeProvider).selectedOffice;
    if (office == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const NoOfficePlaceholder(),
      );
    }

    final settings = ref.watch(settingsProvider);
    final fyStart = settings.financialYearStart;
    final target = settings.rtoTarget;
    final bird = birdAssetForTheme(settings.themeId);

    // One active reporting context at a time keeps the headline, calculation
    // and charts aligned. The window is always the whole period — weekdays
    // still to come included — so the percentage is the share of the month (or
    // year) you have attended, the same figure the home dashboard shows. An
    // elapsed-days-only denominator would read 100% on the first working day
    // of the month, which says nothing about meeting the target.
    final period = ReportPeriod(
      kind: _kind,
      anchor: _anchor,
      financialYearStart: fyStart,
    );
    final breakdown = ref.watch(
      breakdownProvider((
        officeId: office.id!,
        start: period.start,
        end: period.end,
      )),
    );

    // Desktop: gauges side by side under a page header, no app bar.
    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(
          title: 'Insights',
          subtitle: office.name,
          maxContentWidth: 1100,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _sectionTitle(context, 'Reporting period'),
              const SizedBox(height: 12),
              _periodKindSelector(),
              const SizedBox(height: 12),
              _periodNavigator(period),
              const SizedBox(height: 16),
              _arcCard(breakdown, period.label, target, bird),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Breakdown'),
              const SizedBox(height: 12),
              breakdown.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Could not load data: $e')),
                ),
                data: (b) => _details(b, target, office.id!, wide: true),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const GardenHeader(
              eyebrow: 'The bigger picture',
              title: 'See your rhythm.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GardenTag(office.name),
            ),
            const SizedBox(height: 16),
            _periodKindSelector(),
            const SizedBox(height: 8),
            _periodNavigator(period),
            const SizedBox(height: 8),
            breakdown.when(
              loading: () => const Card(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load ${period.label}: $e'),
                ),
              ),
              data: (b) => _RateCard(breakdown: b, target: target),
            ),
            const SizedBox(height: 16),
            breakdown.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (b) => _details(b, target, office.id!),
            ),
          ],
        ),
      ),
    );
  }

  /// A return-to-office gauge card wrapped in its async states.
  Widget _arcCard(
    AsyncValue<AttendanceBreakdown> bd,
    String label,
    int target,
    String? bird,
  ) {
    return bd.when(
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Could not load $label: $e')),
        ),
      ),
      data: (b) => RtoArcCard(
        breakdown: b,
        target: target,
        periodLabel: label,
        birdAsset: bird,
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _periodKindSelector() {
    return SegmentedButton<PeriodKind>(
      segments: const [
        ButtonSegment(value: PeriodKind.month, label: Text('Month')),
        ButtonSegment(value: PeriodKind.year, label: Text('Year')),
      ],
      selected: {_kind},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _kind = s.first),
    );
  }

  Widget _periodNavigator(ReportPeriod period) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
          onPressed: () => setState(() => _anchor = period.previous.anchor),
        ),
        Expanded(
          child: Text(
            period.label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
          // Don't let the user page into the future.
          onPressed: period.isCurrent
              ? null
              : () => setState(() => _anchor = period.next.anchor),
        ),
      ],
    );
  }

  // ── Detailed breakdown (for the selected period) ───────────────────────────

  Widget _details(
    AttendanceBreakdown b,
    int target,
    int officeId, {
    bool wide = false,
  }) {
    // Desktop: two columns so the breakdown fills the width instead of a long
    // single column. Donut + calculation on the left, trend + counts on the
    // right.
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BreakdownDonut(breakdown: b),
                const SizedBox(height: 16),
                _CalculationCard(breakdown: b),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrendCard(officeId: officeId, target: target),
                const SizedBox(height: 16),
                _CountsCard(breakdown: b),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrendCard(officeId: officeId, target: target),
        const SizedBox(height: 16),
        _CalculationCard(breakdown: b),
        const SizedBox(height: 16),
        _CountsCard(breakdown: b),
        const SizedBox(height: 16),
        BreakdownDonut(breakdown: b),
      ],
    );
  }
}

// ── Rate card (mobile) ───────────────────────────────────────────────────────

/// The period's headline: the percentage, whether it clears the target, a
/// progress bar and the plain-language sum behind it.
class _RateCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  final int target;
  const _RateCard({required this.breakdown, required this.target});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final b = breakdown;
    final pct = b.returnToOfficePercentage;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  pct == null ? '—' : '${pct.round()}%',
                  style: text.displaySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (pct != null)
                  GardenTag(
                    pct >= target
                        ? 'Above $target% target'
                        : 'Below $target% target',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: pct == null
                  ? 'No return to office percentage available'
                  : 'Return to office ${pct.toStringAsFixed(1)} percent, '
                        'target $target percent',
              child: LinearProgressIndicator(
                value: ((pct ?? 0) / 100).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_dayCount(b.officeDays, 'office day')} / '
              '${_dayCount(b.eligibleWorkingDays, 'eligible working day')}',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calculation card ─────────────────────────────────────────────────────────

class _CalculationCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const _CalculationCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final b = breakdown;
    final pct = b.returnToOfficePercentage;
    final tint = cs.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, 'How your percentage is calculated'),
            const SizedBox(height: 4),
            _ListRow(
              leading: GardenIconTile(
                color: tint,
                icon: Icons.calendar_view_week_outlined,
              ),
              label: 'Weekdays in period',
              value: '${b.weekdays}',
            ),
            _ListRow(
              leading: GardenIconTile(color: tint, icon: Icons.remove),
              label: 'Excluded leave & holidays',
              value: '${b.excludedDays}',
            ),
            _ListRow(
              leading: GardenIconTile(color: tint, icon: Icons.drag_handle),
              label: 'Eligible working days',
              value: '${b.eligibleWorkingDays}',
              last: true,
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pct == null
                        ? '${b.officeDays} office days ÷ 0'
                        : '${_dayCount(b.officeDays, 'office day')} '
                              '÷ ${b.eligibleWorkingDays} × 100',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  pct == null ? '—' : '${pct.toStringAsFixed(1)}%',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Public holidays and sick, annual, carer\u2019s and misc leave are '
              'removed from the working-day total. Work-from-home days stay '
              'in it, so they lower the percentage.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list row in the garden style: icon tile, label (with an optional
/// caption beneath), and a right-aligned value, divided by hairlines.
class _ListRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final String? caption;
  final String value;
  final bool dim;
  final bool last;

  const _ListRow({
    required this.leading,
    required this.label,
    required this.value,
    this.caption,
    this.dim = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Opacity(
        opacity: dim ? 0.6 : 1,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.bodyLarge),
                  if (caption != null)
                    Text(
                      caption!,
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Counts card ──────────────────────────────────────────────────────────────

class _CountsCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const _CountsCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final office = DayTypeColors.of(context).attendance;
    // Special-day types in a stable, readable order; unused ones are hidden.
    final types = [
      for (final type in const [
        DayType.workFromHome,
        DayType.annualLeave,
        DayType.sickLeave,
        DayType.carersLeave,
        DayType.miscLeave,
        DayType.holiday,
      ])
        if (b.countOf(type) > 0) type,
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, 'Recorded days'),
            const SizedBox(height: 4),
            _ListRow(
              leading: GardenIconTile(
                color: office,
                icon: DayStatus.attended.icon,
              ),
              label: 'Office',
              caption: 'Counts toward %',
              value: '${b.officeDays}',
              last: types.isEmpty && b.weekendOfficeDays == 0,
            ),
            // Weekend check-ins are real attendance but sit outside the
            // weekday-based percentage — surfaced so the numbers add up.
            if (b.weekendOfficeDays > 0)
              _ListRow(
                leading: GardenIconTile(
                  color: office,
                  icon: DayStatus.attended.icon,
                ),
                label: 'Office (weekend)',
                caption: 'Not counted',
                value: '${b.weekendOfficeDays}',
                dim: true,
                last: types.isEmpty,
              ),
            for (final type in types)
              _ListRow(
                leading: GardenIconTile(
                  color: type.colorIn(context),
                  icon: type.icon,
                ),
                label: type.label,
                caption: excludedFromAttendanceDenominator.contains(type)
                    ? 'Excluded from %'
                    : 'Lowers %',
                value: '${b.countOf(type)}',
                last: type == types.last,
              ),
          ],
        ),
      ),
    );
  }
}

/// "1 non-working day" / "3 non-working days" — pluralises [unit] by [n].
String _dayCount(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

Widget _sectionTitle(BuildContext context, String text) =>
    Text(text, style: Theme.of(context).textTheme.titleMedium);
