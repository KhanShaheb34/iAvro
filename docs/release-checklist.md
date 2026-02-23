# Avro Silicon Phase 2 Checklist

## Compatibility Matrix

| Item | Status | Notes |
|---|---|---|
| Apple Silicon (`arm64`) runtime | Verified | Manual install/use on Apple Silicon host (2026-02-23). |
| Intel (`x86_64`) runtime | Built | Universal binary is produced; no dedicated Intel manual run in this phase. |
| Minimum deployment target | Configured | `macOS 11.0` project target. |
| Input Method registration | Verified | `~/Library/Input Methods/Avro Silicon.app` + LaunchServices refresh flow works. |

## Automated Regression Checks

Run from repo root:

```bash
scripts/run_regression_tests.sh
```

The suite validates fixture-driven parser/database/suggestion behavior from:

- `tests/fixtures/regression_cases.json`

## Manual IME Checklist (Per Release)

1. Build and install the app bundle to `~/Library/Input Methods/`.
2. Refresh registration/processes:
   - `lsregister -f ~/Library/Input\ Methods/Avro\ Silicon.app`
   - `killall TextInputMenuAgent`
3. In System Settings > Keyboard > Input Sources:
   - Confirm `Avro Silicon` appears and can be selected.
4. In at least 3 host apps (for example TextEdit, Notes, Terminal/VS Code):
   - Compose text continuously.
   - Verify candidate list appears and updates.
   - Verify `Space`, `Enter`, arrow-key candidate selection, and backspace behavior.
   - Verify punctuation/prefix/suffix handling around composition boundaries.
5. Toggle dictionary preference and confirm behavior is stable in both modes.
6. If performance instrumentation is enabled (`EnablePerfLog=1`), sample logs and check for new high-latency spikes.

## Perf Log Commands (Optional)

```bash
# recent performance entries
log show --last 10m --style compact --predicate 'eventMessage CONTAINS "[AvroPerf]"'

# summarized perf report
scripts/perf_report.sh 10m

# enable logs
defaults write com.omicronlab.inputmethod.AvroSilicon EnablePerfLog -bool true
```

## Release Gate

Ship only if:

1. `scripts/run_regression_tests.sh` passes.
2. `xcodebuild` succeeds for `Avro Silicon`.
3. Manual IME checklist passes on the current Apple Silicon macOS version.
