# Vava-referenced Shorts correction

Goal: Replace the Roro video-management landing page with the full-height, swipeable playback experience the owner requested by reference to Vava. Remove the framed center navigation icon.

Spec: docs/superpowers/specs/2026-11-17-shorts-design.md

- [x] Inspect current Vava H5 source and existing screenshot; record the actual layout and behavior.
- [x] Implement single-player inline feed, swipe paging, pause/mute/seek, search, private notes and action rail; retain the local import composer and persistent records.
- [x] Add a native allowlisted saved-video export command and shell foreground/background events; restrict CSP media access to local files.
- [x] Replace the Shorts artwork and remove its special navigation background; retain provenance in Assets.
- [x] Typecheck, compile for Roro UI Acceptance, verify the actual bundled archive and signature. No app launch or runtime tests are authorized.

Reference review is read-only. No Vava files, identities, configuration, videos or account data are copied. Runtime acceptance remains pending; existing screenshots are reference evidence only.

Evidence: TypeScript exit 0, 130 static checks, successful latest Debug simulator compilation, 56 current archive inputs and strict signing verification. See docs/shorts-feed-verification-2026-11-17.md. The static review's conflicting-topic selection issue was corrected. Runtime validation remains unperformed.
