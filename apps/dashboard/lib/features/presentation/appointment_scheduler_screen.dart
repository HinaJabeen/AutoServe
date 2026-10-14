// apps/dashboard/lib/features/presentation/appointment_scheduler_screen.dart
//
// Interactive calendar powered by table_calendar.
// Add to pubspec.yaml:  table_calendar: ^3.1.0
//
// Features:
// • Dates with leads show a colored dot indicator
// • Tapping a date filters the list below to that day's leads
// • Empty state shown when no leads exist for the selected day
// • Fully theme-reactive via context.palette

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/providers/overview_provider.dart';
import 'package:dashboard/theme/app_palette.dart';

// ── Local state: which day is currently selected ────────────────────────────

final _selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ── Screen ──────────────────────────────────────────────────────────────────

class AppointmentSchedulerScreen extends ConsumerWidget {
  const AppointmentSchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync  = ref.watch(dealerLeadsStreamProvider);
    final palette     = context.palette;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final selectedDay = ref.watch(_selectedDayProvider);
    final focusedDay  = ref.watch(_focusedDayProvider);

    return leadsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(palette.accent)),
      ),
      error: (e, _) => _ErrorState(message: e.toString(), palette: palette,
          onRetry: () => ref.invalidate(dealerLeadsStreamProvider)),
      data: (allLeads) {
        // Build a map: normalised date → list of leads on that day
        final eventMap = <DateTime, List<LeadModel>>{};
        for (final lead in allLeads) {
          final d = _day(lead.createdAt.toLocal());
          (eventMap[d] ??= []).add(lead);
        }

        // Leads for the selected day
        final dayLeads = eventMap[_day(selectedDay)] ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Calendar ─────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingL, AppDimensions.paddingL,
                  AppDimensions.paddingL, 0),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadowColor
                        .withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 20, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TableCalendar<LeadModel>(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, selectedDay),
                eventLoader: (d) => eventMap[_day(d)] ?? const [],
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: AppTextStyles.bodyBold.copyWith(
                    color: palette.textPrimary, fontSize: 14),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded,
                      color: palette.textSecondary),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded,
                      color: palette.textSecondary),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                calendarStyle: CalendarStyle(
                  // Today
                  todayDecoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: AppTextStyles.body.copyWith(
                      color: palette.accent, fontWeight: FontWeight.w600),
                  // Selected
                  selectedDecoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  // Default days
                  defaultTextStyle: AppTextStyles.body.copyWith(
                      color: palette.textPrimary, fontSize: 13),
                  weekendTextStyle: AppTextStyles.body.copyWith(
                      color: palette.textSecondary, fontSize: 13),
                  outsideDaysVisible: false,
                  // Dot markers for days with events
                  markerDecoration: BoxDecoration(
                    color: palette.accent, shape: BoxShape.circle),
                  markerSize: 5,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                  cellMargin: const EdgeInsets.all(4),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.caption.copyWith(
                      color: palette.textTertiary,
                      fontSize: 11, fontWeight: FontWeight.w600),
                  weekendStyle: AppTextStyles.caption.copyWith(
                      color: palette.textTertiary,
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onDaySelected: (selected, focused) {
                  ref.read(_selectedDayProvider.notifier).state =
                      _day(selected);
                  ref.read(_focusedDayProvider.notifier).state = focused;
                },
                onPageChanged: (focused) {
                  ref.read(_focusedDayProvider.notifier).state = focused;
                },
              ),
            ),

            // ── Day header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingL, AppDimensions.paddingL,
                  AppDimensions.paddingL, AppDimensions.paddingS),
              child: Row(
                children: [
                  Text(
                    _formatHeader(selectedDay),
                    style: AppTextStyles.bodyBold.copyWith(
                        color: palette.textPrimary, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  if (dayLeads.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Text(
                        '${dayLeads.length}',
                        style: AppTextStyles.caption.copyWith(
                            color: palette.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),

            // ── Lead list for selected day ────────────────────────────────
            Expanded(
              child: dayLeads.isEmpty
                  ? _DayEmptyState(
                      date: selectedDay,
                      hasAnyLeads: allLeads.isNotEmpty,
                      palette: palette,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppDimensions.paddingL, 0,
                          AppDimensions.paddingL, AppDimensions.paddingL),
                      itemCount: dayLeads.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.paddingS),
                      itemBuilder: (context, i) =>
                          _LeadCard(lead: dayLeads[i], palette: palette,
                              isDark: isDark),
                    ),
            ),
          ],
        );
      },
    );
  }

  // Normalise to midnight so date comparisons work correctly
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatHeader(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(d.year, d.month, d.day);
    if (sel == today) return 'Today';
    if (sel == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (sel == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }
}

// ── Lead card ────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.palette,
    required this.isDark,
  });
  final LeadModel lead;
  final AppPalette palette;
  final bool isDark;

  Color _badgeColor(String status) {
    switch (status) {
      case 'new':         return palette.accent;
      case 'contacted':   return palette.statusReserved;
      case 'closed_won':  return palette.statusAvailable;
      case 'closed_lost': return palette.textTertiary;
      default:            return palette.textTertiary;
    }
  }

  String _label(String status) {
    const m = {
      'new':                  'New',
      'contacted':            'Contacted',
      'test_drive_scheduled': 'Test Drive',
      'negotiating':          'Negotiating',
      'closed_won':           'Won',
      'closed_lost':          'Lost',
    };
    return m[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(lead.status);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                lead.consumerName.isNotEmpty
                    ? lead.consumerName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.bodyBold
                    .copyWith(color: palette.accent, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),

          // Name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.consumerName,
                    style: AppTextStyles.bodyBold.copyWith(
                        color: palette.textPrimary, fontSize: 13.5)),
                if (lead.consumerPhone != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.phone_outlined,
                        size: 12, color: palette.textTertiary),
                    const SizedBox(width: 4),
                    Text(lead.consumerPhone!,
                        style: AppTextStyles.caption.copyWith(
                            color: palette.textSecondary, fontSize: 11)),
                  ]),
                ],
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(color: badgeColor.withValues(alpha: 0.40)),
            ),
            child: Text(_label(lead.status),
                style: AppTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state for a day with no leads ─────────────────────────────────────

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState({
    required this.date,
    required this.hasAnyLeads,
    required this.palette,
  });
  final DateTime date;
  final bool hasAnyLeads;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(date, DateTime.now());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isToday
                  ? Icons.event_available_outlined
                  : Icons.event_busy_outlined,
              size: 44,
              color: palette.textTertiary,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              isToday ? 'No leads today' : 'No leads on this day',
              style: AppTextStyles.bodyBold
                  .copyWith(color: palette.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyLeads
                  ? 'Tap a highlighted date to see leads for that day.'
                  : 'New leads will appear here once customers make inquiries.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.palette,
    required this.onRetry,
  });
  final String message;
  final AppPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 32, color: palette.error),
            const SizedBox(height: AppDimensions.paddingM),
            Text('Could not load schedule',
                style: AppTextStyles.bodyBold
                    .copyWith(color: palette.textPrimary)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: palette.textSecondary)),
            const SizedBox(height: AppDimensions.paddingM),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded,
                  size: 16, color: palette.accent),
              label: Text('Retry',
                  style: AppTextStyles.body
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
      ),
    );
  }
}