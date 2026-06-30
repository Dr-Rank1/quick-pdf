import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/providers/theme_provider.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/premium_service.dart';

// ── Shared prefs keys (see lib/constants/preference_keys.dart) ───────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _storageUsed = '…';
  String _cacheUsed = '…';
  bool _clearingCache = false;
  String _appVersion = '…';

  // User preferences
  int _defaultQuality = 75;
  String _ocrLanguage = 'en';
  bool _adsEnabled = true;
  bool _premiumUnlocked = false;
  bool _purchasePending = false;
  String? _premiumPrice;

  static const List<Map<String, String>> _ocrLanguages = [
    {'label': 'English', 'code': 'en'},
    {'label': 'French', 'code': 'fr'},
    {'label': 'Spanish', 'code': 'es'},
    {'label': 'German', 'code': 'de'},
    {'label': 'Arabic', 'code': 'ar'},
    {'label': 'Swahili', 'code': 'sw'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _calcStorage();
    _loadVersion();
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    final premium = PremiumService.instance;
    if (mounted) {
      setState(() {
        _premiumUnlocked = AdService.premiumUnlocked;
        _premiumPrice = premium.formattedPrice;
        _purchasePending = premium.isPurchasePending;
      });
    }
  }

  Future<void> _purchaseRemoveAds() async {
    setState(() => _purchasePending = true);
    final started = await PremiumService.instance.purchaseRemoveAds();
    if (!started && mounted) {
      setState(() => _purchasePending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not start purchase. Try again later.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _premiumUnlocked = AdService.premiumUnlocked;
        _purchasePending = PremiumService.instance.isPurchasePending;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _purchasePending = true);
    await PremiumService.instance.restorePurchases();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _premiumUnlocked = AdService.premiumUnlocked;
        _purchasePending = PremiumService.instance.isPurchasePending;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_premiumUnlocked
            ? 'Premium restored — ads removed'
            : 'No previous purchase found'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _defaultQuality = prefs.getInt(kPrefImageQuality) ?? 75;
        _ocrLanguage = prefs.getString(kPrefOcrLanguage) ?? 'en';
        _adsEnabled = prefs.getBool(kPrefAdsEnabled) ?? true;
        _premiumUnlocked = prefs.getBool(kPrefPremiumUnlocked) ?? false;
      });
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion =
            '${info.version} (build ${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.1');
    }
  }

  Future<void> _calcStorage() async {
    try {
      int docTotal = 0;
      final docDir = await getApplicationDocumentsDirectory();
      await for (final e
          in docDir.list(recursive: true, followLinks: false)) {
        if (e is File) docTotal += await e.length();
      }

      int cacheTotal = 0;
      try {
        final cacheDir = await getApplicationCacheDirectory();
        await for (final e
            in cacheDir.list(recursive: true, followLinks: false)) {
          if (e is File) cacheTotal += await e.length();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _storageUsed = _fmt(docTotal);
          _cacheUsed = _fmt(cacheTotal);
        });
      }
    } catch (_) {
      if (mounted) setState(() { _storageUsed = 'Unknown'; _cacheUsed = '0 B'; });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      int freed = 0;
      int count = 0;

      // Clear thumbnails from cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        final thumbDir = Directory('${cacheDir.path}/thumbnails');
        if (await thumbDir.exists()) {
          await for (final e
              in thumbDir.list(recursive: true, followLinks: false)) {
            if (e is File) {
              freed += await e.length();
              await e.delete();
              count++;
            }
          }
        }
        // Clear other temp files in cache root
        await for (final e
            in cacheDir.list(recursive: false, followLinks: false)) {
          if (e is File) {
            final n = fileName(e.path).toLowerCase();
            if (n.endsWith('.tmp') || n.endsWith('.cache')) {
              freed += await e.length();
              await e.delete();
              count++;
            }
          }
        }
      } catch (_) {}

      // Clear orphaned thumb refs in documents dir
      final docDir = await getApplicationDocumentsDirectory();
      await for (final e
          in docDir.list(recursive: false, followLinks: false)) {
        if (e is File) {
          final n = fileName(e.path).toLowerCase();
          if (n.startsWith('thumb_') || n.endsWith('.tmp')) {
            freed += await e.length();
            await e.delete();
            count++;
          }
        }
      }

      await DocumentDatabase().clearThumbnailPaths();
      await _calcStorage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(count > 0
              ? 'Cleared $count files (${_fmt(freed)} freed)'
              : 'Nothing to clear'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System (Default)';
    }
  }

  Future<void> _showThemeModeDialog(BuildContext context) async {
    final ThemeMode currentMode = ref.read(themeProvider);
    final ThemeMode? newMode = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Select Theme Mode'),
          content: RadioGroup<ThemeMode>(
            groupValue: currentMode,
            onChanged: (ThemeMode? value) => Navigator.of(ctx).pop(value),
            child: const SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  ListTile(
                    leading: Radio<ThemeMode>(value: ThemeMode.light),
                    title: Text('Light'),
                  ),
                  ListTile(
                    leading: Radio<ThemeMode>(value: ThemeMode.dark),
                    title: Text('Dark'),
                  ),
                  ListTile(
                    leading: Radio<ThemeMode>(value: ThemeMode.system),
                    title: Text('System (Default)'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (newMode != null && newMode != currentMode) {
      ref.read(themeProvider.notifier).setThemeMode(newMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance ──
          _CardSection(title: 'Appearance', children: [
            ListTile(
              title: const Text('Theme Mode'),
              subtitle: Text(_getThemeModeName(ref.watch(themeProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeDialog(context),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Processing defaults ──
          _CardSection(title: 'Processing defaults', children: [
            ListTile(
              title: const Text('Default image quality'),
              subtitle: Text('$_defaultQuality%  (used by compress & convert)'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Slider(
                value: _defaultQuality.toDouble(),
                min: 50,
                max: 100,
                divisions: 10,
                label: '$_defaultQuality%',
                onChanged: (v) async {
                  final q = v.round();
                  setState(() => _defaultQuality = q);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(kPrefImageQuality, q);
                },
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              title: const Text('OCR language'),
              subtitle: Text(_ocrLanguages
                  .firstWhere((l) => l['code'] == _ocrLanguage,
                      orElse: () => {'label': 'English', 'code': 'en'})['label']!),
              trailing: DropdownButton<String>(
                value: _ocrLanguage,
                underline: const SizedBox.shrink(),
                items: _ocrLanguages
                    .map((l) => DropdownMenuItem(
                          value: l['code'],
                          child: Text(l['label']!),
                        ))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _ocrLanguage = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(kPrefOcrLanguage, v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Storage ──
          _CardSection(title: 'Storage', children: [
            ListTile(
              leading: Icon(Icons.folder_outlined, color: cs.primary),
              title: const Text('Documents'),
              subtitle: Text(_storageUsed),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.cached, color: cs.primary),
              title: const Text('Cache (thumbnails & temp files)'),
              subtitle: Text(_cacheUsed),
              trailing: _clearingCache
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: _clearCache,
                      child: const Text('Clear'),
                    ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Premium ──
          _CardSection(title: 'Premium', children: [
            if (_premiumUnlocked)
              ListTile(
                leading: Icon(Icons.verified, color: cs.primary),
                title: const Text('Ads removed'),
                subtitle: const Text('Thank you for supporting QuickPDF'),
              )
            else ...[
              ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: cs.secondary),
                title: const Text('Remove Ads'),
                subtitle: Text(
                  _premiumPrice != null
                      ? 'One-time purchase · $_premiumPrice'
                      : 'One-time purchase · unlock ad-free experience',
                ),
                trailing: _purchasePending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _purchaseRemoveAds,
                        child: const Text('Buy'),
                      ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.restore, color: cs.primary),
                title: const Text('Restore purchase'),
                onTap: _purchasePending ? null : _restorePurchases,
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // ── Ads ──
          _CardSection(title: 'Ads', children: [
            if (_premiumUnlocked)
              const ListTile(
                title: Text('Show ads'),
                subtitle: Text('Disabled while premium is active'),
                trailing: Switch(value: false, onChanged: null),
              )
            else
              SwitchListTile(
                title: const Text('Show ads'),
                subtitle: const Text('Disabling hides ads for testing'),
                value: _adsEnabled,
                onChanged: (v) async {
                  setState(() => _adsEnabled = v);
                  AdService.adsEnabled = v;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(kPrefAdsEnabled, v);
                },
              ),
          ]),
          const SizedBox(height: 12),

          // ── Privacy ──
          _CardSection(title: 'Privacy', children: [
            ListTile(
              leading: Icon(Icons.shield_outlined, color: cs.primary),
              title: const Text('Privacy First'),
              subtitle: const Text(
                  'All document processing is on-device. Ads are served by Google AdMob.'),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.policy_outlined, color: cs.primary),
              title: const Text('Privacy Policy'),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => _showPrivacyPolicy(context),
            ),
          ]),
          const SizedBox(height: 12),

          // ── About ──
          _CardSection(title: 'About', children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: cs.primary),
              title: const Text('QuickPDF'),
              subtitle: Text('Version $_appVersion · Built with Flutter'),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.balance_outlined, color: cs.primary),
              title: const Text('Open-source licences'),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'QuickPDF',
                applicationVersion: _appVersion,
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MarkdownBody(data: _kPrivacyPolicy),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static const String _kPrivacyPolicy = '''
## QuickPDF Privacy Policy

**Effective date: May 2026 · Version 1.0.1**

QuickPDF ("the app") is an offline document management tool developed for Android.
This policy explains what data the app accesses, how it is used, and your rights.

---

### 1. Data We Collect

QuickPDF itself collects **no personal data**. The app has no accounts, no servers,
and performs no uploads of your files or documents.

The app displays ads via **Google AdMob**, which may collect:
- Device Advertising ID
- IP address / approximate location
- App interaction data (for ad relevance)

---

### 2. Permissions Used

| Permission | Why it is needed |
|---|---|
| **Camera** | Capture photos for document scanning |
| **Storage (read)** | Open PDF and image files you select |
| **Storage (write)** | Save processed PDFs to your device |
| **Internet** | Required by Google AdMob to serve ads |
| **Advertising ID** | Used by AdMob for personalised ads |

---

### 3. Files & Documents

- Files you open or create are stored **only on your device**.
- QuickPDF never uploads, syncs, or transmits any file content.
- Temporary files are stored in the app's private directory and cleaned up automatically.

---

### 4. OCR & Text Recognition

Text recognition is performed **fully offline** using Google ML Kit's on-device models.
Recognised text never leaves your device.

---

### 5. Advertising (Google AdMob)

QuickPDF uses **Google AdMob** to display banner and interstitial ads.

**Your choices:**
- To opt out of personalised ads: **Android Settings → Google → Ads → Opt out**
- To reset your Advertising ID: **Android Settings → Google → Ads → Reset ID**

Google's Privacy Policy: https://policies.google.com/privacy

---

### 6. Contact

Questions about this policy:
**stewiegriffin3108ia@gmail.com**

*Document processing is fully local. Only ad serving requires internet access.*
''';
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
