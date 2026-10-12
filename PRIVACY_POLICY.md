# QuickPDF — Privacy Policy

**Effective date:** October 2026  
**App version:** 1.1.6 (Build 21)  
**Developer contact:** stewiegriffin3108ia@gmail.com  

---

## 1. Overview

QuickPDF is an offline-first document workstation for Android. All document processing — including scanning, compressing, merging, splitting, signing, watermarking, password encryption, and OCR text extraction — happens entirely on your local device. We do not operate external file servers, require accounts, or upload your documents.

To support free maintenance and development, QuickPDF displays advertisements served by **Unity Ads**. Unity Ads is the only third-party component that communicates with external servers.

---

## 2. Information We Collect

**QuickPDF itself collects, stores, and transmits zero personal information.**

Our third-party advertising partner, **Unity Ads**, may automatically collect standard device and telemetry data to serve and optimize advertisements:

| Data Type | Purpose |
| :--- | :--- |
| **Android Advertising ID (AAID / GAID)** | Ad frequency capping, attribution, and personalized or contextual ad delivery |
| **IP Address** | Coarse geographical location (country/region level) for relevant ad delivery |
| **Device & Hardware Information** | Device model, manufacturer, OS version, screen size, language, and network connection type (Wi-Fi/Cellular) |
| **Ad Engagement Signals** | Ad views, impressions, click-through rates, and video completion metrics |

This data is processed directly by Unity Technologies in accordance with their privacy policy. QuickPDF does not store, intercept, or have access to any of this telemetry data.

---

## 3. How We Handle Your Information

- **Your Documents & Images:** Processed locally in memory and saved strictly within the device's sandboxed storage. Your files are never uploaded, analyzed, or shared.
- **Extracted Text (OCR) & Signatures:** Kept locally on your device in the app's private SQLite database or cache.
- **Biometric Authentication:** Used only if enabled to unlock locked documents or secure the app. Authentication is handled entirely by the Android operating system (`BiometricPrompt` / Android Keystore); QuickPDF never accesses or stores your biometric credentials.
- **Advertising Data:** Handled strictly by Unity Ads according to industry privacy standards and Google Play Developer policies.

---

## 4. Permissions Explained

QuickPDF only requests permissions strictly necessary to deliver its core functionality:

| Permission | Purpose |
| :--- | :--- |
| `CAMERA` | Required to capture physical paper documents when using the Document Scanner feature. |
| `INTERNET` | Required by the Unity Ads SDK to load banner, interstitial, and rewarded advertisements. |
| `com.google.android.gms.permission.AD_ID` | Used by Unity Ads on Android 13+ for ad attribution, fraud prevention, and frequency capping. |
| `USE_BIOMETRIC` | Optional. Allows you to unlock password-protected PDFs or secure the app using your device's fingerprint or face unlock. |

> *Note on Storage Permissions:* QuickPDF utilizes Android's modern Storage Access Framework (SAF) and system file pickers to open and save files you explicitly select, eliminating the need for broad storage read/write permissions (`READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`).

---

## 5. Third-Party Services

### Unity Ads
- **Provider:** Unity Technologies, 30 3rd Street, San Francisco, CA 94103, USA
- **Purpose:** Serving banner, interstitial, and rewarded advertisements
- **Privacy Policy:** [https://unity.com/legal/privacy-policy](https://unity.com/legal/privacy-policy)
- **Player & App User Privacy FAQ:** [https://unity.com/legal/game-player-and-app-user-privacy-faq](https://unity.com/legal/game-player-and-app-user-privacy-faq)
- **Opt-out:** You can opt out of personalized advertising at any time via Android System Settings (`Settings` → `Google` → `Ads` → `Delete advertising ID` or `Opt out of Ads Personalization`).

### Google ML Kit (Text Recognition)
- **Provider:** Google LLC
- **Purpose:** On-device Optical Character Recognition (OCR) to extract text from images and scanned documents.
- **Privacy Assurance:** The machine learning models run **100% on-device**. No document images, scans, or recognized text are transmitted to Google servers.
- **Terms & Information:** [https://developers.google.com/ml-kit/terms](https://developers.google.com/ml-kit/terms)

---

## 6. Data Sharing & Disclosure

We do not sell, rent, trade, or share your personal information. Data transmission is limited to:
- **Unity Ads:** Device identifiers and ad interaction signals sent directly to Unity Technologies for ad serving as described in Section 2.
- **Legal Compliance:** In the unlikely event required by applicable law, regulation, or legal process.

---

## 7. Data Retention & Deletion

- **Local Files:** All PDFs, scans, annotations, and signatures remain solely on your device. You can delete individual documents anytime via the app or your device's file manager.
- **Cache & App Data:** You can purge cached pages and thumbnails at any time in **Settings → Storage & Cache → Clear Cache**, or by clearing app storage in Android settings (`Settings` → `Apps` → `QuickPDF` → `Storage` → `Clear Data`).
- **Advertising Data:** Governed by Unity Technologies' data retention schedules.

---

## 8. Your Rights & Privacy Choices

You maintain full control over your data:
- **Advertising Opt-Out:** Reset or delete your Advertising ID via Android Settings (`Settings` → `Google` → `Ads`).
- **Permission Control:** Revoke Camera or Biometric permissions at any time via Android Settings (`Settings` → `Apps` → `QuickPDF` → `Permissions`).
- **Data Erasure:** Uninstalling the app permanently removes all sandboxed documents, local database records, and app caches from your device.

---

## 9. Children’s Privacy

QuickPDF is designed for general audiences and is not directed at children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided personal information or encountered inappropriate ad content, please contact us immediately so we can take appropriate measures.

---

## 10. Security

We take data protection seriously:
- All file processing occurs strictly within the application's secure sandboxed storage.
- QuickPDF supports standard AES-256 encryption for securing PDF files with user passwords.
- No documents or document metadata are ever exposed or transmitted over the network.

---

## 11. Changes to This Policy

We may update this Privacy Policy from time to time to reflect improvements, feature additions, or regulatory updates. Any changes will be posted within the app under **Settings → Privacy Policy** and noted in Google Play release notes. Continued use of QuickPDF following updates constitutes your acceptance of the revised policy.

---

## 12. Contact Us

If you have any questions, suggestions, or concerns regarding this Privacy Policy:

- **Email:** stewiegriffin3108ia@gmail.com  
- **Application:** QuickPDF  
- **Developer:** Ian Gicheha Mbae  
- **Platform:** Google Play Store (Android)  

---

*Last updated: October 2026*
