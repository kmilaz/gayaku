# The classifier trains on the Kaggle product catalogue, and its artifacts stay coursework-only

**Status**: superseded as the classifier's final training set by ADR-0008 (the merged 18 classes) and ADR-0010 (that classifier behind a detector). The coursework-only licence posture below still applies to whatever ships.

Training data is the Kaggle *Fashion Product Images* dataset (`paramaggarwal`), used at high resolution: its `articleType` column supplies 141 fine labels (`Tshirts` 7065, `Shirts` 3212, `Jeans` 602, `Jackets` 258, …) that we map down to the five Categories, and its white-background catalogue framing resembles what the classifier sees after the cutout step. The dataset's MIT tag is the uploader's claim over their labels; the photographs are third-party catalogue photography they do not own. The trained weights and any build containing them are therefore coursework artifacts — not redistributed, not shipped commercially.

Until Kaggle credentials are available the classifier shipped in the app is trained on `alexeygrigorev/clothing-dataset-small` (CC0, no attribution) instead — the same bootstrap set named below. That is a temporary source, not a change of decision: the catalogue run supersedes it, and the coursework-only caveat above applies to whichever model ends up in the build.

## Considered options

- **`fnauman/fashion-second-hand-front-only-rgb`** (CC-BY-4.0, 31,638 in-house photographs from RISE/Wargön/Myrorna, the cleanest rights chain, and it separates Jeans from Trousers) — not chosen as the primary because the shots come from a second-hand sorting table rather than the catalogue framing.
- **`alexeygrigorev/clothing-dataset-small`** (CC0, 10 classes, real user flat-lays) — kept as an optional augmentation set: zero attribution, but it cannot tell Jeans from Trousers.
- **Fashionpedia** (46 classes) — its authors state the CC-BY-4.0 covers the annotations and ontology, not the Flickr/Unsplash images, and its ~7 boxes per image include 19 apparel-*part* classes, which would force the detector that the one-garment-per-photo rule lets us skip.
