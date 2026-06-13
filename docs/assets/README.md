# Brand assets

## `aptos-sigil-logo.png`  ← save the logo here

The Aptos Sigil logo (silver winged crest + green crystal, "APTOS SIGIL"
wordmark). **Save the provided PNG at this exact path:**

```
docs/assets/aptos-sigil-logo.png
```

Then distribute it to every app:

```bash
./scripts/sync-logo.sh
```

That copies it into the console and all three games (`public/logo.png` for the
header, `app/icon.png` for the Next.js favicon), which already reference it.
Commit the generated PNGs so deploys include them.

> A transparent background (the logo is on white here) works best on the apps'
> dark themes — export a transparent-PNG version if you have one.
