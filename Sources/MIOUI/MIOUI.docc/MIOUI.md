# ``MIOUI``

Reusable SwiftUI components for the MIO apps.

## Overview

`MIOUI` holds the views that more than one screen or app needs. None of them knows about a
particular app or data model: each takes plain values, bindings and view builders, so it works with
whatever the app puts in it.

Some components wrap an AppKit or UIKit class that SwiftUI has no equivalent for. Those exist only on
the platform of the class they wrap, and their page says which SwiftUI view to use on the others.

## Topics

### Navigation

Move between levels of content inside one area of a window.

- ``MIOPageStack``
