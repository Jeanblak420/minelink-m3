# Script to generate mock files for tests
Write-Host "Generating mock files for tests..."

# Generate mocks for fleet_provider_test.dart
Write-Host "Generating mocks for fleet_provider_test.dart..."
flutter pub run build_runner build --build-filter="test/providers/fleet_provider_test.mocks.dart" --delete-conflicting-outputs

# Generate mocks for fleet_notification_service_test.dart
Write-Host "Generating mocks for fleet_notification_service_test.dart..."
flutter pub run build_runner build --build-filter="test/services/fleet_notification_service_test.mocks.dart" --delete-conflicting-outputs

# Generate mocks for fleet_service_test.dart
Write-Host "Generating mocks for fleet_service_test.dart..."
flutter pub run build_runner build --build-filter="test/services/fleet_service_test.mocks.dart" --delete-conflicting-outputs

# Generate mocks for realtime_test.dart
Write-Host "Generating mocks for realtime_test.dart..."
flutter pub run build_runner build --build-filter="test/realtime_test.mocks.dart" --delete-conflicting-outputs

Write-Host "Mock generation complete!"
