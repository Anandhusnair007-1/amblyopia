import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    if (sync.pendingCount == 0) {
      return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
    }
    return Stack(
      children: [
        const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 20),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${sync.pendingCount}',
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ),
        ),
      ],
    );
  }
}
