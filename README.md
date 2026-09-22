<div align="center">
  <img src="./app_icons/icon.png" width="160" alt="music Icon"/>

  <br />

  # music for macOS

  _A minimalist, lightweight, and native music player for local libraries and self-hosted Navidrome._

  [![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
  [![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift)](https://swift.org)
  [![Release](https://img.shields.io/github/v/release/eidnoat/music4mac?style=flat-square&color=blue)](https://github.com/eidnoat/music4mac/releases)
  [![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

</div>

---

## 💡 Why This Project Exists

This is a **purely personal project** born out of my own everyday frustration.

For years, I loved the **Library** feature in Apple Music—the way it organizes an album collection is second to none. But over time, the friction became unbearable:
- **Disappearing Songs & License Issues**: Tracks would frequently vanish or turn gray without warning, an issue especially rampant in the mainland China region. Eventually, I found myself hunting down audio files and uploading them manually, treating Apple Music essentially as a paid personal music locker.
- **Import Only, No Export**: As a music drive, it only allows importing, never exporting. I never felt true ownership or control over my own library.
- **Tightly Coupled to App Store Accounts**: I occasionally need to switch App Store regions to install different applications. But in Apple Music, changing your App Store Apple ID immediately wipes or disables your music library and offline downloads.

Fed up with these limitations, I began searching for alternatives, prioritizing **open-source** and **self-hosted** solutions, which eventually led me to **Navidrome**.

On mobile (iOS), I quickly found great third-party clients. On macOS, however, I searched everywhere and couldn't find anything **lightweight, clean, and distraction-free**:
- I simply wanted to listen to my own library. Most existing clients were packed with extra bells and whistles I never used.
- Nearly all of them were built on cross-platform frameworks like Electron. After running for a while, memory usage would easily creep toward 1 GB—far too bloated and heavy for a music player.

Out of necessity, I spent a single day building this native macOS app with **Swift + SwiftUI**. I am by no means a macOS client development expert; **over 80% of the code was written by AI**, while I focused on defining requirements, steering architecture, and testing edge cases.

---

## 🖼️ Screenshots

<div align="center">
  <img src="./docs/images/image_3.png" width="100%" alt="music Navidrome Sync & Mini Player" />
  <p><em>Navidrome server integration and compact floating Mini Player</em></p>
  <br />
  <img src="./docs/images/image_2.png" width="100%" alt="music Lyrics & Controls" />
  <p><em>Synced LRC lyrics playback with native macOS bottom player bar</em></p>
  <br />
  <img src="./docs/images/image_1.png" width="100%" alt="music Main Interface" />
  <p><em>Main Library: Clean NavigationSplitView for browsing songs, albums, and artists</em></p>
</div>

---

## 🎯 Design & Trade-offs

This player is not intended to please everyone. Its boundaries are deliberately narrow:

- **Strictly Local & Navidrome**: It only plays local audio files and connects to self-hosted Navidrome (Subsonic) servers. There are no commercial streaming recommendations or discovery features. It is **not** suitable for anyone looking for online streaming services.
- **Intentionally Minimal**: The UI and features are kept as simple as possible, retaining only what is strictly necessary to enjoy listening to music.
- **Extremely Low Resource Footprint**: Free of cross-platform overhead, on my library of **500+ songs** running on a **MacBook Pro (M3 Pro)**, memory consumption consistently stays **below 100 MB** during extended playback, with near-zero CPU impact.

---

## ⚠️ Compatibility & Disclaimer

- **Personal Experiment**: This app was built solely to suit my personal preferences and daily listening workflow.
- **Testing Scope**: The project has not undergone comprehensive usability or regression testing across diverse devices and legacy OS versions. It is **only guaranteed to run properly on macOS 15 (Sequoia) and later**.

---

## 🚀 Download & Installation

### Option 1: Pre-built Binary (Recommended)
Download the latest `music.zip` from the [**Releases**](https://github.com/eidnoat/music4mac/releases) page:
1. Download **`music.zip`** from the latest release.
2. Unzip and drag **`music.app`** to your `/Applications` folder.
3. **First-time launch (Gatekeeper)**: Since this is an unnotarized personal open-source build, macOS will prompt you on first launch. Right-click (or Control-click) `music.app`, select **Open**, and click **Open** in the dialog.

> [!TIP]
> You can also grab bleeding-edge automated builds from the [**Actions**](https://github.com/eidnoat/music4mac/actions) tab under the latest run's Artifacts.

---

## 🛠️ Building from Source

Requires macOS 15.0+ with Xcode 16+ or Swift 6.0+ Command Line Tools.

### Quick Build & Run
```bash
# 1. Clone repository
git clone git@github.com:eidnoat/music4mac.git
cd music4mac

# 2. Run unit tests
swift test

# 3. Run in debug mode directly
swift run music
```

### Packaging `.app` Bundle & `.zip`
The repository includes an automated packaging script (`build_app.sh`):
```bash
chmod +x ./build_app.sh
./build_app.sh
```
This script will:
1. Compile the release binary (`swift build -c release`).
2. Construct the macOS `music.app` bundle hierarchy.
3. Compile `AppIcon.xcassets` into macOS native icons with `actool`.
4. Apply entitlements and ad-hoc sign the bundle (`codesign`).
5. Export production-ready `dist/music.app` and `music.zip` preserving file attributes and permissions.

Or open the project directly in Xcode:
```bash
open Package.swift
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
