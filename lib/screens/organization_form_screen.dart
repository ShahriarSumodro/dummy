import 'package:flutter/material.dart';
import '../models/organization.dart';

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
    _nameController =
        TextEditingController(text: widget.organization?.name ?? '');
    _industryController =
        TextEditingController(text: widget.organization?.industry ?? '');
    _websiteController =
        TextEditingController(text: widget.organization?.website ?? '');
    _addressController =
        TextEditingController(text: widget.organization?.address ?? '');
    _notesController =
        TextEditingController(text: widget.organization?.notes ?? '');
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

    final org = Organization(
      id: widget.organization?.id,
      name: _nameController.text.trim(),
      industry: _industryController.text.trim().isEmpty
          ? null
          : _industryController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.organization?.createdAt,
    );

    Navigator.pop(context, org);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Company' : 'New Company'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Company / Organization Name *',
                hintText: 'e.g. Apex Corporation Ltd.',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Company name is required'
                  : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _industryController,
              decoration: const InputDecoration(
                labelText: 'Industry / Sector',
                hintText: 'e.g. Technology, FMCG, Banking',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.language_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Office Address / City',
                hintText: 'e.g. Gulshan-2, Dhaka',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Company Background / Notes',
                hintText: 'Important context about this business partner...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
