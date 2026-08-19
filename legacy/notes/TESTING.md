# Testing Instructions

## Running the App on Port 61783

To ensure the app always runs on port 61783, you can use one of the following methods:

### Method 1: Using the Batch File

1. Double-click the `run_web.bat` file in the project root directory
2. This will launch the app in Chrome on port 61783

### Method 2: Using PowerShell

1. Right-click the `run_web.ps1` file and select "Run with PowerShell"
2. This will launch the app in Chrome on port 61783

### Method 3: Using VS Code

1. Open the project in VS Code
2. Press F5 or click the "Run and Debug" button
3. Select "Flutter Web (Port 61783)" from the dropdown menu
4. The app will launch in Chrome on port 61783

### Method 4: Using Command Line

Run the following command in the terminal:

```
flutter run -d chrome --web-port=61783 --web-hostname=localhost
```

## Testing the Employee Sign-Up and Verification Workflow

1. **Employee Registration and Company Selection**:
   - Register as an employee
   - Select a company from the list
   - Verify you're redirected to the dashboard with the pending overlay

2. **Pending State**:
   - Verify that only the Profile and Sign Out buttons are functional
   - Try clicking on other tabs to confirm they're disabled
   - Sign out and sign back in to verify the pending state persists

3. **Company Role Assignment**:
   - Log in as a company
   - Check for the notification badge in the app bar
   - Open notifications to see the employee request
   - Navigate to the Manage Employees screen
   - Assign a role to the employee

4. **Employee Role Activation**:
   - Log in as the employee
   - Verify the welcome notification appears
   - Confirm the pending overlay is gone
   - Verify all tabs corresponding to the assigned role are now functional
