# Validation

Validate audio metadata and chapters with built-in and custom rules.

## Overview

``AudioValidator`` runs a set of ``ValidationRule`` conformances against an ``AudioFileInfo`` and returns a ``ValidationResult`` with categorized issues. The engine can also auto-validate before every write.

### Built-in Rules

AudioMarker ships with 10 validation rules:

| Rule | Description |
|------|-------------|
| ``ChapterOrderRule`` | Chapters must be sorted by start time |
| ``ChapterOverlapRule`` | Chapters must not have overlapping time ranges |
| ``ChapterTitleRule`` | Every chapter must have a non-empty title |
| ``ChapterBoundsRule`` | Chapter start must be before end |
| ``ChapterNonNegativeRule`` | Chapter times must not be negative |
| ``MetadataTitleRule`` | Title should not be empty |
| ``MetadataYearRule`` | Year must be a valid positive number |
| ``ArtworkFormatRule`` | Artwork must be JPEG or PNG |
| ``LanguageCodeRule`` | Language must be a 3-letter ISO 639-2 code |
| ``RatingRangeRule`` | Rating must be in the valid range |

### Running Validation

```swift
let validator = AudioValidator()

let info = AudioFileInfo(
    metadata: AudioMetadata(title: "Valid Song", artist: "Artist"),
    chapters: ChapterList([
        Chapter(start: .zero, title: "Intro", end: .seconds(60)),
        Chapter(start: .seconds(60), title: "Verse", end: .seconds(120))
    ]),
    duration: .seconds(120)
)

let result = validator.validate(info)
result.isValid    // true
result.errors     // []
result.warnings   // []
```

### Severity Levels

``ValidationSeverity`` has two levels:

- **`.error`** — The data is invalid and should not be written. Causes `isValid` to return `false`.
- **`.warning`** — The data is technically valid but may cause issues. Does not fail validation.

```swift
let result = validator.validate(problematicInfo)

// Filter by severity
let errors = result.errors     // [ValidationIssue] with .error severity
let warnings = result.warnings // [ValidationIssue] with .warning severity

// Each issue has context
let issue = result.issues[0]
issue.severity  // .error or .warning
issue.message   // Human-readable description
issue.context   // Optional additional context
```

### Engine Integration

``AudioMarkerEngine`` integrates validation directly:

```swift
let engine = AudioMarkerEngine()

// Manual validation
let result = engine.validate(info)

// Throws AudioMarkerError.validationFailed if invalid
try engine.validateOrThrow(info)
```

When ``Configuration/validateBeforeWriting`` is `true` (default), the engine automatically validates before every write:

```swift
let config = Configuration(validateBeforeWriting: true)
let engine = AudioMarkerEngine(configuration: config)

// This throws if the data is invalid
try engine.write(info, to: fileURL)
```

### Custom Rules

Create domain-specific rules by conforming to ``ValidationRule``:

```swift
struct GenreRequiredRule: ValidationRule {
    let name = "Genre Required"

    func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        if info.metadata.genre == nil || info.metadata.genre?.isEmpty == true {
            return [
                ValidationIssue(
                    severity: .warning,
                    message: "Genre is recommended for discoverability.")
            ]
        }
        return []
    }
}

// Use custom rules
let validator = AudioValidator(rules: [GenreRequiredRule()])
let result = validator.validate(info)
// result.isValid == true (warnings don't fail)
// result.warnings[0].message.contains("Genre")
```

You can combine built-in and custom rules:

```swift
let validator = AudioValidator(
    rules: AudioValidator.defaultRules + [GenreRequiredRule()]
)
```

## Next Steps

- <doc:ReadingAndWriting> — Metadata read/write workflows
- <doc:BatchProcessing> — Validate multiple files in parallel
