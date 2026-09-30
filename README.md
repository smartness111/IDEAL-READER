# Ideal Reader — Setup & Build Guide

A simple app that lets you add books and documents — `.txt`, `.epub`,
`.docx`, `.pdf`, `.jpg`/`.png` — and have them read aloud, on both
**Windows** and **Android**. Everything runs on-device: nothing in this
app talks to the internet, and on Android the release build is set up so
it's not even *allowed* to (more on that in "Working fully offline"
below). Reading keeps going with the phone screen locked or the app
minimized (see "Reading with the screen locked or the app minimized").
Built with Flutter and free packages.

This zip contains only the app's own files — `lib/`, `pubspec.yaml`, two
small Android manifest files, and the two files used in step 5 to package
a proper Windows installer. You'll generate the surrounding native project
shell with the free Flutter tool itself in step 2 below — that's the
normal, reliable way to do it. (No local installs at all? See "Alternative:
get the installer without installing anything" further down.)

---

## 1. Install the free tools (one-time setup)

1. **Flutter SDK** — https://docs.flutter.dev/get-started/install (free).
   Follow the guide for your OS (you'll build from Windows for both targets).
2. **Android Studio** — https://developer.android.com/studio (free). During
   setup it also installs the Android SDK, which you need even if you code
   in a different editor like VS Code.
3. **Visual Studio 2022 Community** — https://visualstudio.microsoft.com
   (free). When installing, tick the **"Desktop development with C++"**
   workload — this is required to build the Windows app.
4. Open a terminal and run:
   ```
   flutter doctor
   ```
   Fix anything it flags with a ✗ (it gives you the exact command each time,
   e.g. `flutter doctor --android-licenses` to accept Android SDK licenses).

## 2. Create the project shell and drop in this code

```
flutter create --org com.idealpathimpactful ideal_reader
cd ideal_reader
flutter config --enable-windows-desktop
```
(`--org` sets the app's publisher identity — here, your NGO — inside the
generated Android/Windows project files.)

Now copy the files from this zip into the new `ideal_reader` folder,
**overwriting** the generated `pubspec.yaml` and `lib/main.dart`:

- `pubspec.yaml` → replaces the generated one
- `lib/main.dart` → replaces the generated one
- `lib/models/`, `lib/services/`, `lib/screens/` → new folders, copy as-is
- `android/app/src/main/AndroidManifest.xml` → **replaces** the generated
  one. It turns on reading with the screen locked (see the next sections).
  The generated `MainActivity` file is no longer used; leave it alone.
- `android/app/src/release/AndroidManifest.xml` → new file (create the
  `release` folder). See "Working fully offline" below for what it does.
- `installer/ideal_reader.iss` and `.github/workflows/build.yml` → new
  files, used later in step 5 to get an actual double-click installer.

Then install the dependencies:
```
flutter pub get
```

## 3. Run it

**Windows (on your PC):**
```
flutter run -d windows
```

**Android (device or emulator):**
- Plug in a phone with USB debugging on (Settings → About phone → tap
  "Build number" 7 times → Developer options → USB debugging), or start an
  emulator from Android Studio.
- Then:
```
flutter devices
flutter run -d <device-id-from-the-list-above>
```

## 4. Build the real apps

**Windows:**
```
flutter build windows
```
Output: `build\windows\x64\runner\Release\` — this folder alone will run on
another Windows PC without Flutter installed, but it's a loose folder, not
an installer. Step 5 turns it into one.

**Android (an .apk you can install directly):**
```
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk` — copy this to your
phone and open it to install (you may need to allow "install from unknown
sources" once, since it's not from the Play Store).

## 5. Package a real Windows installer (double-click to install)

This turns the folder from step 4 into a single `IdealReaderSetup.exe` —
something you (or anyone you give it to) can double-click, click Next a
few times, and have Ideal Reader properly installed with a Start Menu
entry, a desktop shortcut, and a normal uninstaller in "Apps & Features".

1. Download and install **Inno Setup** (free): https://jrsoftware.org/isdl.php
   — get the plain installer, not the "-unicode" one; it already handles
   Unicode. One-time setup, a couple of minutes.
2. Open `installer\ideal_reader.iss` (from this zip, now inside your
   `ideal_reader` project folder) by double-clicking it — it opens in the
   **Inno Setup Compiler**.
3. Press **Ctrl+F9** (or Build → Compile).
4. The installer appears at `installer\Output\IdealReaderSetup.exe`.

That one file is what you share or double-click to install — no Flutter,
no folder-copying, no shortcut-making by hand. Whenever you rebuild the
app (step 4) after a change, just re-open and re-compile the `.iss` file
to get an updated installer.

If Inno Setup complains it can't find the app icon, open
`installer\ideal_reader.iss`, find the `SetupIconFile=` line near the top,
and delete that line and the comment above it — the installer still works
fine, just with Inno Setup's own default icon instead of the app's.

---

## Alternative: get the installer without installing anything

If installing Flutter, Android Studio and Visual Studio (steps 1–5, several
GB total) is more than you want to do on this PC, this zip also includes a
free GitHub Actions setup that does the entire build for you, on GitHub's
own computer, for free. You only need a web browser.

1. Create a free account at https://github.com if you don't have one.
2. Create a new repository (top-right **+** → **New repository**). Private
   is fine.
3. Open it, click **Add file → Upload files**, and drag in **everything**
   from this unzipped folder — `README.md`, `lib`, `pubspec.yaml`,
   `android`, `installer`, and the hidden `.github` folder — then click
   **Commit changes**. (If your file browser hides folders starting with a
   dot, drag the `.github` folder in as a second, separate upload — most
   browsers show it even when the OS hides it elsewhere.)
4. Click the **Actions** tab. A run called "Build Ideal Reader" starts
   automatically (click "I understand my workflows, go ahead and enable
   them" if asked). It takes roughly 10–15 minutes.
5. When it shows a green check, click into the run, scroll to
   **Artifacts**, and download `ideal-reader-windows-installer` (unzip it
   to get `IdealReaderSetup.exe`) and `ideal-reader-android-apk`.

This is my best-effort setup using well-established free tools, but I
could not run it myself to confirm it end to end — if a run shows a red X,
open the failed step and send me the error text so I can fix it.

---

## How it works

- **Add a book**: tap **+**, pick a `.txt`, `.epub`, `.docx`, `.pdf`, `.jpg`,
  or `.png` file. The app copies it into its own storage so it keeps
  working even if you move the original.
- **Reading**: the book's text is split into readable sections. Play/Pause/
  Next/Previous move through them, and your place is saved automatically so
  you can close the app and pick up later.
- **Voice settings** (the mic icon): adjust speed, pitch, and pick from
  whatever voices are installed on your Windows or Android system.
- **Voice quality**: this uses each device's built-in speech engine, so
  quality depends on what's installed:
  - *Windows*: Settings → Time & Language → Speech → add voices.
  - *Android*: Settings → System → Languages & input → Text-to-speech
    output → install voice data (Google's TTS engine has good free voices).

## Reading with the screen locked or the app minimized

**Android** — reading continues with the screen locked, with the app in the
background, or with another app in front. A "Reading aloud" notification
appears with previous / pause / next / stop buttons (also on the lock
screen), and headset or Bluetooth buttons work too. This is done with
Android's standard media "foreground service", which is why the main
`AndroidManifest.xml` has to be replaced in step 2.
- The first time you press play on Android 13 or newer, the phone asks
  whether to show notifications. Choose **Allow**. If you refuse, reading
  still continues; you just won't see the controls.
- Some phones stop background apps aggressively to save battery (common on
  Tecno, Infinix, itel, Xiaomi and some Samsung models). If reading stops
  after a while with the screen locked: open a book, tap the sliders icon
  at the top, tap **Allow background reading** and accept. Also open
  phone Settings, Apps, Ideal Reader, Battery, and choose **Unrestricted**
  (or "Don't optimize"). On Tecno/Infinix/itel phones, also allow
  auto-start and lock the app in the recent-apps screen. Menu names
  differ between phones.
- To leave the book while it keeps reading, press the **Home** button or
  lock the screen. The **Back** button closes the book and stops reading.

**Windows** — minimize the window and reading continues. Windows does not
suspend minimized desktop apps, and an app that is playing sound is not
slowed down. Closing the window stops reading. Locking the PC (Win+L)
keeps it going; if the PC goes to sleep, reading stops with it (Settings,
System, Power lets you change when that happens).

I could not run either platform on a real device from here, so please test
both after building: start a book, minimize or lock, wait a few minutes,
and check that it is still reading. If Android reading does not continue,
first check that you replaced the main `AndroidManifest.xml` exactly as in
step 2; without it the app still works normally but reads only while it
is on screen.

## Working fully offline

Nothing in this app's code makes a network request. Reading, adding
books, and every text extractor (txt, epub, docx, pdf, image text
recognition) work only on files already on the device. Here is how that
is enforced and how you can prove it yourself:

**Android** — `android/app/src/release/AndroidManifest.xml` (included in
this zip) removes the `INTERNET` permission from the release app, even if
a library tried to add it. Without that permission, Android itself stops
the app from opening any network connection. This only affects
`flutter build apk --release`; `flutter run` for testing keeps its
permission so hot reload still works.
- Check it: after building, run `aapt dump permissions app-release.apk`
  (the `aapt` tool is in the Android SDK's `build-tools` folder). The list
  should not contain `android.permission.INTERNET`.
- Or simply switch the phone to **airplane mode** and use every feature.

**Windows** — Windows has no per-app permission like Android, but the app
has no network code. If you want a hard block anyway, add a firewall rule
once (PowerShell opened as Administrator, using the real path of your
copy of the app):
```
New-NetFirewallRule -DisplayName "Ideal Reader - block internet" -Direction Outbound -Program "C:\Path\To\ideal_reader.exe" -Action Block
```
Or just switch Wi-Fi off / unplug the cable and use the app.

**Two things that happen outside the app, through your device's own
settings:**
- **Voices**: reading aloud uses voices already installed on the device.
  Installing a new voice is a one-time download done by Windows or Android
  itself, not by this app. After that it works offline. On Android the
  app's voice list hides any voice Android marks as "needs internet".
- **Windows image reading** needs a text-recognition language installed in
  Windows. English and most major languages already are; adding another
  one is a one-time Windows download.

One more honest detail: the background-reading library (`audio_service`)
contains code that could download album art from a web address. This app
never gives it one, so it never runs, and on Android the removed internet
permission would block it anyway.

Also worth knowing: if you pick a file from a cloud location in the file
picker (Google Drive, OneDrive), fetching that file needs internet at that
moment, done by that other app. Files already on the device need none.

**Android image reading** uses Google's ML Kit plugin, which ships its
Latin-script model inside the app package, so no download is needed. The
airplane-mode test above is the way to confirm it on your own phone. If
image reading ever crashes on the release APK but worked in `flutter run`,
delete `android/app/src/release/AndroidManifest.xml`, rebuild, and let me
know; the app's own code still never uses the network.

## If a build step errors

Flutter's plugin ecosystem moves fast, so a version pinned in
`pubspec.yaml` can occasionally clash with a very new Android/Visual
Studio toolchain. If `flutter pub get` or a build fails:
```
flutter pub upgrade
flutter clean
flutter pub get
```
and try the build again. If `flutter pub get` complains that a package
needs a newer Dart/Flutter version, run `flutter upgrade` first. If the
Android build complains about `compileSdk`, open `android/app/build.gradle`
(or `build.gradle.kts`) and set `compileSdk` to 35 or higher. If a
specific plugin is the problem, its pub.dev page (e.g.
pub.dev/packages/file_picker) lists current known issues and fixes.

## Notes on the newer formats

**Word documents (.docx)** — read directly, no extra setup. Only the
modern `.docx` format is supported, not the old binary `.doc` format from
Word 2003 and earlier. If you have a `.doc` file, open it in Word (or the
free LibreOffice) and use "Save As → .docx" first, then import that.

**PDF (.pdf)** — text is pulled from the PDF's own text layer (the normal
case for anything exported from Word, Google Docs, a phone's "Save as
PDF", etc.), no extra setup needed. A PDF that's really just photographed
or scanned pages with no text layer will come back empty — there's no OCR
fallback for that case yet.
- This uses the `syncfusion_flutter_pdf` package. It's free to use (no
  license key needed, no cost) but it isn't an open-source license — worth
  a glance at Syncfusion's terms if that matters to you: https://www.syncfusion.com/sales/communitylicense

**Images (.jpg/.png)** — the app reads the text out of the picture
on-device, with no internet:
- **Android**: Google's ML Kit text recognition (Latin scripts, such as
  English).
- **Windows**: the text recognition built into Windows 10/11, called
  through the PowerShell that ships with Windows. I could not run this
  Windows route myself, so treat it as best-effort. If it fails, the app
  says why and suggests the manual route: open the image in **Photos**
  (or Snipping Tool), use **"Text actions"** to copy the text, paste it
  into a `.txt` file, and import that.
- A clear, straight-on, well-lit picture gives far better results than a
  blurry or tilted one.

## Known limitations

- **Pause** stops the voice; pressing play again re-reads the current
  section (a paragraph or so) from its start.
- **Background reading** depends on the phone's battery settings (see
  "Reading with the screen locked or the app minimized"). Some phone
  brands need extra steps.
- **Scanned PDFs** (pages that are only pictures) have no text to read;
  import the pages as images instead.
- **Old `.doc`** files must be re-saved as `.docx` first.
- **Image text recognition** on Android covers Latin scripts only; on
  Windows it depends on the languages installed in Windows.
- **Voice quality and languages** depend on the voices installed on the
  device.
- **Windows SmartScreen**: since `IdealReaderSetup.exe` isn't digitally
  signed (a paid certificate, typically $100+/year, is needed for that),
  Windows may show a blue "Windows protected your PC" screen the first
  time someone runs it. Click **More info**, then **Run anyway**. This is
  normal for independently-built free software and goes away once enough
  people have run it without issue.
