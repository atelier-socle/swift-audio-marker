# ``AudioMarker/AudioValidator``

Validates audio metadata and chapters against configurable rules.

## Overview

`AudioValidator` runs a set of ``ValidationRule`` conformances against an ``AudioFileInfo`` and returns a ``ValidationResult``. Use the default rules or provide your own.

```swift
let validator = AudioValidator()
let result = validator.validate(info)

if !result.isValid {
    for error in result.errors {
        print("Error: \(error.message)")
    }
}
```

Create a validator with custom rules:

```swift
let validator = AudioValidator(rules: [
    ChapterOrderRule(),
    ChapterOverlapRule(),
    MyCustomRule()
])
```

## Topics

### Creating

- ``init()``
- ``init(rules:)``

### Validation

- ``validate(_:)``

### Configuration

- ``rules``
- ``defaultRules``
