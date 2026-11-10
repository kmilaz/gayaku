# The release build asks for `INTERNET`, because the wardrobe lives in Supabase

ADR-0001 keeps inference on-device and ships the models inside the APK. It also recorded that the release manifest carried no `INTERNET` permission. That is no longer true: the wardrobe is stored in Supabase, so the app has to reach `https://<project-ref>.supabase.co` to sign in and to read or write `wardrobe_items`.

## Decision

`android/app/src/main/AndroidManifest.xml` declares `android.permission.INTERNET`.

The permission buys a shared database, not a server-side model. Nothing in the scan path uploads a photo or asks a server for a label:

- background removal and classification run through `tflite_flutter` on the device;
- cutouts are written to `<app documents>/cutouts/<uuid>.png`, and only the file name goes into the row;
- the only network calls are GoTrue (`/auth/v1`) and PostgREST (`/rest/v1`).

ADR-0001's rule — no model is served over the network — still holds.

## Consequences

- The scanner still works offline; the wardrobe does not. With no connectivity the app starts, the scanner runs, and the sync seam in `lib/state/wardrobe_sync.dart` swallows the failure instead of blocking the first frame.
- `supabase_flutter` keeps its session in the platform keystore-backed storage, so a relaunch resumes the signed-in user.
- The manifest also carries `READ_PHONE_STATE`, `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE`, merged in by `tflite_flutter` and `image_picker`. If a reviewer wants the smallest possible permission set, those come from the plugins, not from the wardrobe code.
- Without `INTERNET`, Android fails DNS resolution with `SocketException: Failed host lookup`, which reads like a backend outage instead of a manifest mistake. That cost an afternoon once; keep the permission.
