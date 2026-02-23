# Avro Silicon

Avro Silicon is a modernized macOS Bengali input method based on iAvro, updated to run reliably on Apple Silicon while preserving the original typing behavior.

## Current Status

- Phase 1: complete (modern build/runtime compatibility)
- Phase 2: complete (regression checks, perf instrumentation, release checklist)
- Phase 3: in progress (CI + release automation started)

See details in:

- `docs/migration-plan.md`
- `docs/release-checklist.md`

## Installation (From Release)

1. Download the latest release artifact (`.tar.gz`) from this repository’s Releases page.
2. Extract it to get `Avro Silicon.app`.
3. Copy the app to `~/Library/Input Methods/`.
4. Open System Settings > Keyboard > Input Sources and add `Avro Silicon` under Bangla.

If the new app does not appear immediately, run:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Library/Input\ Methods/Avro\ Silicon.app
killall TextInputMenuAgent
```

## Build (Local)

Debug build:

```bash
xcodebuild \
  -project AvroKeyboard.xcodeproj \
  -scheme "Avro Silicon" \
  -configuration Debug \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Release build:

```bash
xcodebuild \
  -project AvroKeyboard.xcodeproj \
  -scheme "Avro Silicon" \
  -configuration Release \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Development Checks

Run fixture-based regression tests:

```bash
scripts/run_regression_tests.sh
```

Summarize recent performance logs:

```bash
scripts/perf_report.sh 10m
```

Enable perf logs (debug builds):

```bash
defaults write com.omicronlab.inputmethod.AvroSilicon EnablePerfLog -bool true
```

## CI and Release Automation

- CI workflow: `.github/workflows/ci.yml`
  - Runs regression tests
  - Runs macOS build

- Release workflow: `.github/workflows/release.yml`
  - Triggers on tags matching `v*`
  - Builds `Release` app bundle
  - Publishes `Avro-Silicon-<tag>.tar.gz` and `.sha256` to GitHub Releases

## Creating a Release

1. Ensure local checks pass.
2. Push your commits.
3. Create and push a version tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

The release workflow will publish artifacts automatically.

## Troubleshooting

No perf data in report:

- Ensure `EnablePerfLog` is enabled.
- Generate typing activity, then run `scripts/perf_report.sh 5m`.

Input source not visible:

- Confirm app path is `~/Library/Input Methods/Avro Silicon.app`.
- Run `lsregister` + `killall TextInputMenuAgent` commands above.
