# Changelog

## [0.6.0](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.5.1...osxphotos-export-v0.6.0) (2026-08-02)


### Features

* **observability:** ship Talos node logs to ClickStack + cut log noise ([f00b83c](https://github.com/svnlto/homelab/commit/f00b83c56c4d7b920d1254ad50ebe99f89730799))

## [0.5.1](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.5.0...osxphotos-export-v0.5.1) (2026-07-31)


### Bug Fixes

* **osxphotos-export:** serve metrics as text/plain, add source freshness ([d2dd520](https://github.com/svnlto/homelab/commit/d2dd520055a78fbbf0a61beb82bb00b43fca22d0))

## [0.5.0](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.4.0...osxphotos-export-v0.5.0) (2026-07-31)


### Features

* **osxphotos-export:** expose export metrics and alert on staleness ([2152b41](https://github.com/svnlto/homelab/commit/2152b41600511adc58daea76be81f78336183bef))

## [0.4.0](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.3.0...osxphotos-export-v0.4.0) (2026-07-26)


### Features

* **direnv:** load 1Password credentials; apply drifted formatters ([#166](https://github.com/svnlto/homelab/issues/166)) ([076a1f0](https://github.com/svnlto/homelab/commit/076a1f02b7930a6797dd931cf3d83cb7b7ee4d3e))

## [0.3.0](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.2.0...osxphotos-export-v0.3.0) (2026-05-01)

### Features

* **osxphotos-export:** add exiftool to write correct dates from Photos DB ([4ebb40a](https://github.com/svnlto/homelab/commit/4ebb40aab9315e0ac8ce9bd55becdec89a62e638))
* P700 server consolidation ([#84](https://github.com/svnlto/homelab/issues/84)) ([5632130](https://github.com/svnlto/homelab/commit/5632130f7adae0b43c244b8d3ebdc7bb32bd6a3d))

### Bug Fixes

* **osxphotos-export:** restore exiftool support lost in script rewrite ([31a7a14](https://github.com/svnlto/homelab/commit/31a7a14a859ee50478a5546a68f7fc9cc60a9920))

### Performance Improvements

* **osxphotos-export:** add --ramdb, reduce verbosity, expand cache PVC ([8a829fe](https://github.com/svnlto/homelab/commit/8a829feaa394c810f9e3de9251635c37efd916a1))

## [0.2.0](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.1.1...osxphotos-export-v0.2.0) (2026-04-27)

### Features

* **osxphotos-export:** add exiftool to write correct dates from Photos DB ([4ebb40a](https://github.com/svnlto/homelab/commit/4ebb40aab9315e0ac8ce9bd55becdec89a62e638))
* P700 server consolidation ([#84](https://github.com/svnlto/homelab/issues/84)) ([5632130](https://github.com/svnlto/homelab/commit/5632130f7adae0b43c244b8d3ebdc7bb32bd6a3d))

### Bug Fixes

* **osxphotos-export:** restore exiftool support lost in script rewrite ([31a7a14](https://github.com/svnlto/homelab/commit/31a7a14a859ee50478a5546a68f7fc9cc60a9920))

## [0.1.1](https://github.com/svnlto/homelab/compare/osxphotos-export-v0.1.0...osxphotos-export-v0.1.1) (2026-04-12)

### Bug Fixes

* **osxphotos-export:** restore exiftool support lost in script rewrite ([75412f5](https://github.com/svnlto/homelab/commit/75412f5976f1b7109eba1c1e836f0b65088c4277))
