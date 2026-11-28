# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `account`: the collection creates the login account the rootless engine runs
  as, so a host needs no pre-existing human. The defaults are `container` with
  uid/gid 1500, the distribution's home for that name and `/bin/bash`; the name,
  UID, GID, home and shell are inventory values. The role refuses to rewrite an existing
  identity (an account or a group that already holds another UID or GID fails
  the run), reads the account back, and checks that the home belongs to it.
  `playbooks/site.yml` runs it first, when the engine or the declarations are
  enabled.
- `quadlet`: the published host-port floor is enforced. A `PublishPort` whose
  host port is below `quadlet_unprivileged_port_start` (the host's
  `net.ipv4.ip_unprivileged_port_start` when empty) fails the run, and template
  unit names (`foo@.container`) are accepted.
- `podman`: `podman_auto_update` (false by default) enables the account's
  `podman-auto-update.timer`, without which a unit's `AutoUpdate=registry` is a
  dead setting. The engine read-back now refuses a `vfs` store, a cgroup other
  than v2 and a network backend other than netavark, instead of reading only the
  rootless flag.

### Changed

- `podman_user` defaults to the account `roles/account` declares
  (`account_name`, `container` by default) instead of the undefined
  `accounts_human.name`, which left the engine with an empty account on any
  host that did not define that foreign variable.
- The README no longer asks for an existing human account, and the sandbox
  inventory no longer asks the owner to create its account by hand.

## [0.3.0] - 2026-11-27

### Added

- `podman`: the subordinate ID ranges are planned before they are written, by
  `roles/podman/files/subid-plan.awk`. The plan refuses a range another account
  holds, a range shorter than `podman_subuid_count`, a range in one file only,
  two ranges in one file, and a host that delegates `subid` to an NSS provider;
  it adds the first free block at or after `podman_subuid_start` when the account
  has none, and it never overwrites. A candidate must also avoid every UID and
  GID that `/etc/passwd` and `/etc/group` declare, and the count is capped at
  1 048 576. A host whose accounts or subordinate ranges come from an NSS
  provider is refused, because the plan reads the files.
- `podman`: `podman_subuid_repair` (false by default) is the one repair the role
  accepts: it removes this account's unusable ranges, then adds the block the
  plan names.
- `podman`: `podman_system_migrate` runs `podman system migrate` as the owning
  account after a change, and the kernel's `/proc/self/uid_map` and `gid_map` are
  read back and asserted against the planned block.
- `podman`: the host's base is asserted before anything is written (Debian 13
  read from `/etc/debian_version`, systemd, cgroup v2). The edition brands
  `/etc/os-release`, so `ansible_distribution_version` reads the edition's own
  `1.0` and is not used.
- `podman`: `catatonit` is installed. The Quadlet default `RunInit=true` needs it
  and Debian lists it as a *Recommends* of `podman`, so a host that installs no
  recommends started no container.
- gate: the planner is proven against fourteen fixture host states (including a
  host UID inside the candidate block and a malformed line), and
  `tests/playbooks/subid.yml` runs the role's own decision tasks and both
  refusals without root. `tests/inventories/sandbox/` converges the collection
  on the test host with its configuration relocated under `/var/tmp`.
- gate: every defect line carries at most ten lines of a failed command's output.
- gate and CI: `scripts check --deny-warnings`, `--module` for the modules, and
  `scripts run --no-warnings` for the gate.

### Fixed

- a subordinate range that another account also held was accepted in silence,
  while `roles/podman/defaults/main.yml` and `SECURITY.md` claimed a collision
  was a hard failure;
- `usermod` was called with the same hard-coded 100000 block for every account,
  so two engines on one host collided;
- nothing read back the mapping the kernel installed, so a file the engine
  ignored passed the run;
- `release.scs` computed its program name in a helper, which raised
  `SCRIPTS-LINT-0004`; each call site now passes a literal `run_request`.

### Changed

- `SECURITY.md` states the mechanisms that actually isolate a container (no LSM
  confines a rootless container on Debian 13) and the risk of the socket the
  role enables.

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
- `quadlet`: `quadlet_default_memory` and `quadlet_default_cpu_quota` give every
  container unit a `MemoryMax=` and a `CPUQuota=` unless it declares its own.
  The role writes a per-unit drop-in only while the unit omits the key (a
  Quadlet drop-in wins over the unit file), and removes it as soon as the unit
  declares the key or the default is emptied.
- The gate's `one registries writer` check: only `roles/podman/defaults/main.yml`
  may name a registries drop-in, and the retired name survives only as the
  removal target.

### Changed

- The base image keeps Debian's own `/etc/os-release` and no longer writes a
  `PRETTY_NAME`, a version of its own or `/etc/container-edition`: the
  collection is a capability and owns no identity, in an image or on a host.
- The collection version is `0.2.0`. The invariants a `0.3.0` would carry —
  images pinned by digest, a read-back of the storage driver (Podman 5.4.2 has
  no `storage.conf.d`), the auto-update timer, a service account, no TCP
  socket — are not implemented yet, so this release does not claim them.

### Fixed

- `podman`: `--check` no longer fails on a host where the user-namespace
  drop-in is not applied yet. The read runs in check mode (it only reads) and
  the assert is skipped there, because check mode cannot apply the sysctl it
  asserts. Measured before: `ok=8 changed=1 failed=1`, "is , not 1".

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
  limit bounded, `umask` 0077 and the `crun` runtime — Debian
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
[0.3.0]: https://github.com/benmoussa-younes/container/releases/tag/v0.3.0
[0.2.0]: https://github.com/benmoussa-younes/container/releases/tag/v0.2.0
[0.1.0]: https://github.com/benmoussa-younes/container/releases/tag/v0.1.0
