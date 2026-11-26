# MIOUI

Reusable SwiftUI components for the MIO apps. Each one is here because more than one screen or app
needs it, and none of them knows about a particular app or data model.

## Requirements

- iOS 17 or macOS 14
- Swift 6

## Installation

Add the package to your project and link the `MIOUI` product:

```swift
dependencies: [
    .package(url: "https://github.com/miolabs/MIOUI.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: ["MIOUI"]),
]
```

In an Xcode workspace that keeps the MIO libraries side by side, add the `MIOUI` folder to the
workspace and link the `MIOUI` product to the app target.

## Components

- `MIOPageStack` (macOS): a stack of pages that slide horizontally, driven by a path.

## Documentation

Each component is documented with DocC, with usage examples. In Xcode, choose
Product > Build Documentation, or Option-click a component's name in your code.
