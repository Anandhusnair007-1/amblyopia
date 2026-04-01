import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/sync/report_syncer.dart';

class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  bool _syncing = false;
  DateTime? _lastSyncUtc;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_sync_timestamp');
    if (raw == null) return;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return;
    if (!mounted) return;
    setState(() => _lastSyncUtc = parsed.toUtc());
  }

  String _label() {
    if (_syncing) return 'Syncing...';
    final t = _lastSyncUtc;
    if (t == null) return 'Not synced yet';
    final delta = DateTime.now().toUtc().difference(t);
    if (delta.inMinutes < 2) return 'Synced just now';
    if (delta.inMinutes < 60) return 'Last synced: ${delta.inMinutes} min ago';
    if (delta.inHours < 24) return 'Last synced: ${delta.inHours} hours ago';
    return 'Last synced: ${delta.inDays} days ago';
  }

  IconData _icon() {
    if (_syncing) return Icons.hourglass_empty;
    final t = _lastSyncUtc;
    if (t == null) return Icons.sync;
    final delta = DateTime.now().toUtc().difference(t);
    if (delta.inMinutes < 2) return Icons.check_circle_outline;
    return Icons.sync;
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await syncNow();
      await _load();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _syncNow,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(), size: 18, color: const Color(0xFF66748B)),
            const SizedBox(width: 6),
            Text(
              _label(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF66748B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

