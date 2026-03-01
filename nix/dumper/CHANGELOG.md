# Changelog

## [0.4.1](https://github.com/svnlto/homelab/compare/dumper-v0.4.0...dumper-v0.4.1) (2026-03-01)


### Bug Fixes

* correct Photos Library path duplication in dumper sync ([9bd3897](https://github.com/svnlto/homelab/commit/9bd38976dcc91f9c9a40e2caa4c782d49b9bb47b))

## [0.4.0](https://github.com/svnlto/homelab/compare/dumper-v0.3.0...dumper-v0.4.0) (2026-03-01)


### Features

* add Immich deployment with shared Dragonfly cache and enhanced PostgreSQL ([#48](https://github.com/svnlto/homelab/issues/48)) ([cc2c030](https://github.com/svnlto/homelab/commit/cc2c0306248f40ef5869404a00806b1b96d35730))
* targeted photo sync using Photos.sqlite instead of remote find ([c7c8f78](https://github.com/svnlto/homelab/commit/c7c8f78a9917710a2e129916554290c699e018fc))

## [0.3.0](https://github.com/svnlto/homelab/compare/dumper-v0.2.4...dumper-v0.3.0) (2026-02-27)

### Features

* migrate observability from SigNoz to OpenObserve ([cdc4000](https://github.com/svnlto/homelab/commit/cdc4000c826610cb04d17efcd654b06cf4e4d4e7))

## [0.2.4](https://github.com/svnlto/homelab/compare/dumper-v0.2.3...dumper-v0.2.4) (2026-02-25)

### Bug Fixes

* migrate all SQLite apps from NFS to iSCSI storage ([387043e](https://github.com/svnlto/homelab/commit/387043eeaebd0d51ee9aa9e4d6b9d2b6055dd960))

## [0.2.3](https://github.com/svnlto/homelab/compare/dumper-v0.2.2...dumper-v0.2.3) (2026-02-25)

### Bug Fixes

* use Homebrew rsync on remote Mac for protocol compatibility ([24c2f30](https://github.com/svnlto/homelab/commit/24c2f30c0ff01b6f6a6446d8ad0331b9571b4680))

## [0.2.2](https://github.com/svnlto/homelab/compare/dumper-v0.2.1...dumper-v0.2.2) (2026-02-25)

### Bug Fixes

* reduce rsync parallelism to 4 and stagger stream starts ([6c9516b](https://github.com/svnlto/homelab/commit/6c9516b1fd30a19fe0417c0e9aeb85e489bbe3d5))

## [0.2.1](https://github.com/svnlto/homelab/compare/dumper-v0.2.0...dumper-v0.2.1) (2026-02-25)

### Bug Fixes

* arithmetic syntax error in parallel rsync stats aggregation ([f9d4fe0](https://github.com/svnlto/homelab/commit/f9d4fe0ea7049463cd071678b722dc4bc4071688))

## [0.2.0](https://github.com/svnlto/homelab/compare/dumper-v0.1.0...dumper-v0.2.0) (2026-02-24)

### Features

* parallel rsync streams and Tailscale peer relay for dumper ([74a5c9d](https://github.com/svnlto/homelab/commit/74a5c9dab2efd6fd9d07d441e0fdf76bd44a0fba))
