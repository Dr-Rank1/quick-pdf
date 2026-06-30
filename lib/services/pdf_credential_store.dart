import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores per-document PDF passwords in the platform secure store and
/// retrieves them after biometric authentication.
class PdfCredentialStore {
  PdfCredentialStore._();
  static final PdfCredentialStore instance = PdfCredentialStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static final LocalAuthentication _auth = LocalAuthentication();

  String _storageKey(String pdfPath) =>
      'pdf_pw_${sha256.convert(utf8.encode(pdfPath)).toString()}';

  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStoredPassword(String pdfPath) async {
    try {
      return await _storage.containsKey(key: _storageKey(pdfPath));
    } catch (_) {
      return false;
    }
  }

  Future<void> savePassword(String pdfPath, String password) async {
    await _storage.write(key: _storageKey(pdfPath), value: password);
  }

  Future<void> deletePassword(String pdfPath) async {
    await _storage.delete(key: _storageKey(pdfPath));
  }

  /// Returns the stored password after a successful biometric prompt, or null.
  Future<String?> unlockWithBiometrics(
    String pdfPath, {
    String reason = 'Unlock this protected PDF',
  }) async {
    if (!await hasStoredPassword(pdfPath)) return null;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
      if (!authenticated) return null;
      return await _storage.read(key: _storageKey(pdfPath));
    } catch (_) {
      return null;
    }
  }
}
