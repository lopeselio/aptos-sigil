# Brand assets

## `aptos-sigil-logo.png`

The Aptos Sigil logo (silver winged crest + green crystal, "APTOS SIGIL"
wordmark) — full-resolution master (1024×1024).

The console + all three games reference `/logo.png` (header) and use it as the
favicon / app icon. To (re)distribute after replacing the master, run:

```bash
./scripts/sync-logo.sh
```

That copies a 256px-downscaled version into each app's `public/logo.png` and
`app/icon.png` (the master here stays full-res). Commit the generated PNGs so
deploys include them.

> The master has a light background. For the apps' dark themes a transparent-PNG
> version reads best — drop a transparent `aptos-sigil-logo.png` here and re-run
> the sync to swap it everywhere.
