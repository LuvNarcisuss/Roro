# Local photography community implementation

## Scope and decisions
The owner approved licensed Pexels fallback and fictional local community data. Preserve React Native, the local H5 archive, StoreKit 1 and existing private records. Use one bundled catalog for web/native IDs. Keep real source attribution separate from fictional personas; use licensed theme avatars. Video authors own only video works so their profile totals exactly equal their video totals. Photo authors have photo works. Topic totals include visible photos and shorts. Hidden works are excluded consistently from displayed totals and lists.

## Steps
1. Download five licensed clips, inspect representative frames, extract posters and record provenance.
2. Add stable author/work/comment records and shared derived statistics. Preserve old notes and add separate local comments.
3. Connect Shorts, author profiles, Topics, photo details, saved and hidden collections. Allowlist bundled playback/share/source URLs natively.
4. Check source data integrity, typecheck, package and compile for Roro UI Acceptance. Perform a fresh independent source review and correct material findings.

## Verification boundary
Compilation, packaging and typechecking are authorized. Do not install, launch or run application/runtime tests. Static data validation is allowed. Existing files are uncommitted user work; edit the approved Roro directory without moving or resetting it. Record actual verification results separately.

## Progress
- Media: five HD files downloaded, all three-frame contact sheets inspected. No caption overlays observed. Original HD files retained.
- Implementation: shared selectors, native comments/author IDs, bundled video playback/share/source allowlists, author profiles and topic statistics connected.
- First verification: TypeScript, 139 static project checks, 271 community static checks and the designated Debug simulator build passed. Media/catalog byte equality and strict code signature verification passed.
- Fresh independent source review: two important findings confirmed. Restoring the current video/topic is now part of leaving Shorts for a profile/topic. Saved totals now use the same visible records as the collection, without deleting hidden saved relationships. Final compilation after these fixes succeeded. TypeScript, static checks, current artifact/media hashes and strict code signature verification passed. See docs/community-verification-2026-11-17.md.
- Verification ruling: preserve the owner's explicit no-runtime-testing boundary. Source-level fixes will be typechecked, compiled and statically inspected; interactive reproduction and persistence replay remain unverified.
- Review scope rulings: source license access was independently verified by the primary task; actual Safari/player/share behavior awaits runtime authorization. Wallet behavior is unchanged and remains outside this feature's verification.
