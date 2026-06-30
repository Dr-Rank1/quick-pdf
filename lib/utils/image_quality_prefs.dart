import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';

/// Reads the user's default image quality from SharedPreferences (50–100).
Future<int> readDefaultImageQuality() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getInt(kPrefImageQuality) ?? 75).clamp(50, 100);
}
