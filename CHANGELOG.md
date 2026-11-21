# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-11-21

### Added

- `podman`: `container_host_edition` states the edition the host already
  carries. The collection owns no identity: the argument spec accepts `server`
  only and an unsupported value fails validation; applying the role without the
  declaration fails its first task, whether or not the engine is selected.
- `podman`: the role removes the `99-podman.conf` the retired `server` and
  `workstation` roles wrote under `registries.conf.d` and `containers.conf.d`,
  before writing its own `99-container-podman.conf`, so exactly one file owns
  each configuration. `podman_stale_config_files` follows the two directories,
  and the removal restarts the user socket like any other engine change.
- The gate's `one registries writer` check: only `roles/podman/defaults/main.yml`
  may name a registries drop-in, and the retired name survives only as the
  removal target.

### Changed

- The base image keeps Debian's own `/etc/os-release` and no longer writes a
  `PRETTY_NAME`, a version of its own or `/etc/container-edition`: the
  collection is a capability and owns no identity, in an image or on a host.
- The collection version is `0.2.0`. The `0.3.0` invariants written in
  `publication-roadmap.md` (images by digest, `storage.conf.d`, the auto-update
  timer, a service account, no TCP socket) are not implemented yet, so the
  collection does not claim that number.

### Migration

- From `0.1.0`: declare `container_host_edition: server` in the host's
  variables. The engine role now refuses to run without it, whether or not
  `podman_enabled` is true, and `server` is the only accepted value.
- A host that ran an edition's engine keeps no configuration of its own: the
  retired `99-podman.conf` is removed on the first run, and the product's
  `99-container-podman.conf` replaces it.

## [0.1.0] - 2026-11-19

### Fixed

- `quadlet`: the account's home is a lazy variable with an empty default, so the
  role's argument validation no longer resolves `quadlet_home` before the passwd
  record is read (measured on `container-01-testing`).
- `podman`: the engine declares `kernel.unprivileged_userns_clone=1` in
  `62-podman-userns.conf`, loads it after a hardening file that disables the
  setting, reads it back, and removes it when the engine is not declared.


### Added

- The Ansible collection `benmoussa.container` and its 0.1.0 release.
- The rootless Podman engine role: packages, registry search path, engine
  drop-in, user socket, linger and subordinate IDs. It never creates a
  container.
- The Quadlet role: the site's unit files, a user-manager reload and a
  read-back of every generated unit. It ships no container definition.
- The base image `images/base/Containerfile`: the Debian minimal base pinned by
  digest, TLS roots, `tzdata`, `curl`, `procps`, the Scripts interpreter (0.1.2,
  verified against its release `SHA256SUMS`), one non-root account, a locked
  root, no setuid bit and a branded `/etc/os-release`.
- The engine's defaults in `containers.conf`: `no_new_privileges` on, the pids
  limit and the log size bounded, `umask` 0077 and the `crun` runtime — Debian
  leaves all of them permissive.
- The Quadlet role writes the product's global hardening drop-in
  (`NoNewPrivileges`, all capabilities dropped, read-only rootfs, `RunInit`,
  pids and ulimit bounds, journald logs) and refuses a container unit that
  declares `Network=host`, `User=0`, `NoNewPrivileges=false`,
  `ReadOnly=false` or `SecurityLabelDisable=true` while it is on.
- The example inventory with documentation values only (TEST-NET-1).
- The repository gate, the CI workflow and the release workflow.

### Security

- The engine is rootless only; the rootful socket is not enabled.
- No registry credential, secret or site definition is part of the product.
- The configuration drop-ins are named `99-container-podman.conf`, so the
  collection does not collide with a site's own Podman configuration.

[Unreleased]: https://github.com/benmoussa-younes/container/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/benmoussa-younes/container/releases/tag/v0.2.0
[0.1.0]: https://github.com/benmoussa-younes/container/releases/tag/v0.1.0
