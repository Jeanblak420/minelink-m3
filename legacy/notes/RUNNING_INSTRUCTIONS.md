# The Mineral Guide - Running Instructions

This document provides instructions for running The Mineral Guide application and avoiding common issues.

## Prerequisites

- Flutter SDK (version 3.32.0-beta or higher)
- Dart SDK (version 3.8.0 or higher)
- A code editor (VS Code recommended)
- Git

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/Blak-42069/The_Mineral_Guide.git
   cd The_Mineral_Guide
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run --dart-define-from-file=config/supabase.live.json
   ```

   This repo is configured for the live Supabase project only. The web scripts and VS Code launch config already use `config/supabase.live.json`.

   For web:
   ```bash
   flutter run -d chrome --web-port=61783 --web-hostname=localhost --dart-define-from-file=config/supabase.live.json
   ```

## Common Issues and Solutions

### File Selection

The app now uses `image_picker` for image selection and `file_selector` for generic file attachments. If file selection is not working as expected, run:

```bash
flutter pub get
flutter analyze
```

This verifies that the current platform integrations are installed correctly.

### Port Already in Use

If you see an error about the port already being in use:

```
Error: Cannot start Flutter web server on port 61783.
```

**Solution**:
1. Find the process using the port:
   ```
   netstat -ano | findstr :61783
   ```

2. Kill the process:
   ```
   taskkill /F /PID <PID>
   ```

3. Try running the app again.

### Supabase Initialization Issues

If you encounter issues with Supabase initialization:

**Solution**:
1. Check your internet connection
2. Verify that the Supabase project is up and running
3. Try running the minimal app to test Supabase connectivity:
   ```bash
   flutter run -t lib/minimal_app.dart
   ```

### Debug Mode

The application includes a floating debug button that can be used to access debug information and tools. Click the bug icon in the bottom right corner to toggle the debug panel.

## Testing

Run tests with:

```bash
flutter test
```

## Analyzing Code

Check for code issues with:

```bash
flutter analyze
```

## Updating Dependencies

Update dependencies to the latest versions with:

```bash
flutter pub upgrade
```

For major version updates:

```bash
flutter pub upgrade --major-versions
```

## Troubleshooting

If you encounter any issues not covered here, try the following steps:

1. Clean the project:
   ```bash
   flutter clean
   flutter pub get
   ```

2. Restart your IDE

3. Check the Flutter doctor for any issues:
   ```bash
   flutter doctor -v
   ```

4. If Supabase-related issues persist, try running the debug app:
   ```bash
   flutter run -t lib/debug_supabase.dart
   ```

## Contact

For further assistance, please contact the project maintainer.
