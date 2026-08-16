# Contributing to Lumina Expense

Thank you for your interest in contributing to **Lumina Expense**! As an open-source project, contributions from the community are welcomed.

## Development Workflow

1. **Fork & Branch**: Create a feature branch with a descriptive name (e.g. `feat/recurring-bills` or `fix/backup-restore-validation`).
2. **Local Isolation**: Do not commit local IDE configuration, credentials, or AI agent instruction files. Verify that your `.gitignore` is intact.
3. **Database Migrations**: If modifying tables in `lib/core/database/tables.dart`, increment `schemaVersion` in `app_database.dart` and run:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. **Code Quality**: Ensure all tests pass and there are zero static analysis issues:
   ```bash
   flutter test
   dart analyze lib test
   ```
5. **Commit Messages**: Follow Conventional Commits format (e.g. `feat: add category icon picker`, `fix: handle null dates on CSV export`).
