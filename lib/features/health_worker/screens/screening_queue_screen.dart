import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/ambyo_theme.dart';
import '../../../core/theme/ambyoai_design_system.dart';
import '../../../core/widgets/ambyoai_empty_state.dart';
import '../../../core/widgets/ambyoai_list_item.dart';
import '../../../core/widgets/ambyoai_widgets.dart';
import '../../../core/widgets/enterprise_ui.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../consent/consent_flow.dart';
import '../../eye_tests/age_profile.dart';
import '../../eye_tests/test_flow_controller.dart';
import '../../offline/database_tables.dart';
import '../../offline/local_database.dart';

class ScreeningQueueScreen extends StatefulWidget {
  const ScreeningQueueScreen({super.key});

  @override
  State<ScreeningQueueScreen> createState() => _ScreeningQueueScreenState();
}

class _ScreeningQueueScreenState extends State<ScreeningQueueScreen> {
  Future<List<Patient>>? _loader;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<List<Patient>> _load() async {
    return LocalDatabase.instance.getUnscreenedPatientsToday();
  }

  Future<void> _start(Patient patient) async {
    if (!mounted) return;
    final begin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StartScreeningSheet(patient: patient),
    );
    if (!mounted || begin != true) return;
    final started = await ensureConsentThenStartScreening(
      context,
      patient,
      screener: 'Health Worker',
    );
    if (mounted && started) setState(() => _loader = _load());
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(
      child: EnterpriseScaffold(
        title: 'Screening Queue',
        subtitle: 'Children waiting today',
        appBarStyle: EnterpriseAppBarStyle.light,
        surfaceStyle: EnterpriseSurfaceStyle.plain,
        backgroundColor: AmbyoColors.darkBg,
        actions: const [],
        child: FutureBuilder<List<Patient>>(
          future: _loader,
          builder: (context, snapshot) {
            final rows = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                rows == null) {
              return const _QueueLoading();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EnterprisePanel(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AmbyoTheme.primaryColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.groups_rounded,
                                  color: AmbyoTheme.primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${rows.length} children waiting',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Not screened today (UTC)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AppRouter.addPatient)
                                  .then((_) {
                                setState(() => _loader = _load());
                              }),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  Expanded(
                    child: AmbyoEmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'Queue Empty',
                      subtitle:
                          'All registered children have been screened today.',
                      buttonLabel: 'Register New Child',
                      onButton: () => Navigator.of(context)
                          .pushNamed(AppRouter.addPatient)
                          .then((_) {
                        setState(() => _loader = _load());
                      }),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final p = rows[index];
                        final initials =
                            p.name.isNotEmpty ? p.name.substring(0, 1) : '?';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AmbyoListItem(
                            leading: ambyoAvatar(
                                initials: initials,
                                color: AmbyoColors.royalBlue),
                            title: p.name,
                            subtitle: 'Age: ${p.age}  ·  ${p.gender}',
                            trailing: SizedBox(
                              height: AmbyoSpacing.btnHeight,
                              child: FilledButton(
                                onPressed: () => _start(p),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AmbyoTheme.primaryColor,
                                ),
                                child: const Text('START'),
                              ),
                            ),
                            onTap: () => _start(p),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StartScreeningSheet extends StatefulWidget {
  const _StartScreeningSheet({required this.patient});

  final Patient patient;

  @override
  State<_StartScreeningSheet> createState() => _StartScreeningSheetState();
}

class _StartScreeningSheetState extends State<_StartScreeningSheet> {
  late AgeProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = TestFlowController.profileOverride ??
        AgeProfile.fromAge(widget.patient.age);
  }

  Future<void> _changeProfile() async {
    final selected = await showDialog<AgeProfile>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AmbyoColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Change Profile'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
        content: Text(
          'Override the age-based profile if this child is more or less developed than their age suggests.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, AgeProfile.a),
            child: const Text('A (3-4)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, AgeProfile.b),
            child: const Text('B (5-7)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, AgeProfile.c),
            child: const Text('C (8+)'),
          ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _profile = selected;
        TestFlowController.profileOverride = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start screening',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13213A),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.patient.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF66748B),
                  ),
            ),
            const SizedBox(height: 16),
            EnterprisePanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.child_care_rounded,
                      color: AmbyoTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Age profile',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile.label,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _changeProfile,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                    label: const Text('Change Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AmbyoTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Begin screening'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueLoading extends StatelessWidget {
  const _QueueLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AmbyoShimmer(height: 72),
      ),
    );
  }
}
