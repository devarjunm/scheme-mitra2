# Scheme Mitra Android client

A separate Flutter Android app for Maharashtra farmers. It uses only the Scheme Mitra API; it does not scrape government pages, call an AI provider, collect Aadhaar/bank identifiers, upload document files, submit applications, or claim government status. Official sources and application portals open in the external browser.

## Main flows

- Account registration, sign-in, development-only synthetic demo access and sign-out. Mobile bearer tokens are stored with `flutter_secure_storage`; an expired session returns to sign-in (there is no refresh-token flow yet).
- Home, searchable published-scheme catalogue, saved schemes, self-reported application tracker and farm-profile editing.
- Deterministic eligibility labels and rule explanations, source facts/links, date checked, document checklist caveat and official portal links.
- Account deletion requires password re-entry and typing `DELETE`; the same-origin `/delete-account` web page is also available from the backend.
- English, Marathi and Hindi interface copy. Some scheme content and source-rule explanations remain in their captured source language; review translated content before a language-specific public launch.

The app displays only schemes the API returns as both `PUBLISHED` and `VERIFIED`. A verified record with an incomplete ruleset still returns “Insufficient Information.” The current catalog's candidate records are not automatically promoted by this client.

## Local Android emulator

Start the backend using the documented development setup, then from this directory:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's host alias. Android cleartext access is restricted to that host in the debug manifest. For physical devices, use a reachable HTTPS development API origin.

## Release

See [`RELEASE.md`](RELEASE.md) for the production build command, upload-key setup, expected AAB path, Play target API and launch blockers. A real HTTPS API origin and an operator-owned upload key are required; they are not committed here.
