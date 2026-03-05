# Avro Silicon

A native macOS Bengali (Bangla) phonetic input method for Apple Silicon. Type in English and get Bengali text — just like the original [Avro Keyboard](https://www.omicronlab.com/avro-keyboard.html), but modernized for current macOS.

## Why This Exists

The original iAvro was built for Intel Macs and will stop working in upcoming macOS versions. Avro Silicon is a from-source modernization that:

- Builds and runs natively on Apple Silicon (arm64)
- Removes all legacy dependencies (CocoaPods, RegexKitLite, FMDB)
- Uses only system frameworks (Foundation, InputMethodKit, sqlite3)
- Preserves the exact same phonetic typing behavior

## Features

- **Phonetic Bengali input** — type `ami` to get `আমি`, `bangla` to get `বাংলা`
- **Smart candidate suggestions** — dictionary-backed suggestions sorted by edit distance
- **Suffix-aware completion** — intelligently handles Bengali suffixes and conjuncts
- **AutoCorrect / emoticon support** — shorthand expansions
- **User learning** — remembers your preferred candidates across sessions
- **Candidate panel** — configurable single-column or single-row layout
- **Lightweight** — no external dependencies, fast startup

## Installation

### From Release

1. Download the latest `.tar.gz` from the [Releases](../../releases) page.
2. Extract to get `Avro Silicon.app`.
3. Copy it to `~/Library/Input Methods/`.
4. Open **System Settings > Keyboard > Input Sources** and add **Avro Silicon** under Bangla.

### From Source

```bash
# Build
xcodebuild \
  -project AvroKeyboard.xcodeproj \
  -scheme "Avro Silicon" \
  -configuration Release \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  build

# Install
scripts/install.sh
```

If the input source doesn't appear, run:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Library/Input\ Methods/Avro\ Silicon.app
killall TextInputMenuAgent
```

## Architecture

```
main.m                    — App entry point, IMKServer setup
AvroKeyboardController    — InputMethodKit controller (composition, candidates, key handling)
AvroParser                — Phonetic-to-Bengali transliteration engine (data.json rules)
RegexParser               — Regex pattern generator for dictionary matching (regex.json rules)
Database                  — SQLite3 dictionary lookup with caching and literal fast-path
Suggestion                — Composite suggestion pipeline (parser + dictionary + autocorrect + suffix)
CacheManager              — Persistent weight cache + in-session phonetic/suffix caches
AutoCorrect               — Emoticon and shorthand expansion (autodict.plist)
NSString+Levenshtein      — Edit distance calculation + regex helpers
```

Data files: `data.json` (transliteration rules), `regex.json` (pattern rules), `database.db3` (word dictionary), `autodict.plist` (autocorrect entries).

## Development

### Run tests

```bash
scripts/run_regression_tests.sh
```

### Performance profiling (debug builds)

```bash
defaults write com.omicronlab.inputmethod.AvroSilicon EnablePerfLog -bool true
# Use the IME, then:
scripts/perf_report.sh 10m
```

### CI/CD

- **CI**: `.github/workflows/ci.yml` — runs regression tests and builds on every push/PR
- **Release**: `.github/workflows/release.yml` — builds and publishes on `v*` tags

### Creating a release

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

The release workflow publishes `.tar.gz` and `.sha256` to GitHub Releases automatically.

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository and clone it.
2. Build the project (see "From Source" above).
3. Run the regression tests to make sure everything passes.
4. Make your changes and add test cases for new behavior.
5. Submit a pull request.

### Areas where help is needed

- **Code signing and notarization** — if you have an Apple Developer account, you can help sign and distribute the app
- **Testing on different macOS versions** — especially older versions (macOS 11-13)
- **Expanding the dictionary** — adding more Bengali words to `database.db3`
- **UI improvements** — modernizing the preferences panel

### Code conventions

- Objective-C with manual retain/release (no ARC)
- Singleton pattern for shared instances (AvroParser, Database, Suggestion, etc.)
- Preference keys centralized in `AvroPreferenceKeys.h`
- Resource path resolution via `AvroResourcePath.h`
- Debug-only performance instrumentation behind `#ifdef DEBUG`

## Troubleshooting

**Input source not visible:**
- Confirm app path is `~/Library/Input Methods/Avro Silicon.app`
- Run the `lsregister` + `killall TextInputMenuAgent` commands above

**No perf data in report:**
- Ensure `EnablePerfLog` is set to `true`
- Generate typing activity, then run `scripts/perf_report.sh 5m`

## License

This project is based on [iAvro](https://github.com/nicefiction/iAvro) by OmicronLab.

## Credits

- Original iAvro by [Rifat Nabi](https://github.com/nicefiction) / OmicronLab
- Apple Silicon modernization and improvements by the open-source community
