---
name: eas-testflight-release
description: Prepare, build, submit, and monitor native Expo iOS releases in TestFlight. Use when asked to create an EAS production iOS build, send a build to TestFlight, monitor Apple processing, or fix App Store Connect upload failures such as Invalid Pre-Release Train and CFBundleShortVersionString errors.
---

# EAS TestFlight Release

Release a native iOS binary safely. Do not use this workflow for OTA-only updates.

## Workflow

1. Read repository release instructions, mobile config, `eas.json`, and git state.
2. Confirm the work is tracked before pushing.
3. Inspect App Store Connect before building:
   - Find the latest approved App Store version.
   - Find open and closed TestFlight pre-release trains.
   - Read recent Build Upload failures.
4. Compare the Expo `version` with Apple state.
   - If Apple closed that train or approved the same version, increment the patch version first.
   - Never solve this by changing only `ios.buildNumber`.
   - Let EAS auto-increment the build number when configured.
5. Run focused formatting/config validation.
6. Commit and push the version change only when authorized and linked to tracked work.
7. Build:

```bash
eas build --platform ios --profile production --non-interactive
```

8. Wait for EAS status `FINISHED`. Treat `ERRORED` or `CANCELED` as failures and inspect logs.
9. Submit the exact build ID:

```bash
eas submit --platform ios --profile production --id <build-id> --non-interactive
```

10. Do not report success at upload completion. Monitor App Store Connect until the build is either:
    - available for testing, or
    - failed with an exact Apple error.
11. If failed, open the Build Upload status, capture every error code and message, fix the root cause, then restart from step 3.
12. Verify CI for the pushed SHA. Do not merge unless explicitly authorized.

## Apple train guard

Before every native build, enforce:

```text
Expo version > latest approved App Store version
OR
Expo version belongs to an explicitly open TestFlight train
```

Apple errors `90186 Invalid Pre-Release Train` and `90062 CFBundleShortVersionString` mean the marketing version must increase. Increment the patch version, rebuild with a new build number, and resubmit.

## Monitoring

- Prefer App Store Connect or its API as source of truth; EAS only proves upload/submission.
- Poll meaningful state, not fixed UI delays.
- Report build version, build number, current state, and blocker.
- Continue until available or a concrete failure requires code or credentials.
