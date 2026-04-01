import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ambyoai_snackbar.dart';
import '../providers/language_provider.dart';

class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language_rounded),
      tooltip: 'Change Language',
      onPressed: () => _showLanguageSheet(context),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LanguageSheet(),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final language in AppLanguage.values)
            ListTile(
              leading: Text(
                _flag(language),
                style: const TextStyle(fontSize: 20),
              ),
              title: Text(_name(language)),
              subtitle: Text(_subname(language)),
              trailing: provider.current == language
                  ? const Icon(Icons.check_circle, color: Colors.teal)
                  : null,
              onTap: () async {
                await context.read<LanguageProvider>().setLanguage(language);
                if (context.mounted) {
                  Navigator.pop(context);
                  AmbyoSnackbar.show(context, message: 'Language changed to ${_name(language)}', type: SnackbarType.success);
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _flag(AppLanguage l) {
    switch (l) {
      case AppLanguage.english:
        return 'EN';
      case AppLanguage.malayalam:
        return 'ML';
      case AppLanguage.hindi:
        return 'HI';
      case AppLanguage.tamil:
        return 'TA';
    }
  }

  String _name(AppLanguage l) {
    switch (l) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.malayalam:
        return 'മലയാളം';
      case AppLanguage.hindi:
        return 'हिंदी';
      case AppLanguage.tamil:
        return 'தமிழ்';
    }
  }

  String _subname(AppLanguage l) {
    switch (l) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.malayalam:
        return 'Malayalam';
      case AppLanguage.hindi:
        return 'Hindi';
      case AppLanguage.tamil:
        return 'Tamil';
    }
  }
}
