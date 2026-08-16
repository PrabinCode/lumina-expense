# 💎 Lumina Expense — 100% Offline-First Personal Finance Tracker

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database: Drift SQLite](https://img.shields.io/badge/Database-Drift%20SQLite-003B57?logo=sqlite)](https://drift.simonbinder.eu/)
[![Offline First](https://img.shields.io/badge/Storage-100%25%20Offline-success)](#)

**Lumina Expense** is a modern, lightweight, privacy-focused expense tracker and personal finance manager built with **Flutter**, **Riverpod**, and **Drift (SQLite)**. 

It is designed with an **offline-first philosophy**: zero cloud lock-in, zero trackers, zero account sign-up, and complete data ownership with one-tap JSON & CSV backup to Google Drive or local storage.

---

## ✨ Features

### ⚡ Fast Transaction Flow
* **3-Tap Quick Entry**: Fast numeric keypad with instant calculation for Expenses, Income, and Transfers.
* **Custom Categories & Subcategories**: Pre-seeded with 17+ essential categories with customizable icons and color coding.
* **Multi-Account / Wallets**: Track balances across multiple sources (Cash Wallet, Bank Accounts, Credit Cards, Savings).
* **Account Transfers**: Move funds between wallets with real-time balance calculations.

### 🛡️ Backup & Restore (Your Data, Your Control)
* **One-Tap JSON Export**: Export the entire database snapshot to a versioned `.json` file and trigger the native **OS Share Sheet** to save directly to **Google Drive**, **iCloud**, **Files**, or send via Email.
* **Spreadsheet CSV Export**: Generate `.csv` transaction sheets compatible with Microsoft Excel and Google Sheets.
* **Safe Import with Validation**: Preview summary counts (transactions, accounts, budgets) before restoring with overwrite confirmation.
* **Demo Data Generator**: One-click button in Settings to populate realistic sample data for instant exploration and testing.

### 📊 Budgets & Visual Analytics
* **Monthly Category Budgets**: Set spending caps per category with visual progress bars and color warnings (Green $\to$ Amber at 80% $\to$ Red at 100%).
* **Interactive Donut Charts**: Powered by `fl_chart` for visual category spending breakdown.
* **Net Worth & Monthly Flow**: Live overview of Total Net Worth, Monthly Income, Expenses, and Net Savings.

### 🤝 Debt & Lending (IOU) Manager
* **"They Owe Me" vs. "I Owe"**: Track money lent to friends or borrowed from colleagues.
* **Partial & Full Settlements**: Record repayments that automatically sync with balance summaries.

### 🎨 Clean Material 3 & AMOLED Theming
* **Multiple Themes**: Supports System Default, Light Theme, Slate Dark Theme, and **Pure Pitch Black AMOLED Mode**.

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── database/          # Drift (SQLite) schema tables & migrations
│   ├── providers/         # Global Riverpod database providers
│   ├── theme/             # Material 3 tokens, colors & themes
│   └── utils/             # Currency formatter, Date helpers, Icon mapper
├── features/
│   ├── dashboard/         # Net worth card, quick actions, recent transaction feed
│   ├── transactions/      # 3-Tap transaction modal, numeric keypad, CRUD repository
│   ├── accounts/          # Account & wallet management
│   ├── categories/        # Category repository & selectors
│   ├── budgets/           # Monthly category budgets & progress tracking
│   ├── analytics/         # Interactive fl_chart spending donut & monthly stats
│   ├── debts/             # IOU lending, borrowing & settlement manager
│   ├── backup/            # JSON/CSV export, file picker restore & demo seeder
│   └── settings/          # Theme switcher & data preferences
└── main.dart              # Riverpod ProviderScope & Navigation shell
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.x or higher)
* Dart SDK (3.x or higher)
* Android Studio / Xcode / VS Code

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/lumina_expense.git
   cd lumina_expense
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate Drift database code:
   ```bash
   dart run build_runner build
   ```

4. Run the app on your connected device/emulator:
   ```bash
   flutter run
   ```

---

## 🧪 Running Tests

Run all unit and widget tests:
```bash
flutter test
```

Run static analysis:
```bash
dart analyze lib test
```

---

## 🔒 Privacy & Local Isolation

* **100% Offline**: No network requests, analytics, or external telemetry are made by the application.
* **AI Agent & Local Rules Isolation**: Local developer instructions and editor overrides (`.agent-rules/`, `.cursorrules`, `.gemini/`) are strictly excluded from git tracking.

---

## 👤 Author & Maintainer

**Prabin Chandra Shrestha (PC Shrestha)**
* **Portfolio & Blog**: [pcshrestha.com.np](https://pcshrestha.com.np)
* **GitHub**: [@PrabinCode](https://github.com/PrabinCode)
* **LinkedIn**: [in/pcshrestha](https://www.linkedin.com/in/pcshrestha/)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
