import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/pdf_credential_store.dart';

class PasswordProtectScreen extends StatefulWidget {
  const PasswordProtectScreen({super.key});

  @override
  State<PasswordProtectScreen> createState() => _PasswordProtectScreenState();
}

class _PasswordProtectScreenState extends State<PasswordProtectScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _isProcessing = false;
  int _progress = 0;
  int _total = 0;

  // ── Protect tab ──────────────────────────────────────────────────────────
  File? _protectFile;
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  // ── Unlock tab ───────────────────────────────────────────────────────────
  File? _unlockFile;
  final _unlockCtrl = TextEditingController();
  bool _obscureUnlock = true;
  bool _biometricAvailable = false;
  bool _hasStoredBiometric = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    final available = await PdfCredentialStore.instance.canUseBiometrics();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    _unlockCtrl.dispose();
    super.dispose();
  }

  // ── File picking ─────────────────────────────────────────────────────────

  Future<void> _pickProtectFile() async {
    final files =
        await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty) return;
    setState(() => _protectFile = files.first);
  }

  Future<void> _pickUnlockFile() async {
    final files =
        await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final hasStored =
        await PdfCredentialStore.instance.hasStoredPassword(file.path);
    setState(() {
      _unlockFile = file;
      _hasStoredBiometric = hasStored;
    });
    if (hasStored) {
      await _unlockWithBiometrics();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final file = _unlockFile;
    if (file == null || !_biometricAvailable) return;

    final password = await PdfCredentialStore.instance.unlockWithBiometrics(
      file.path,
      reason: 'Unlock ${fileName(file.path)}',
    );
    if (password == null || !mounted) return;

    _unlockCtrl.text = password;
    await _removePassword(
      passwordOverride: password,
      offerBiometricSave: false,
    );
  }

  Future<void> _offerBiometricSave(String pdfPath, String password) async {
    if (!_biometricAvailable) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save for biometric unlock?'),
        content: const Text(
          'Use fingerprint or face recognition to unlock this PDF next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      await PdfCredentialStore.instance.savePassword(pdfPath, password);
    }
  }

  // ── Encrypt ──────────────────────────────────────────────────────────────

  Future<void> _applyPassword() async {
    final file = _protectFile;
    final password = _pwCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (file == null) {
      _snack('Select a PDF first.');
      return;
    }
    if (password.isEmpty) {
      _snack('Enter a password.');
      return;
    }
    if (password != confirm) {
      _snack('Passwords do not match.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _total = 0;
    });

    try {
      final out = await PDFManager.encryptPDF(
        file,
        userPassword: password,
        onProgress: (c, t) {
          if (mounted) setState(() { _progress = c; _total = t; });
        },
      );
      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase().insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      if (mounted) {
        _snack('PDF protected: ${fileName(out.path)}');
        _pwCtrl.clear();
        _confirmCtrl.clear();
        setState(() => _protectFile = null);
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Encryption failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Decrypt ──────────────────────────────────────────────────────────────

  Future<void> _removePassword({
    String? passwordOverride,
    bool offerBiometricSave = true,
  }) async {
    final file = _unlockFile;
    final password = passwordOverride ?? _unlockCtrl.text.trim();

    if (file == null) {
      _snack('Select a password-protected PDF first.');
      return;
    }
    if (password.isEmpty) {
      _snack('Enter the current password.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _total = 0;
    });

    try {
      final out = await PDFManager.decryptPDF(
        file,
        password: password,
        onProgress: (c, t) {
          if (mounted) setState(() { _progress = c; _total = t; });
        },
      );
      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase().insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      if (mounted && offerBiometricSave) {
        await _offerBiometricSave(file.path, password);
      }
      if (mounted) {
        _snack('Password removed: ${fileName(out.path)}');
        _unlockCtrl.clear();
        setState(() {
          _unlockFile = null;
          _hasStoredBiometric = false;
        });
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Failed — check that the password is correct.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Protect'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.lock_outline), text: 'Protect'),
            Tab(icon: Icon(Icons.lock_open_outlined), text: 'Unlock'),
          ],
        ),
      ),
      body: _isProcessing
          ? _buildProgress(cs)
          : TabBarView(
              controller: _tabs,
              children: [
                _buildProtectTab(cs),
                _buildUnlockTab(cs),
              ],
            ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    final pct = _total > 0 ? _progress / _total : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _total > 0 ? pct : null),
            const SizedBox(height: 20),
            if (_total > 0)
              Text('Processing page $_progress of $_total…',
                  style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildProtectTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FileCard(
          file: _protectFile,
          hint: 'Tap to pick a PDF to protect',
          onPick: _pickProtectFile,
          cs: cs,
        ),
        const SizedBox(height: 16),
        _SectionLabel('Set password', cs),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _PwField(
                  controller: _pwCtrl,
                  label: 'Password',
                  obscure: _obscurePw,
                  onToggle: () => setState(() => _obscurePw = !_obscurePw),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _PwField(
                  controller: _confirmCtrl,
                  label: 'Confirm password',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  onChanged: (_) => setState(() {}),
                ),
                if (_pwCtrl.text.isNotEmpty &&
                    _confirmCtrl.text.isNotEmpty &&
                    _pwCtrl.text != _confirmCtrl.text)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text('Passwords do not match',
                            style:
                                TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed:
                (_protectFile != null && _pwCtrl.text.isNotEmpty && _confirmCtrl.text.isNotEmpty)
                    ? _applyPassword
                    : null,
            icon: const Icon(Icons.lock),
            label: const Text('Protect PDF', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Note: Encryption uses AES-256 and keeps the original pages '
          '(text stays selectable). You will need the password to open the file.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUnlockTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FileCard(
          file: _unlockFile,
          hint: 'Tap to pick a password-protected PDF',
          onPick: _pickUnlockFile,
          cs: cs,
        ),
        const SizedBox(height: 16),
        _SectionLabel('Enter current password', cs),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _PwField(
              controller: _unlockCtrl,
              label: 'Current password',
              obscure: _obscureUnlock,
              onToggle: () =>
                  setState(() => _obscureUnlock = !_obscureUnlock),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        if (_biometricAvailable && _unlockFile != null && _hasStoredBiometric) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _unlockWithBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with biometrics'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed:
                (_unlockFile != null && _unlockCtrl.text.isNotEmpty)
                    ? () => _removePassword()
                    : null,
            icon: const Icon(Icons.lock_open),
            label: const Text('Remove Password', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A new unlocked copy of the PDF will be saved to your documents.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final File? file;
  final String hint;
  final VoidCallback onPick;
  final ColorScheme cs;

  const _FileCard({
    required this.file,
    required this.hint,
    required this.onPick,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onPick,
        leading: Icon(Icons.picture_as_pdf, color: cs.error),
        title: Text(
          file != null ? fileName(file!.path) : hint,
          style: TextStyle(
            fontWeight:
                file != null ? FontWeight.w600 : FontWeight.normal,
            color: file != null ? null : cs.onSurfaceVariant,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: file != null
            ? Text(
                _fmtSize(file!.lengthSync()),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )
            : null,
        trailing:
            Icon(Icons.folder_open_outlined, color: cs.onSurfaceVariant),
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: cs.onSurfaceVariant),
      );
}

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  const _PwField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.password_outlined),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          isDense: true,
        ),
      );
}
