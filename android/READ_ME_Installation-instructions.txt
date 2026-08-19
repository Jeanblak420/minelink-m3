================================================================================
  Mine-Link / The Mineral Guide — ANDROID INSTALLATION INSTRUCTIONS
================================================================================

This file lives in the project's "android" folder (Flutter Android project).
The installable app file is produced by a release build (see Part A).

--------------------------------------------------------------------------------
PART A — IF YOU ARE THE DEVELOPER (where the .apk is built)
--------------------------------------------------------------------------------

Step 1 — Open a terminal in the project root folder
        Example:
        C:\Users\...\TheMineral Guide\worktree-2026-05-05T11-53-29

Step 2 — Build the Android release APK
        Command:
        flutter build apk --release

Step 3 — Navigate to the folder that contains the installable APK:

        <PROJECT_ROOT>\build\app\outputs\flutter-apk

        Full example (adjust to your machine):
        C:\Users\Somebody Someone\Music\TheMineral Guide\worktree-2026-05-05T11-53-29\build\app\outputs\flutter-apk

Step 4 — Which file to install on the phone
        Default Flutter output name:
        app-release.apk

        That is the file you copy to the phone (USB, email, cloud, etc.).
        You may rename it (e.g. Mine-Link.apk) — the phone installs whatever
        .apk file you open.

        Optional: app-release.apk.sha1 in the same folder is a checksum for
        verifying the file was not corrupted when copying.

--------------------------------------------------------------------------------
PART B — IF YOU ARE THE END USER (installing on your Android phone)
--------------------------------------------------------------------------------

Step 1 — Get the APK onto your phone
        Copy app-release.apk (or Mine-Link.apk) to Downloads or any folder you
        can open with the Files app.

Step 2 — Where "installation" happens on the phone
        You do not choose a Windows-style folder. Android installs the app into
        the system app space. You only need to open the APK file once to install.

Step 3 — Open the APK
        Use Files / Downloads / your file manager and tap the .apk file.

Step 4 — Allow installation from this source (if asked)
        Settings may ask you to allow "Install unknown apps" for Files, Chrome,
        or whichever app you used to open the APK. Follow the prompt, then tap
        the APK again.

Step 5 — Tap Install, then Open
        After install, find the app in your app drawer (name shown on device).

Step 6 — Internet
        The app needs mobile data or Wi-Fi to reach Supabase.

Step 7 — Updates
        To update: install a newer APK over the old one (same package), or
        uninstall the old app first if the installer complains.

================================================================================
Quick reference — path to the file to install
================================================================================
  Built by Flutter:  <PROJECT_ROOT>\build\app\outputs\flutter-apk\app-release.apk
  On phone:          Tap that .apk after copying it to the device (any folder).
================================================================================
