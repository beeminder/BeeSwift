# Automated Weekly TestFlight Build — Plan

## Goal

A weekly GitHub Actions workflow that builds the BeeSwift app and uploads it to
TestFlight, fully unattended, with code signing handled by `fastlane match` so no
developer Mac is in the loop.

## Background (current state)

- `fastlane/Fastfile` already has a `beta` lane that does the core release flow:
  `ensure_git_status_clean` → `app_store_connect_api_key` (reads a local `.p8`) →
  `increment_build_number` to `latest_testflight_build_number + 1` → `build_app` →
  `upload_to_testflight` → `add_git_tag` / `push_git_tags` → `reset_git_repo`.
- CI today is GitHub Actions only (`.github/workflows/fastlane-tests.yml`,
  `pre-commit.yml`) — there is **no scheduled workflow** and no release workflow.
- **No `match`** anywhere — distribution signing currently relies on a developer's
  Mac (`CODE_SIGN_STYLE = Automatic`, team `8TW9V9HVES`).
- Several files needed for a real build are git-ignored: `fastlane/AuthKey_*.p8`,
  `BeeKit/Config.swift`, `BeeSwift/Config.swift`, `BeeSwift/GoogleService-Info.plist`,
  `BeeSwift/Sentry.sh`.
- App bundle id `com.beeminder.beeminder`; build scheme `BeeSwift`; project
  `BeeSwift.xcodeproj` (no standalone workspace); SPM for dependencies.

## Approach

- **Local signing stays exactly as-is** — Xcode automatic signing. Developers only
  ever create *development* certs, which have a generous limit, so there's no
  scarcity problem.
- Introduce **`fastlane match`** as the single owner of the App Store **distribution**
  certificate + provisioning profile, stored encrypted in a dedicated private git
  repo.
- The weekly CI job runs **`match(readonly: false)`** so it is **self-healing**: a
  valid cert is reused; an expired or missing one is regenerated and pushed back to
  the store automatically. No separate rotation/maintenance workflow is required
  (one can be added later if ever wanted — see "Optional later" below).
- CI accesses the match repo via a **GitHub deploy key** (a repo-scoped machine
  credential, not tied to any user account), with **write** access (required because
  the self-healing run may push regenerated material).
- Apple access uses the existing **App Store Connect API key** — a team-level
  credential, not tied to any Apple ID. One key (role: **App Manager**) covers both
  cert/profile management for `match` and the TestFlight upload.

### Why `readonly: false` weekly, and not a separate rotation workflow

- A non-readonly `match` run does **not** churn certs — a valid cert is reused; a new
  one is minted only on first run or after the stored one expires/is revoked.
- The only real cost vs. `readonly: true` is that the certs-repo deploy key must be
  read-write, so an unattended weekly job holds write access to the signing repo.
- The other difference is behavior on weird state: `readonly: false` silently
  regenerates and moves on; `readonly: true` fails loudly so a human investigates.
  For a project this size, "keep shipping" is the reasonable default.
- Expired certs do **not** count against Apple's ~2-valid-distribution-cert cap, so
  a late run self-heals fine. The cap only bites when there are two *still-valid*
  certs (e.g. an orphan nobody remembers) — rare, and surfaced immediately.

## One-time setup (done by you — admin Mac + GitHub admin)

1. Create a **private repo** for signing material — done: `beeminder/BeeSwift-credentials`.
2. From a Mac with the distribution signing rights (the `fastlane/Matchfile` is
   already committed, so `match init` is not needed):
   - `bundle exec fastlane match appstore` — prompts for a **passphrase**, then
     generates + uploads the distribution cert/profile and populates the repo
3. Generate an **SSH deploy key**; add the public half to
   `beeminder/BeeSwift-credentials` as a deploy key with **write** access.
4. Confirm the App Store Connect API key's role is **App Manager** (needs upload +
   cert/profile management). Created under App Store Connect → Users and Access →
   Integrations → App Store Connect API. Note the **Key ID**, **Issuer ID**, and the
   `.p8` file.
5. Add the secrets to a **`testflight` GitHub Environment** on `beeminder/BeeSwift`
   (restricted to `master`), not repository-wide:
   - `MATCH_PASSWORD` — the match passphrase
   - `MATCH_SSH_KEY` — private half of the credentials-repo deploy key
   - `ASC_KEY_ID`, `ASC_ISSUER_ID` — App Store Connect API key identifiers
   - `ASC_KEY_P8_BASE64` — the `.p8`, base64-encoded
   - `CONFIG_SWIFT` — contents of `BeeKit/Config.swift`. (`BeeSwift/Config.swift`,
     `BeeSwift/GoogleService-Info.plist`, and `BeeSwift/Sentry.sh` are not
     referenced by the Xcode project and are not needed for the build.)
