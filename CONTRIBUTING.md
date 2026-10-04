# Contributing / Contribuer

Issues and pull requests in English or French are welcome. This is an independent iOS companion, with no affiliation with VIA Rail Canada.

## Development

Use Xcode 26.1 or later (Swift 6.2) and iOS 26. Open `ios/ReveilVIA.xcodeproj`; no API key or backend is needed. For a physical device, select your own signing team for both the app and Live Activity extension. Never commit signing credentials or provisioning profiles.

`ios/project.yml` is the project structure source. After changing it, run `xcodegen generate --spec ios/project.yml` and include the generated project changes. Keep `ios/Package.resolved` committed when updating dependencies.

Before submitting:

```sh
swift test --package-path ios
xcodebuild -project ios/ReveilVIA.xcodeproj -scheme ReveilVIA \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Tests run offline by default. Only enable `VIA_LIVE_SMOKE=1` deliberately: it contacts VIA and depends on changing data. Keep regression fixtures synthetic, preserve both English and French, and explain how behavior changes were validated. Simulator results do not establish physical alarm behavior.

## Reporting bugs

Include the app/Xcode/iOS version, reproducible steps, expected and actual behavior. For train-data problems, include train number, service date and station time zone. Remove personal details from screenshots and logs. Report security vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Scope and assets

Preserve conservative alarm behavior: stale or conflicting data must not silently replace a verified alarm. Do not claim continuous background updates. Do not add external imagery, datasets or dependencies without documenting their provenance and redistribution terms. The code license does not license VIA data or trademarks. See [the README](README.md).
