# OpenWisprFlow

OpenWisprFlow is a native macOS menu bar dictation app for voice-driven coding. It lets you start speaking with a global hotkey, transcribes your voice with Apple's built-in Speech framework, formats common coding phrases, and pastes the result into your active editor.

## What It Uses

- Swift and SwiftUI for the macOS app UI
- Apple's Speech framework via `SFSpeechRecognizer`
- `AVAudioEngine` for live microphone audio capture
- Carbon hotkeys for the global `Control + Option + Space` shortcut
- AppKit pasteboard and accessibility events for auto-paste
- macOS permissions for Microphone, Speech Recognition, and Accessibility

The app originally tested Apple's newer macOS 26 `SpeechAnalyzer`/`DictationTranscriber` path, but that framework path crashed inside Apple's `SpeechRecognizerWorker.preRunRecognition()` on this machine. OpenWisprFlow now uses the stable `SFSpeechRecognizer` live-audio API from the same Apple Speech framework.

## Requirements

- macOS 14.0 or newer
- Xcode 26.4 or newer recommended
- A microphone
- Git, if you want to clone and build from source

## Install From Source

Clone the repo:

```sh
git clone https://github.com/akashiitd/openwisprflow.git
cd openwisprflow
```

Build the app:

```sh
xcodebuild -project OpenWisprFlow.xcodeproj \
  -scheme OpenWisprFlow \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/OpenWisprFlowDerivedData \
  build
```

Run it:

```sh
open /private/tmp/OpenWisprFlowDerivedData/Build/Products/Debug/OpenWisprFlow.app
```

You can also open the project in Xcode and press Run:

```sh
open OpenWisprFlow.xcodeproj
```

## First Launch Permissions

macOS will ask for permissions when dictation starts:

- Microphone: required to record your voice
- Speech Recognition: required for Apple Speech transcription
- Accessibility: required only if you want OpenWisprFlow to paste into the active editor automatically

If auto-paste does not work, enable it manually:

```text
System Settings -> Privacy & Security -> Accessibility -> OpenWisprFlow
```

## Usage

1. Launch `OpenWisprFlow.app`.
2. Click the microphone icon in the macOS menu bar.
3. Choose `Show OpenWisprFlow`.
4. Press `Control + Option + Space` to start listening.
5. Press `Control + Option + Space` again to stop and paste.

You can also use the `Start`, `Stop`, `Paste`, and `Copy` buttons in the app window.

## Coding Phrases

With `Code phrases` enabled, OpenWisprFlow converts spoken phrases into coding-friendly text:

```text
new line -> line break
open paren -> (
close paren -> )
open brace -> {
close brace -> }
double quote -> "
single quote -> '
underscore -> _
fat arrow -> =>
arrow -> ->
```

The formatter is intentionally small and predictable so it does not rewrite normal dictation too aggressively.

## Troubleshooting

If the app appears to do nothing after launching, check the macOS menu bar for the microphone icon. OpenWisprFlow is a menu bar app and does not show a Dock icon.

If dictation does not start, confirm permissions in:

```text
System Settings -> Privacy & Security -> Microphone
System Settings -> Privacy & Security -> Speech Recognition
```

If auto-paste does not work, use the app's `Copy` button or grant Accessibility permission.

If you rebuild often while testing permissions, macOS may keep old permission records for the same bundle identifier. Quit the app, rebuild, and launch the newly built app from:

```text
/private/tmp/OpenWisprFlowDerivedData/Build/Products/Debug/OpenWisprFlow.app
```