6. Decide whether the workflow should push a git tag per build (the existing `beta`
   lane does `add_git_tag` / `push_git_tags`). Keeping it means the workflow needs
   `permissions: contents: write` and uses the built-in `GITHUB_TOKEN` (acts as the
   github-actions bot, not a user). Dropping it removes that requirement.

## Repo changes (implemented on branch `claude/auto-testflight-builds-ZbOTz`)

1. **New `beta_ci` lane** in `fastlane/Fastfile`:
   - decode `ASC_KEY_P8_BASE64` and write it to `fastlane/AuthKey_<id>.p8`
   - `app_store_connect_api_key(...)` reading `ASC_KEY_ID` / `ASC_ISSUER_ID` from env
   - `match(type: "appstore", readonly: false)`
   - `increment_build_number(build_number: latest_testflight_build_number + 1,
     xcodeproj: "BeeSwift.xcodeproj")`
   - `update_code_signing_settings(use_automatic_signing: false, ...)` (or pass via
     `build_app` `export_options`) to sign with the match profile, then
     `build_app(scheme: "BeeSwift")`
   - `upload_to_testflight`
   - optionally `add_git_tag` + `push_git_tags`
   - **no** `ensure_git_status_clean` (CI dirties the tree by writing the `Config.swift`
     / `GoogleService-Info.plist` / `Sentry.sh` files) and **no** `reset_git_repo` on
     the source repo
2. **New `.github/workflows/testflight-weekly.yml`:**
   - `on:` weekly `schedule:` cron **+** `workflow_dispatch` (manual trigger)
   - `runs-on: macos-26`, pin Xcode via `maxim-lobanov/setup-xcode` (mirror
     `fastlane-tests.yml`)
   - `actions/cache` for `SPMCache` (key on `Package.resolved`)
   - `ruby/setup-ruby` with Ruby `3.3.5` and `bundler-cache: true`
   - write `BeeKit/Config.swift`, `BeeSwift/Config.swift`,
     `BeeSwift/GoogleService-Info.plist`, `BeeSwift/Sentry.sh` from secrets (or `cp`
     the `.sample` files + stub `Sentry.sh`)
   - start `ssh-agent` and load `MATCH_SSH_KEY`; decode `ASC_KEY_P8_BASE64` to a file
   - `bundle exec fastlane beta_ci`
   - upload build log / `fastlane` output as an artifact on failure
3. **Docs touch-up:** document the new release path in `CONTRIBUTING.md`, and fix the
   stale "Semaphore CI" reference there.

## Verify before the first green run

- `BeeSwift/BeeSwift.entitlements` has `aps-environment = development` — fine for
  TestFlight in practice, but confirm it's intended.
- The `BeeSwiftToday` and `BeeSwiftIntents` schemes reference `.appex` targets that
  are not present in `project.pbxproj`; ensure `build_app(scheme: "BeeSwift")`
  archives cleanly regardless.
- Make sure you are not already at Apple's 2-valid-distribution-cert cap before the
  first `match` run (prune orphaned certs if so).
- Final decision on tag-pushing (affects workflow `permissions`).

## Secrets summary

| Secret | Purpose | User-bound? |
| --- | --- | --- |
| `MATCH_PASSWORD` | decrypt the match storage repo | no |
| `MATCH_SSH_KEY` | clone/push the `certificates` repo (deploy key) | no — repo-scoped machine key |
| `ASC_KEY_ID` / `ASC_ISSUER_ID` | App Store Connect API key identifiers | no — team-level |
| `ASC_KEY_P8_BASE64` | App Store Connect API private key (`.p8`) | no — team-level |
| `CONFIG_SWIFT` | contents of `BeeKit/Config.swift` | no |
| `GITHUB_TOKEN` (built-in) | push the per-build git tag (if kept) | no — github-actions bot |

## Optional later

- **`match-rotate` workflow** — `workflow_dispatch` only; `match nuke distribution`
  + `match appstore` to deliberately rotate the distribution cert. Destructive; needs
  a read-write deploy key and an API key with cert-management rights; gate behind a
  typed confirmation input. Worth adding only if you want a one-button rotation.
- **Expiry-warning job** — scheduled check that opens an issue / pings Slack when the
  distribution cert is < 30 days from expiry. Mostly redundant given `readonly: false`
  self-heals, but cheap insurance against the "two valid certs / can't mint a third"
  edge case.
- **`match` storage on S3/GCS instead of a git repo** — IAM-grade access separation
  and audit logs; more infra. Overkill now.

## Effort

Repo changes: ~1 hour. The real work is the one-time setup (certs repo + `match`
seed + ~6 secrets). After that it is hands-off; the only occasional task is pruning an
old expired cert for tidiness, and even that is not required.
