# 🚀 Lumina Expense Tracker — Release & Operations Guide
> Author: **Prabin Chandra Shrestha (@PrabinCode)**  
> Application ID: `com.prabincode.luminaexpense`  
> Version: `1.2.0+3` (Name: `v1.2.0`, Code: `3`)  
> Website & Documentation: [https://pcshrestha.com.np/lumina-expense-tracker](https://pcshrestha.com.np/lumina-expense-tracker)

---

## 🛠️ Essential Project Commands Cheatsheet

### 1. 📦 Build Production Binaries

#### Build Android App Bundle (`.aab`) for Google Play Store:
```powershell
flutter build appbundle --release
```
* **Output Path**: `build/app/outputs/bundle/release/app-release.aab`
* **Use for**: Uploading directly to Google Play Console (Production / Internal Testing / Closed Testing).

#### Build Standalone Signed APK (`.apk`) for Direct Download & Testing:
```powershell
flutter build apk --release
```
* **Output Path**: `build/app/outputs/flutter-apk/LuminaExpense-v1.2.0-PrabinCode.apk`
* **Use for**: Installing directly on your physical Android device or attaching to GitHub Releases.

---

### 2. 🧪 Code Quality, Testing & Database Generation

#### Run Code Static Analysis:
```powershell
flutter analyze lib test
```

#### Run All Automated Unit & Widget Tests:
```powershell
flutter test test/backup_restore_test.dart test/widget_test.dart
```

#### Generate Drift Database SQLite Code & Schema (when modifying tables):
```powershell
dart run build_runner build --delete-conflicting-outputs
```

#### Capture Authentic App Screenshots for Website & Store:
```powershell
flutter test test/capture_real_screenshots_test.dart
```
* **Output Paths**: `playstore_assets/screenshots/` and `portfolio/public/images/lumina/`

#### Update Adaptive Launcher Icons:
```powershell
dart run flutter_launcher_icons
```

---

## 🏬 Google Play Console Submission Checklist

### 1. Store Listing Details
* **App Name**: `Lumina Expense Tracker`
* **Short Description** *(80 chars max)*:
  ```text
  100% offline personal expense tracker, budget planner & multi-wallet manager.
  ```
* **Full Description**:
  ```text
  Lumina Expense Tracker is a fast, 100% offline personal finance manager and budget tracker created by Prabin Chandra Shrestha (@PrabinCode). Designed with total privacy in mind, all data is stored securely on your device with zero cloud tracking, zero advertising, and zero monthly subscriptions.

  💎 Key Features:
  • 3-Tap Rapid Logging: Fast custom numeric keypad with built-in calculator and split transactions.
  • Multi-Wallet Accounts: Manage Cash, Bank accounts, Savings, and Credit Cards with real-time transfer tracking.
  • Visual Analytics & Donut Charts: Interactive monthly income vs expense cash flow comparisons.
  • Monthly Category Budgets: Proactive visual progress bars with dynamic warning thresholds.
  • Savings Goals & Sinking Funds: Milestone targets with deposit logs and completion tracking.
  • Debt & Loan Manager: Track money lent ("They Owe Me") and borrowed with partial settlements.
  • Biometric App Lock & Privacy Shield: Protect balances with Face ID/Fingerprint and app switcher blur.
  • One-Tap JSON & CSV Export: 100% data portability for Microsoft Excel and Google Sheets.

  🔒 100% Offline Privacy Guarantee:
  No account registration required. Zero telemetry, zero analytics SDKs, and zero developer servers.
  ```

* **Category**: `Finance`
* **Tags**: `Personal Finance`, `Budgeting`, `Expense Tracker`, `Productivity`
* **Privacy Policy URL**: `https://pcshrestha.com.np/lumina-expense-tracker/privacy-policy`
* **Developer Email**: `prabin@pcshrestha.com.np`
* **Developer Website**: `https://pcshrestha.com.np`

---

### 2. Graphic Assets Locations
All required assets are pre-formatted to Google Play specifications:
* **App Icon (512x512 PNG)**: `playstore_assets/icon_512x512.png`
* **Feature Graphic (1024x500 PNG)**: `playstore_assets/feature_graphic_1024x500.png`
* **Phone Screenshots (1080x2400 PNG)**: `playstore_assets/screenshots/`
  1. `screenshot_dashboard.png` (Dashboard & Net Worth)
  2. `screenshot_analytics.png` (fl_chart Spending Donut)
  3. `screenshot_budgets.png` (Category Budget Caps)
  4. `screenshot_goals.png` (Savings Goals Milestones)
  5. `screenshot_debts.png` (Debt & Loan Manager)
  6. `screenshot_settings.png` (Security, AMOLED & Diagnostics)

---

### 3. Policy & Data Safety Questionnaire Answers
* **Target Audience**: 18 and over (or 13+ / All Ages). Content Rating will be **Everyone (3+)**.
* **Financial Features**: Personal finance tracking only (not a bank, lender, or crypto exchange).
* **Data Safety Declaration**:
  * *Does your app collect or share user data?* $\to$ **No**.
  * *Is all user data stored locally on the device?* $\to$ **Yes**.
  * *Are all features usable without an account?* $\to$ **Yes**.

---

## 🔄 How to Release Future Updates (`v1.2.0`, `v1.3.0`, etc.)

1. **Bump Version in `pubspec.yaml`**:
   ```yaml
   version: 1.2.0+3  # (Version Name: 1.2.0, Version Code: 3)
   ```
2. **Run Tests & Verify**:
   ```powershell
   flutter test
   ```
3. **Build the New Bundle**:
   ```powershell
   flutter build appbundle --release
   ```
4. **Upload `build/app/outputs/bundle/release/app-release.aab`** to Google Play Console under **Releases &rarr; Create new release**.
