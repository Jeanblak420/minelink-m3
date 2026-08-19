# Script to generate mock files for tests
Write-Host "Generating mock files for tests..."
flutter pub run build_runner build --delete-conflicting-outputs
Write-Host "Mock files generated successfully!"
