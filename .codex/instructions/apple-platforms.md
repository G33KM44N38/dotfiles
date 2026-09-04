# Apple platforms

One job: protect macOS and iOS application identity during debugging.

## Rules

- Do not re-sign or ad hoc sign an application as a debugging step without explicit approval.
- Do not change bundle IDs, entitlements, signing identities, or related identity settings without explicit approval.
- Announce the exact proposed change before requesting approval.
- Explain that identity changes can reset or break TCC permissions.
