================================================================================
  Mine-Link / The Mineral Guide — WINDOWS INSTALLATION INSTRUCTIONS
================================================================================

This file lives in the project's "windows" folder (Flutter Windows sources).
The program you actually run is NOT here — it is produced by a release build.

--------------------------------------------------------------------------------
PART A — IF YOU ARE THE DEVELOPER (where the .exe is built)
--------------------------------------------------------------------------------

Step 1 — Open a terminal in the project root folder
        Example:
        C:\Users\...\TheMineral Guide\worktree-2026-05-05T11-53-29

Step 2 — Build the Windows release
        Command:
        flutter build windows --release

Step 3 — Navigate to the build output folder (this is where the installable
         program lives):

        <PROJECT_ROOT>\build\windows\x64\runner\Release

        Full example (adjust to your machine):
        C:\Users\Somebody Someone\Music\TheMineral Guide\worktree-2026-05-05T11-53-29\build\windows\x64\runner\Release

Step 4 — What you must ship
        Zip the ENTIRE "Release" folder (not only one file). It contains:
        - minelink.exe   ← this is the file users double-click to start the app
        - All .dll files next to it
        - The "data" folder (required — do not omit)

        Point your zip tool at:
        ...\build\windows\x64\runner\Release
        and compress everything inside that folder.

--------------------------------------------------------------------------------
PART B — IF YOU ARE THE END USER (installing from a zip someone sent you)
--------------------------------------------------------------------------------

Step 1 — Choose where to install (extract) on your PC
        Recommended: a folder you own, for example:
        - Desktop\Mine-Link
        - Documents\Mine-Link
        - C:\Apps\Mine-Link

        Avoid: Program Files (may need admin rights). Any normal folder is fine.

Step 2 — Extract the zip
        Extract so that you see minelink.exe, the DLL files, and a "data"
        folder all in the SAME folder (one level — do not nest only the .exe).

Step 3 — Navigate to that folder in File Explorer
        Open the folder where you extracted. You should see:
        minelink.exe

Step 4 — Run the application
        Double-click:  minelink.exe

        That is the only file you "run". Do not move minelink.exe away from
        the DLLs and the "data" folder.

Step 5 — First launch (Windows SmartScreen)
        If Windows shows "Windows protected your PC":
        - Click "More info"
        - Click "Run anyway"
        (Common for apps that are not yet code-signed.)

Step 6 — Internet
        The app needs an internet connection to reach Supabase (your backend).

================================================================================
Quick reference — path to the file to install / run
================================================================================
  Built by Flutter:  <PROJECT_ROOT>\build\windows\x64\runner\Release\minelink.exe
  After you extract: <YOUR_CHOSEN_FOLDER>\minelink.exe
================================================================================
