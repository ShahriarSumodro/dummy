import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Form screen for creating or editing a contact.
class ContactFormScreen extends StatefulWidget {
  /// Pass an existing contact to edit, or null to create a new one.
  final Contact? contact;

  const ContactFormScreen({super.key, this.contact});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _notesController;
  late int _cadenceDays;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
    _emailController = TextEditingController(text: widget.contact?.email ?? '');
    _companyController = TextEditingController(text: widget.contact?.company ?? '');
    _roleController = TextEditingController(text: widget.contact?.role ?? '');
    _notesController = TextEditingController(text: widget.contact?.notes ?? '');
    _cadenceDays = widget.contact?.cadenceDays ?? 30;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.success();

    final contact = Contact(
      id: widget.contact?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      role: _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      cadenceDays: _cadenceDays,
      createdAt: widget.contact?.createdAt,
    );

    Navigator.pop(context, contact);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contact' : 'New Contact', style: const TextStyle(fontWeight: FontWeight.w700)),
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
              label: 'Full Name *',
              hintText: 'e.g. Rahim Ahmed',
              prefixIcon: Icons.person_outline_rounded,
              autofocus: !_isEditing,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hintText: 'e.g. +880 1XX XXXXXXX',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'e.g. rahim@company.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _companyController,
              label: 'Company / Organization',
              hintText: 'e.g. ABC Corporation',
              prefixIcon: Icons.business_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _roleController,
              label: 'Role / Designation',
              hintText: 'e.g. Chief Marketing Officer',
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Cadence Selector
            Text(
              'TOUCHPOINT CADENCE (HEALTH RADAR)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How frequently you aim to reconnect with this person:',
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _buildCadenceChip(7, 'Weekly (7d)'),
                _buildCadenceChip(14, 'Bi-weekly (14d)'),
                _buildCadenceChip(30, 'Monthly (30d)'),
                _buildCadenceChip(60, '60 Days'),
                _buildCadenceChip(90, 'Quarterly (90d)'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _notesController,
              label: 'Background & Relationship Notes',
              hintText: 'Important preferences, mutual connections, or personal context...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCadenceChip(int days, String label) {
    final isSelected = _cadenceDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.foreground(context),
      ),
      onSelected: (_) {
        AppHaptics.lightImpact();
        setState(() => _cadenceDays = days);
      },
    );
  }
}
