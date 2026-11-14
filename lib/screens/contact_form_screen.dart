import 'package:flutter/material.dart';
import '../models/contact.dart';

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
    _companyController =
        TextEditingController(text: widget.contact?.company ?? '');
    _roleController = TextEditingController(text: widget.contact?.role ?? '');
    _notesController =
        TextEditingController(text: widget.contact?.notes ?? '');
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

    final contact = Contact(
      id: widget.contact?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      company: _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      role: _roleController.text.trim().isEmpty
          ? null
          : _roleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      cadenceDays: _cadenceDays,
      createdAt: widget.contact?.createdAt,
    );

    Navigator.pop(context, contact);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contact' : 'New Contact'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
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
                labelText: 'Name *',
                hintText: 'e.g. Rahim Ahmed',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'e.g. +880 1XX XXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'e.g. rahim@company.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company / Organization',
                hintText: 'e.g. ABC Corporation',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role / Title',
                hintText: 'e.g. Marketing Director',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_cadenceDays),
              initialValue: _cadenceDays,
              decoration: const InputDecoration(
                labelText: 'Touchpoint Cadence (Health Radar)',
                helperText: 'How often you want to reconnect with this person',
                prefixIcon: Icon(Icons.sync_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('Weekly (Every 7 days)')),
                DropdownMenuItem(value: 14, child: Text('Bi-weekly (Every 14 days)')),
                DropdownMenuItem(value: 30, child: Text('Monthly (Every 30 days - Default)')),
                DropdownMenuItem(value: 60, child: Text('Bi-monthly (Every 60 days)')),
                DropdownMenuItem(value: 90, child: Text('Quarterly (Every 90 days)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _cadenceDays = val);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any important details about this person...',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
