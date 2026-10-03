# Pocket Manager

Pocket Manager is a private, offline-first personal finance application built with Flutter. It provides a focused way to record transactions, manage accounts, monitor savings goals, and understand day-to-day finances without requiring an online account.

## Product Overview

Pocket Manager is designed for people who want practical financial tracking with local data ownership. The application stores its core data on the device and keeps common workflows available without an internet connection.

## Features

- **Home dashboard** with an overview of account balances and recent activity
- **Transaction tracking** for income and expenses
- **Account management** for multiple financial accounts
- **Transfers** between accounts
- **Categories** with default and custom options
- **Savings goals** with contribution tracking
- **Reports and summaries** for reviewing financial activity
- **PIN protection** for an additional privacy layer
- **Backup and restore** using local files
- **Theme preferences** with light, dark, and system modes

## Privacy and Data Storage

Pocket Manager does not require registration, a cloud account, or an internet connection for its core functionality. Financial data is stored locally in a SQLite database on the device. Backups are user-controlled and can be created or restored through the application.

## Technology

- Flutter and Dart
- SQLite via `sqflite`
- `path_provider` for application storage
- `file_picker` for backup and restore workflows
- `crypto` for security-related operations

## Architecture

The application is organized into presentation, service, and data-access layers:

```text
Screens and widgets
		  |
	  Services
		  |
		 DAOs
		  |
		SQLite
```

- `screens/` and `widgets/` contain the user interface.
- `services/` contains business rules, validation, and workflow coordination.
- `database/` contains SQLite setup and data-access objects.
- `models/` defines the application's data structures.
- `utils/` contains shared utility code.

## Project Structure

```text
lib/
├── database/       # SQLite setup and data-access objects
├── models/         # Application data models
├── screens/        # Application screens and feature areas
├── services/       # Business logic and workflows
├── utils/          # Shared utilities
└── widgets/        # Reusable UI components

assets/             # Application assets
test/               # Automated tests
```

## Requirements

- Flutter SDK
- Dart SDK compatible with the version in `pubspec.yaml`
- Android Studio and Android SDK for Android development
- Xcode for iOS development on macOS

## Setup

Clone the repository and install the project dependencies:

```bash
git clone https://github.com/prikshit-bot/Manager.git
cd Manager
flutter pub get
```

Run the application on a connected device or emulator:

```bash
flutter run
```

## Testing

Run the complete test suite with:

```bash
flutter test
```

## Android Release Build

Build a release APK with:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Implement the change and add tests where appropriate.
4. Run `flutter test`.
5. Open a pull request with a clear description of the change.

## Project Status

Pocket Manager is currently at version `1.0.0` and provides the core personal finance workflows described above.

## License

This project does not currently specify an open-source license.