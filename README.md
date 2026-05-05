<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/Build-XcodeGen-purple?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
</p>

# 🎬 FrameForge

**A professional-grade video editor built entirely in SwiftUI.** FrameForge brings desktop-class editing tools to iOS — multi-track timeline, real-time filters, LUT grading, chroma key, motion tracking, AI captions, and more.

---

## ✨ Features

### 🎞️ Core Editing
- **Multi-track timeline** — Drag, trim, split, duplicate, and reorder clips
- **Real-time preview** — Pinch-to-zoom, rotate, and pan canvas
- **Undo/Redo** — Full history stack with configurable depth
- **Auto-save** — Projects persist automatically via SwiftData
- **Keyboard shortcuts** — Siri Shortcuts integration via AppIntents

### 🎨 Color & Grading
- **30+ built-in filters** — Cinematic, vintage, B&W, and more
- **Color adjustments** — Brightness, contrast, saturation, temperature, sharpness, vignette
- **LUT import** — Load `.cube` and `.3dl` LUT files for professional color grading
- **Chroma key** — Green/blue screen removal with adjustable threshold

### 🎬 Effects & Compositing
- **Background removal** — Vision-powered person segmentation
- **Motion tracking** — Track objects across frames
- **Video stabilization** — Reduce camera shake
- **Noise reduction** — Clean up grainy footage
- **Masking** — Shape and freehand masks
- **Picture-in-Picture** — Overlay multiple video layers
- **Split screen** — Side-by-side comparisons
- **3D text** — SceneKit-powered text overlays

### 🔊 Audio
- **Audio mixer** — Per-track volume + master volume
- **Voiceover recording** — Record directly in the editor
- **Audio browser** — Import audio from Files
- **Beat sync** — Snap cuts to audio beats

### 📝 Text & Captions
- **AI auto-captions** — Speech recognition powered by Apple's Speech framework
- **Custom caption styles** — Presets with font, color, and animation options
- **Text overlays** — Positioned on the canvas with keyframe animation

### 📤 Export & Share
- **Custom resolution** — 720p to 4K
- **Codec selection** — H.264 / HEVC
- **Frame rate** — 24 / 30 / 60 fps
- **Social presets** — Instagram, TikTok, YouTube optimized exports
- **Save to Camera Roll** — Direct PHPhotoLibrary integration

### ☁️ Cloud & Sync
- **iCloud backup** — CloudKit-powered project backup
- **Spotlight indexing** — Projects searchable via iOS Spotlight

### 💰 Monetization
- **In-app purchases** — Pro upgrade via StoreKit 2
- **Tip jar** — Support the developer
- **Google AdMob** — Banner ads for free tier

---

## 🏗️ Architecture

```
FrameForge/
├── AppIntents/          # Siri Shortcuts
├── Engine/              # Core processing
│   ├── MultiLayerCompositor   # AVFoundation composition pipeline
│   ├── CompositionEngine      # Real-time preview rendering
│   ├── MotionTracker          # Vision-based object tracking
│   ├── CaptionEngine          # Speech → text via SFSpeechRecognizer
│   ├── LUTParser              # .cube/.3dl LUT file parsing
│   ├── PluginManager          # CIFilter plugin system
│   └── CloudSyncManager       # CloudKit backup
├── Export/              # Export pipeline (AVAssetExportSession)
├── Models/              # SwiftData models, timeline data
├── Services/            # Analytics, Spotlight indexing
├── Utilities/           # Settings, StoreKit, helpers
├── ViewModels/          # EditorViewModel (MVVM)
└── Views/               # 40+ SwiftUI views
    └── Ads/             # Google AdMob integration
```

**Pattern:** MVVM with `@Observable` (iOS 17)  
**Storage:** SwiftData for projects, `AppStorage` for preferences  
**Composition:** AVFoundation + CoreImage + Vision  

---

## 🚀 Getting Started

### Prerequisites
- **Xcode 15+**
- **iOS 17.0+** device or simulator
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** installed (`brew install xcodegen`)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/Lalit-khatri/FrameForge.git
cd FrameForge

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode
open FrameForge.xcodeproj

# 4. Select your device/simulator and run (⌘R)
```

> **Note:** The `.xcodeproj` is generated and git-ignored. Always run `xcodegen generate` after pulling.

### Configuration

| Key | File | Purpose |
|-----|------|---------|
| `GADApplicationIdentifier` | `Info.plist` | Google AdMob App ID |
| `NSPhotoLibraryUsageDescription` | `Info.plist` | Photo library access |
| `NSMicrophoneUsageDescription` | `Info.plist` | Voiceover recording |
| `NSSpeechRecognitionUsageDescription` | `Info.plist` | AI captions |
| `iCloud container` | `FrameForge.entitlements` | CloudKit backup |

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [Google Mobile Ads SDK](https://github.com/googleads/swift-package-manager-google-mobile-ads) | 13.3.0 | Banner ads (AdMob) |

All other frameworks are Apple first-party: AVFoundation, Vision, CoreImage, Speech, CloudKit, StoreKit, SwiftData, SceneKit, PhotosUI.

---

## 📸 Screenshots

> *Coming soon — build the project and explore!*

---

## 🗺️ Roadmap

- [ ] iPad + macOS Catalyst support
- [ ] Collaborative editing
- [ ] AI-powered smart cuts
- [ ] Plugin marketplace
- [ ] Export to GIF/WebP

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Lalit Khatri** — [@Lalit-khatri](https://github.com/Lalit-khatri)

---

<p align="center">
  Built with ❤️ using SwiftUI
</p>
