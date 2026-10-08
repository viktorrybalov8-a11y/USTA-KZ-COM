# USTA.KZ — release security gates

This checklist is mandatory before publishing production APK/AAB or enabling payments.

## Credentials and access
- [ ] Review all open GitHub secret scanning alerts; distinguish Firebase client configuration from privileged credentials.
- [ ] Revoke and rotate exposed service account keys, private keys, payment credentials or server tokens. Never commit replacements.
- [ ] Verify Firebase Auth email verification and custom admin claim are enforced server-side.
- [ ] Run Firebase Security Rules tests against unauthorized reads, privilege escalation, cross-user writes, order ownership and chat membership.
- [ ] Review public Git history for secrets before release.

## User safety and privacy
- [ ] Ensure private user phone numbers are not exposed in public profile documents.
- [ ] Validate uploaded file MIME types, sizes, storage paths and access rules.
- [ ] Verify account deletion, privacy policy, terms and support contact.
- [ ] Obtain Android notification permission; honor opt-out and city/category preferences.

## Backend and money
- [ ] Deploy Firestore indexes/rules and Cloud Functions to the intended Firebase project; verify project and region first.
- [ ] Obtain owner approval before enabling paid Firebase Blaze services.
- [ ] Never activate a paid subscription based solely on client confirmation or screenshot; use trusted server-side payment confirmation.
- [ ] Do not issue a fiscal receipt for an unverified transfer. Document legal fiscal receipt provider and refund process.

## Release verification
- [ ] flutter analyze, flutter test and Android build succeed on main.
- [ ] Real-device tests: registration, email verification, profile, publish/edit/delete order, city routing, chat, notifications, admin isolation, back navigation.
- [ ] Signed AAB and Play Console data-safety declaration reviewed.
- [ ] Owner signs off on public production release after blocking issues are closed.
