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
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/theme/app_colors.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:startapp_sdk/startapp.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheUsed = '…';
  bool _clearingCache = false;
  String _appVersion = '…';
  int _defaultQuality = 75;
  String _ocrLanguage = 'en';

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
    _calcCache();
    _loadVersion();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _defaultQuality = prefs.getInt(kPrefImageQuality) ?? 75;
        _ocrLanguage = prefs.getString(kPrefOcrLanguage) ?? 'en';
      });
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() =>
            _appVersion = '${info.version} (build ${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.1');
    }
  }

  Future<void> _calcCache() async {
    try {
      int cacheTotal = 0;
      final cacheDir = await getApplicationCacheDirectory();
      await for (final e
          in cacheDir.list(recursive: true, followLinks: false)) {
        if (e is File) cacheTotal += await e.length();
      }
      if (mounted) setState(() => _cacheUsed = _fmt(cacheTotal));
    } catch (_) {
      if (mounted) setState(() => _cacheUsed = '0 B');
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      int freed = 0;
      int count = 0;

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
      await _calcCache();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _showThemeModeDialog(BuildContext context) async {
    final ThemeMode currentMode = ref.read(themeProvider);
    final ThemeMode? newMode = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Theme'),
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
                    title: Text('System'),
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
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.muted(brightness);

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _CardSection(title: 'Appearance', children: [
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dark_mode_outlined,
                    size: 16, color: Color(0xFF9C27B0)),
              ),
              title: const Text('Theme'),
              subtitle: Text(_getThemeModeName(ref.watch(themeProvider))),
              trailing: Icon(Icons.chevron_right, color: muted),
              onTap: () => _showThemeModeDialog(context),
            ),
          ]),
          const SizedBox(height: 20),

          _CardSection(title: 'Processing', children: [
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, size: 16, color: Color(0xFFFF9800)),
              ),
              title: const Text('Image quality'),
              subtitle: Text('$_defaultQuality%'),
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
            Divider(height: 1, color: AppColors.border(brightness)),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.translate,
                    size: 16, color: Color(0xFF3F51B5)),
              ),
              title: const Text('OCR language'),
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
          const SizedBox(height: 20),

          _CardSection(title: 'Storage', children: [
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFE53935)),
              ),
              title: const Text('Clear cache'),
              subtitle: Text(_cacheUsed),
              trailing: _clearingCache
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _clearCache,
                      child: const Text('Clear'),
                    ),
            ),
          ]),
          const SizedBox(height: 20),

          _CardSection(title: 'Privacy & About', children: [
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF607D8B).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.policy_outlined,
                    size: 16, color: Color(0xFF607D8B)),
              ),
              title: const Text('Privacy Policy'),
              trailing: Icon(Icons.chevron_right, color: muted),
              onTap: () => _showPrivacyPolicy(context),
            ),
            Divider(height: 1, color: AppColors.border(brightness)),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF009688)),
              ),
              title: const Text('Version'),
              subtitle: Text(_appVersion),
            ),
            Divider(height: 1, color: AppColors.border(brightness)),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.balance_outlined,
                    size: 16, color: AppColors.navy),
              ),
              title: const Text('Licences'),
              trailing: Icon(Icons.chevron_right, color: muted),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'QuickPDF',
                applicationVersion: _appVersion,
              ),
            ),
          ]),
          const SizedBox(height: 24),

          if (AdService.shouldShowAds)
            _CardSection(title: 'Premium', children: [
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star, size: 16, color: Colors.amber),
                ),
                title: const Text('24h Ad-Free Premium'),
                subtitle: const Text('Watch a short video to remove ads for 24 hours'),
                trailing: TextButton(
                  onPressed: () {
                    AdService().showRewardedOrFallback(onRewarded: () async {
                      await AdService.activate24hPremium();
                      if (mounted) setState(() {});
                    });
                  },
                  child: const Text('Watch'),
                ),
              ),
            ]),
            
          if (AdService.shouldShowAds) const _MrecAd(),
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

**Effective date: July 2026**

QuickPDF processes documents **on your device**. There are no accounts and no file uploads.

### Permissions
- **Camera** — document scanning
- **Storage** — open and save PDFs/images you choose
- **Internet** — ads (Start.io) and optional store features

### Files
Files you open or create stay on your device. Temporary cache can be cleared in Settings.

### OCR
Text recognition uses on-device ML Kit models. Recognised text does not leave your device.

### Advertising
QuickPDF shows ads via **Start.io**. Document content is not used for ads.

Contact: **stewiegriffin3108ia@gmail.com**
''';
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted(brightness),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MrecAd extends StatefulWidget {
  const _MrecAd();

  @override
  State<_MrecAd> createState() => _MrecAdState();
}

class _MrecAdState extends State<_MrecAd> {
  StartAppBannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (AdService.shouldShowAds) {
      AdService().sdk.loadBannerAd(StartAppBannerType.MREC).then((ad) {
        if (mounted) setState(() => _ad = ad);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 24),
      child: StartAppBanner(_ad!),
    );
  }
}
