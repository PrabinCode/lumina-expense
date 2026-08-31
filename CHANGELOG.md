# Changelog

All notable changes to this project will be documented in this file.

The format is a modified version of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
- `Added` - for new features.
- `Changed` - for changes in existing functionality.
- `Improved` - for enhancement or optimization in existing functionality.
- `Removed` - for now removed features.
- `Fixed` - for any bug fixes.
- `Other` - for technical and release chores.

## [Unreleased]
### Added
- **Privacy Mask & Public Shield**: One-tap eye toggle in Dashboard and long-press on balance cards to instantly obscure financial balances (`$••••`) in public environments.
- **App Launcher Quick Shortcuts**: Static Android shortcuts (`shortcuts.xml`) with `lumina://` deep links for instant "Add Expense", "Add Income", and "Health Score" entry from home screen.
- **Advanced Boolean & Prefix Power Search**: Full query engine with prefixes (`cat:`, `acc:`, `tag:`, `note:`, `type:`, `amount:`, `date:`), comparative operators (`>`, `<`, `<=`, `>=`), negation (`-`), and logical operators (`&&`, `||`) with live token suggestions.
- **Batch Operations & Multi-Select Toolbar**: Long-press on transactions to activate multi-select mode with floating action bar for bulk category reassignment, wallet transfer, tagging, and batch deletion.
- **Database Maintenance & Storage Optimizer**: In-app maintenance suite with real-time SQLite storage stats, `VACUUM` defragmentation, `ANALYZE` query planner optimization, `PRAGMA integrity_check`, and temporary cache purging.
- **AES-256 Encrypted Backups**: Optional PBKDF2 SHA-256 + AES-256 CBC cipher encryption for local `.lumina.enc` archives and native share exports with password prompt on restore.
- **Curated Designer Theme Palettes**: Curated designer palettes including *Catppuccin Mocha*, *Tokyo Night*, *Nord Frost*, *Forest Emerald*, *Slate Emerald*, and *Pure Pitch Black AMOLED*.
- **Universal Bank CSV & App Migration Wizard**: Universal CSV importer with automatic header detection, interactive column dropdown mapping, dry-run balance preview, and auto-category creation from external apps (Cashew, Ivy Wallet, Monefy).

---


## [v1.2.0] - 2026-09-01
### Added
- Categorized Settings architecture grouping features into **Financial Tools** and **Preferences** ([@PrabinCode](https://github.com/PrabinCode))
- Multi-slide interactive onboarding walkthrough with feature highlights and settings tour ([@PrabinCode](https://github.com/PrabinCode))
- In-app feedback and bug reporting sheet with native system log attachments and device diagnostics ([@PrabinCode](https://github.com/PrabinCode))
- Dedicated standalone Privacy Policy sub-route and regulatory disclosure sheet ([@PrabinCode](https://github.com/PrabinCode))
- In-app system diagnostics inspector displaying database statistics, device environment, and app versioning metadata ([@PrabinCode](https://github.com/PrabinCode))

### Improved
- Polished settings navigation hierarchy with distinct icon badge categories and unified Material 3 card styling ([@PrabinCode](https://github.com/PrabinCode))
- Refreshed high-resolution Play Store showcase screenshots with authentic financial dataset seeder ([@PrabinCode](https://github.com/PrabinCode))
- App launcher icon and brand assets alignment for Google Play release submission ([@PrabinCode](https://github.com/PrabinCode))

### Fixed
- Fixed Privacy Policy navigation tile misdirection by routing to a dedicated standalone viewer ([@PrabinCode](https://github.com/PrabinCode))

### Other
- Bumped app release version to `1.2.0+3` for production release ([@PrabinCode](https://github.com/PrabinCode))

---

## [v1.1.0] - 2026-08-17
### Added
- Overhauled Backup & Restore architecture with dedicated persistent storage management:

  - Custom storage folder selection with SAF and direct device `Downloads` directory options ([@PrabinCode](https://github.com/PrabinCode))
  - In-app local backup browser with metadata inspector and snapshot preview before restoring ([@PrabinCode](https://github.com/PrabinCode))
  - Automatic backup pruning mechanism to keep the latest historical snapshots ([@PrabinCode](https://github.com/PrabinCode))
- Official Lumina Expense brand identity, vectors, and adaptive launcher icons ([@PrabinCode](https://github.com/PrabinCode))
- Dynamic multi-currency selector supporting 30+ global fiat currencies with localized formatting ([@PrabinCode](https://github.com/PrabinCode))
- Interactive drag-and-drop category reordering with persistent custom sorting ([@PrabinCode](https://github.com/PrabinCode))
- Permanent Android production release keystore configuration for seamless Google Play and APK updates ([@PrabinCode](https://github.com/PrabinCode))

### Improved
- Biometric App Lock unlock flow with lifecycle observer and screen transition guards ([@PrabinCode](https://github.com/PrabinCode))
- SharedPreferences theme mode persistence and seamless dark mode transitions ([@PrabinCode](https://github.com/PrabinCode))

### Fixed
- Fixed race condition in biometric authentication prompt on app resume ([@PrabinCode](https://github.com/PrabinCode))
- Fixed AAPT2 resource compilation error by re-encoding app logo and launcher assets to genuine 32-bit PNG format ([@PrabinCode](https://github.com/PrabinCode))

---

## [v1.0.0] - 2026-08-16
### Added
- **Initial Release** of **Lumina Expense** — 100% Offline-First, zero cloud lock-in, privacy-centric personal finance manager ([@PrabinCode](https://github.com/PrabinCode))
- **Fast 3-Tap Transaction Entry**:
  - Built-in numeric keypad with instant inline math calculation
  - Support for Expenses, Incomes, and Account Transfers
  - Multi-category Split Transactions with real-time budget allocation
- **Smart Financial Health Score**:
  - Algorithmic 0–100 health gauge assessing savings rate, budget discipline, debt burden, and runway
  - Personalized actionable financial insights card on Dashboard
- **Security & Privacy Shield**:
  - Biometric fingerprint/face lock with configurable auto-lock timeout
  - Privacy Shield covering app contents in Android recent apps switcher
- **Budgets & Sinking Funds**:
  - Monthly category spending caps with progressive color warnings (Green $\to$ Amber $\to$ Red)
  - Savings Goals with visual target progress, target dates, and allocation tracking
- **Subscriptions & Recurring Bills**:
  - Recurring expense scheduler with monthly burn rate calculations and auto-logging
- **Debt & Lending (IOU) Manager**:
  - "They Owe Me" and "I Owe" tracker with partial and full settlement logs
- **Local Analytics & Charts**:
  - Interactive spending distribution donut chart powered by `fl_chart`
  - Monthly net cash flow and net worth calculation
- **Data Portability**:
  - Full database JSON export/import with validation
  - Spreadsheet-compatible CSV export for Excel and Google Sheets
- **Theming**:
  - Clean Material 3 design with Light, Dark Slate, and Pitch Black True AMOLED modes

### Fixed
- Fixed `Material` canvas clipping on custom `ListTile` and `InkWell` components ([@PrabinCode](https://github.com/PrabinCode))
- Stabilized async state pump in widget test suite for CI workflow compliance ([@PrabinCode](https://github.com/PrabinCode))
