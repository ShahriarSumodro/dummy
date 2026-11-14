import 'package:flutter/material.dart';
import '../models/organization.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Screen to create or edit an Organization / Company.
class OrganizationFormScreen extends StatefulWidget {
  final Organization? organization;

  const OrganizationFormScreen({super.key, this.organization});

  @override
  State<OrganizationFormScreen> createState() => _OrganizationFormScreenState();
}

class _OrganizationFormScreenState extends State<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _industryController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  bool get _isEditing => widget.organization != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization?.name ?? '');
    _industryController = TextEditingController(text: widget.organization?.industry ?? '');
    _websiteController = TextEditingController(text: widget.organization?.website ?? '');
    _addressController = TextEditingController(text: widget.organization?.address ?? '');
    _notesController = TextEditingController(text: widget.organization?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.success();

    final org = Organization(
      id: widget.organization?.id,
      name: _nameController.text.trim(),
      industry: _industryController.text.trim().isEmpty ? null : _industryController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.organization?.createdAt,
    );

    Navigator.pop(context, org);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Company' : 'New Company', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: 'Save',
              size: AppButtonSize.sm,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Company / Organization Name *',
              hintText: 'e.g. Apex Corporation Ltd.',
              prefixIcon: Icons.business_rounded,
              autofocus: !_isEditing,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _industryController,
              label: 'Industry / Sector',
              hintText: 'e.g. Technology, FMCG, Banking',
              prefixIcon: Icons.category_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _websiteController,
              label: 'Website',
              hintText: 'https://example.com',
              prefixIcon: Icons.language_outlined,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _addressController,
              label: 'Office Address / City',
              hintText: 'e.g. Gulshan-2, Dhaka',
              prefixIcon: Icons.location_on_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _notesController,
              label: 'Company Background / Context',
              hintText: 'Important context about this business partner...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
