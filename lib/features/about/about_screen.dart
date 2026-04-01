import 'package:flutter/material.dart';

import '../../core/theme/ambyoai_design_system.dart';
import '../../core/widgets/ambyoai_widgets.dart';
import '../../core/widgets/enterprise_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: 'About AmbyoAI',
      subtitle: 'Clinical pilot build',
      appBarStyle: EnterpriseAppBarStyle.light,
      surfaceStyle: EnterpriseSurfaceStyle.gradient,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AmbyoSpacing.pagePadding, vertical: AmbyoSpacing.pageTop),
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.medical_services_outlined, size: 56, color: AmbyoColors.royalBlue.withValues(alpha: 0.8)),
                const SizedBox(height: AmbyoSpacing.inlineGap),
                Text('AmbyoAI', style: AmbyoTextStyles.subtitle().copyWith(fontSize: 22)),
                Text('v1.0.0', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          const AmbyoSectionHeader(title: 'Research Credits'),
          AmbyoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-powered Amblyopia Screening Using Smartphone Camera',
                  style: AmbyoTextStyles.body().copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AmbyoSpacing.itemGap),
                Text('Aditya Anil Deyal, Anandhu S. Nair, Vasudev PC', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          const AmbyoSectionHeader(title: 'Guidance'),
          AmbyoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. Prema Nedungadi, Dr. Subbulakshmi S', style: AmbyoTextStyles.body()),
                Text('Amrita School of Computing', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          const AmbyoSectionHeader(title: 'Clinical Partners'),
          AmbyoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clinical Ophthalmology Team', style: AmbyoTextStyles.body()),
                Text('Aravind Eye Hospital, Coimbatore', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          const AmbyoSectionHeader(title: 'Technology'),
          AmbyoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flutter · TFLite · ML Kit', style: AmbyoTextStyles.body()),
                Text('Vosk · SQLCipher · FastAPI', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          const AmbyoSectionHeader(title: 'Legal'),
          AmbyoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AmbyoAI is a screening aid only. It does not replace clinical examination by an eye doctor. Always consult a qualified ophthalmologist for diagnosis.',
                  style: AmbyoTextStyles.body(color: AmbyoColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.sectionGap),
          Center(
            child: Column(
              children: [
                Text('AmbyoAI v1.0.0', style: AmbyoTextStyles.caption()),
                Text('© 2026 Amrita School of Computing', style: AmbyoTextStyles.caption()),
                Text('Apache 2.0 · AmbyoAI', style: AmbyoTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(height: AmbyoSpacing.pageBottom),
        ],
      ),
    );
  }
}
