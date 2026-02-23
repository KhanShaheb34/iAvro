# iAvro Modernization Plan

This document defines a practical 3-phase migration path to keep iAvro usable on modern Apple Silicon macOS releases.

## Goals

- Build and run natively on Apple Silicon (`arm64`).
- Keep Bengali typing behavior stable while modernizing tooling.
- Establish a maintainable release path for future macOS updates.

## Phase 1: Build and Runtime Compatibility (Immediate)

### Scope

- Make the project build with current Xcode + modern macOS SDK.
- Remove brittle legacy dependency wiring that blocks builds.
- Keep app behavior/functionality unchanged where possible.
- Validate app launch and basic IMK runtime behavior on an Apple Silicon Mac.

### Work items

- Remove legacy CocoaPods coupling from project/workspace if dependencies are replaced in-repo.
- Replace `RegexKitLite` usages with Foundation regex compatibility helpers.
- Replace `FMDB` usages with `sqlite3` directly for current dictionary loading/query paths.
- Update project settings:
  - modern `MACOSX_DEPLOYMENT_TARGET`
  - clean stale build flags
  - normalize signing defaults for local development
- Build with `xcodebuild` for `arm64`.

### Exit criteria

- `xcodebuild` succeeds on Apple Silicon.
- App can be installed to `~/Library/Input Methods` and enabled in System Settings.
- Manual smoke test confirms: composition, candidate list, selection/commit, preferences window.

### Estimated effort

- 3-7 days (including manual QA across target macOS versions and common apps).

## Phase 2: Stabilization and Safety

### Scope

- Reduce regressions and make behavior predictable across host apps.
- Add reproducible checks around transliteration/candidate logic.

### Work items

- Add focused tests for parser/suggestion/database logic.
- Add regression fixtures for core Bengali transliteration patterns.
- Validate candidate panel behavior against modern InputMethodKit edge cases.
- Profile and reduce latency under fast typing bursts (parser + candidate generation hot path).
- Improve logging/diagnostics for runtime failures.
- Document supported macOS versions and known limitations.

### Exit criteria

- Deterministic tests for parser/suggestion core paths.
- Reproducible manual test checklist for IME behaviors.
- Clear compatibility matrix and release checklist.

### Estimated effort

- 3-5 days.

## Phase 3: Long-Term Modernization

### Scope

- Raise maintainability and release quality beyond immediate compatibility.

### Work items

- Optional ARC migration (or selective modernization) to reduce memory-risk patterns.
- Evaluate selective Swift adoption where it improves clarity/testability.
- Replace remaining legacy project conventions with modern Xcode defaults.
- Add CI build checks and release automation.
- Prepare hardened runtime/notarization/distribution pipeline.

### Exit criteria

- Automated build/release workflow.
- Maintainer-friendly architecture and docs.
- Reliable signed/notarized distribution process.

### Estimated effort

- +2-6 weeks depending on refactor depth and release requirements.

## Current status

- **Phase 1 is complete** (build + install + manual typing validation on Apple Silicon).
- **Phase 2 is now in progress**, starting with fast-typing latency/performance.

## Phase 1 progress (2026-02-23)

- Completed:
  - Removed hard dependency on CocoaPods-generated project wiring.
  - Replaced `RegexKitLite` calls with local Foundation-based regex helpers.
  - Replaced `FMDB` query path with direct `sqlite3` access.
  - Updated Xcode project settings for modern SDK + Apple Silicon builds.
  - Verified `xcodebuild` succeeds for `arm64` and produces a native arm64 binary.
  - Renamed app/target/scheme/bundle identity to `Avro Silicon` for side-by-side install with legacy Avro.
  - Confirmed install and activation from `~/Library/Input Methods` on Apple Silicon.
  - Manual smoke test passed in real typing usage (composition, candidate list, selection/commit, preferences).
- Known follow-up (Phase 2):
  - Typing very fast can introduce noticeable lag (existing issue from legacy version; now tracked for profiling + optimization).

## Phase 2 progress (2026-02-23)

- Completed:
  - Added regex compilation caching in `NSString+Levenshtein` to avoid recompiling identical patterns across hot paths.
  - Optimized dictionary suggestion sorting by precomputing Levenshtein distances once per candidate before sorting.
  - Added debug-only runtime timing instrumentation across:
    - `AvroKeyboardController` (`inputText`, candidate generation, panel update)
    - `Suggestion` (parse/cache/dictionary/suffix stages)
    - `Database` (`find` regex compile + scan stages)
  - Added runtime toggle key for perf logs: `EnablePerfLog` in user defaults.
  - Verified project still builds successfully with `xcodebuild` using scheme `Avro Silicon`.
- Next:
  - Capture baseline latency under burst typing and target highest-cost stages.
  - Add focused tests/fixtures for parser/suggestion/database regressions.
