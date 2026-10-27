# Household Budget Book

A beginner-friendly Flutter/Dart project for a lab demonstration. It tracks household income and expenses, calculates the available balance, filters transaction history, and stores entries locally with `shared_preferences`.

## Features

- Dashboard with balance, total income, and total expenses
- Add income and expense transactions with title, amount, and category
- Transaction history with All / Income / Expenses filters
- Delete transactions
- Budget summary and a simple expense overview
- Local persistence between sessions

## Tech stack

- Flutter and Dart
- Material 3 widgets
- `shared_preferences` for local key-value storage
- JSON encoding/decoding for transaction records

## Run in FlutLab

1. Open FlutLab and create/import a Flutter project.
2. Ensure `pubspec.yaml` and the `lib` folder are at the project root.
3. Resolve dependencies (for example, `flutter pub get` if a terminal is available).
4. Run in a supported emulator or web preview.

## Notes

This is a learning/demo app, not a financial product. Data is stored locally and is not synced between devices. Web storage behavior depends on the selected target and package support. No bank account or payment information is connected.

## Viva topics

- Flutter widgets and Material Design
- `StatefulWidget`, `StatelessWidget`, and `setState`
- Dart classes and enums
- Form validation and callbacks
- JSON encoding/decoding
- Local storage with SharedPreferences
- Income, expense, and balance calculations
