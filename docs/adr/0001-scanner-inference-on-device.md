# Scanner inference runs on-device; ml_workspace stays an offline lab

The Smart Scanner runs its models inside the Flutter app as bundled LiteRT (`.tflite`) assets through `tflite_flutter`. `ml_workspace/` holds only offline work: dataset gathering, training, evaluation and export. A Python API serving predictions was rejected because it needs a host and a reachable network during the demo; a hybrid (matting local, classification remote) pays both integration costs.

## Amended 2026-11-09: the manifest now asks for `INTERNET`

Account, profile and saved-look sync run through Supabase, which arrived with `PR #12` and `PR #13`.
The owner accepted that as a network feature rather than reverting it, so the release manifest declares
`INTERNET`. This ADR still governs the scanner, and only the scanner: **inference runs from the assets in
the APK, and a scan never uploads a photograph.** The offline guarantee is now a property of the scanning
path, not of the manifest.

## Consequences

- Models ship inside the APK, so a scan works with no connectivity and uploads nothing. The manifest does declare `INTERNET` for account and profile sync; a change that makes *scanning* depend on the network contradicts this ADR, and so does uploading a captured photograph.
- Swapping a model means a new build, not a redeploy.
- LiteRT export runs on Linux/macOS only, so exports happen in WSL or Colab even though the app is developed on Windows.
- Inference can only be verified on the Android emulator or a device; Windows desktop runs of the app are limited to non-inference behaviour.
