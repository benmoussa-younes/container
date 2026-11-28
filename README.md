# Container

[![Release](https://img.shields.io/badge/release-0.3.0-blue)](https://github.com/benmoussa-younes/container/releases/tag/v0.3.0)
[![Licence](https://img.shields.io/badge/licence-AGPL--3.0--or--later-blue)](LICENSE)
[![CI](https://github.com/benmoussa-younes/container/actions/workflows/ci.yml/badge.svg)](https://github.com/benmoussa-younes/container/actions/workflows/ci.yml)

Ansible roles that install a **rootless Podman engine** on a **Debian** host,
write the **Quadlet** declarations a site owns and ship the **base image** those
declarations run on. The product owns the engine, the generator's input and the
base; the definitions themselves — ports, volumes, networks, secrets — remain
the site's.

It installs on a host that already carries an edition — Server Edition today;
a Workstation Edition host is refused — and it **writes no host identity**: no `os-release` of
its own, no login banner, no boot splash, no version line of its own. The one
account it creates is the engine's own, and the site declares its name, UID and
GID. The edition says what the machine is; this collection says what it runs.
It is shipped as the collection `benmoussa.container`.

## What it does

- **The account it runs as**: the collection creates the login account the
  engine runs as, so a host needs no pre-existing human. `container` with
  uid/gid 1500 by default, and the name, the UID, the GID, the home and the
  shell are the site's. It refuses to move an existing identity: an account
  whose UID differs fails the run, it is never rewritten.
- **One rootless engine**: packages, registry search path, the account's
  engine configuration, the user socket, linger, subordinate IDs and the opt-in
  auto-update timer. The read-back refuses a `vfs` store, a cgroup other than
  v2 and a network backend other than netavark. The rootful socket is never
  enabled and `/etc/containers/systemd` is never written.
- **Subordinate IDs that are planned, not guessed**: the role computes the
  account's range from `/etc/subuid` and `/etc/subgid`, refuses one another
  account already holds, adds the first free block when the account has none,
  lets the engine adopt it (`podman system migrate`) and reads the kernel's
  `uid_map` and `gid_map` back. A host that delegates subordinate IDs to an NSS
  provider is refused, because the role reads the files.
- **The engine's defaults, decided**: Debian leaves `no_new_privileges` off,
  the root file system writable and the pids limit at 1024. The product turns
  the first on, makes the root read-only, bounds the pids and the nofile
  ulimit, sets `umask` 0077, names the `crun` runtime, keeps the
  distribution's seccomp profile and the caller's user namespace, and pulls an
  image only when it is missing. Container logs go to journald, whose retention
  belongs to the host journal: `log_size_max` only bounds the file driver,
  which the product's units do not use.
- **The configuration belongs to the account**: Podman reads
  `~/.config/containers/{containers,registries}.conf` and `policy.json` for one
  user before the host-wide files, and for `registries.conf` and `policy.json`
  the user file replaces the host-wide one. The role writes there, owned by the
  account, and never into `/etc/containers`: root and every other user keep
  their engine. The host-wide `99-container-podman.conf` and `99-podman.conf`
  the older versions and the retired edition roles left are removed, so exactly
  one file owns each configuration.
- **An image policy**: the account's `policy.json` accepts only the registries
  `podman_registries` declares and rejects every other repository, and
  `short-name-mode = "enforcing"` refuses an ambiguous short name outside a
  terminal. A declared `.container` or `.image` names its image by digest
  (`@sha256:` with the 64 hex characters); `image_digest: false` is the
  per-unit opt-out.
- **An edition it reads, never writes**: `container_host_edition` names the
  edition the host already carries (`server` today). Applying the engine role
  without it, or with another value, fails the run instead of guessing.
- **The site's Quadlet declarations**: `container`, `volume`, `network`, `pod`,
  `image`, `build` and `kube` files, including template names
  (`foo@.container`) and their drop-ins, in the owning account's generator
  directory, a user-manager reload and a read-back of every generated unit and
  every declared drop-in.
- **A hardening baseline in one drop-in**: `container.d/*.conf` is merged into
  every container unit of the account — no new privileges, all capabilities
  dropped, read-only rootfs with tmpfs, an init, pids and ulimit bounds,
  journald logs. A unit's own drop-in still wins.
- **A refusal, not a warning**: a declared unit that carries `Network=host`,
  `User=0`, `NoNewPrivileges=false`, `ReadOnly=false` or
  `SecurityLabelDisable=true` fails the run while the hardened defaults are on.
  The match ignores the spacing around `=`, so `Network = host` is refused too.
  Any `PodmanArgs`, `GlobalArgs`, `Unmask`, `SeccompProfile` or `Privileged`
  key is refused in any unit type, whatever its value: those keys bypass the
  drop-in rather than relax one setting.
- **A base image**: the Debian minimal base pinned by digest, TLS roots,
  `tzdata`, `curl`, `procps` and the Scripts interpreter, one non-root
  account, a locked root and no setuid bit. The image keeps Debian's own
  `/etc/os-release`; the collection writes no identity, in an image or on a
  host.

## Requirements

- a target running **Debian 13** (`trixie`), the release the supported edition
  runs today, with the engine packages taken from the distribution;
- `ansible-core` **2.20 or later, below 2.23** on the controller, with SSH access to the
  target;
- no pre-existing account: the collection creates the engine's own login
  account (`container`, uid/gid 1500 by default), and the name, UID and GID
  are inventory values;
- a privilege-escalation password: no account of the product holds `NOPASSWD`;
- the target's host key in the controller's `known_hosts`;
- network access to the distribution mirror, both on the target and wherever
  the base image is built; a registry is reached only when the site pulls an
  image, which this product never does.

Only `ansible.builtin` is used. `requirements.yml` declares no external
collection.

## Install the collection

From the release tarball (the collection is published on GitHub, not Galaxy):

```sh
ansible-galaxy collection install benmoussa-container-0.3.0.tar.gz
```

Or, from the signed tag:

```sh
ansible-galaxy collection install \
  git+https://github.com/benmoussa-younes/container.git,v0.3.0
```

The release also carries `container-0.3.0-src.tar.gz` (the source tree with the
example inventory and the repository tooling) and `SHA256SUMS`. Verify the
checksums before installing:

```sh
sha256sum -c SHA256SUMS
```

## Usage

Create the site inventory from the source archive's `inventories/example/`, or
write a minimal one:

```yaml
all:
  vars:
    ansible_user: debian
    ansible_python_interpreter: /usr/bin/python3

    # The account the collection creates and the engine runs as. The defaults
    # are `container` with uid/gid 1500; name, UID, GID, home and shell are
    # yours to declare.
    account_name: container
    account_uid: 1500
    account_gid: 1500

    # The engine. `podman_user` follows `account_name`; name another account
    # only when you turn `account_enabled` off and own that account yourself.
    # `container_host_edition` is the edition the host already carries: the
    # collection owns no identity and accepts `server` today.
    podman_enabled: true
    container_host_edition: server
    podman_registries: [docker.io]

    # The site's declarations. Nothing is created by this product.
    quadlet_enabled: true
    quadlet_units: []
```

Then:

```sh
ansible-playbook -i inventories/site/hosts.yml \
  benmoussa.container.site --check --diff -K
ansible-playbook -i inventories/site/hosts.yml \
  benmoussa.container.site -K
```

The playbook targets `all`; use `--limit` when the inventory holds more than the
hosts this product owns.

### Subordinate IDs

A rootless engine maps the container's UIDs onto host UIDs listed in
`/etc/subuid` and `/etc/subgid`; the ranges of two accounts must not overlap, or
one account can use another's namespace and corrupt it (podman's rootless
tutorial). The role therefore computes a plan before it writes anything:

| Answer | Meaning | What the role does |
|---|---|---|
| `OK` | one range, in both files, large enough, no overlap | nothing |
| `ADD` | the account is in neither file | adds the first free block at or after `podman_subuid_start` |
| `CONFLICT`, `SMALL`, `MISMATCH`, `HALF`, `MULTI` | the account holds a range it cannot use | fails the run, naming the reason |
| `NOFREE` | no aligned block is free below 2^32 | fails the run |
| `BADARG name\|count\|base` | the invocation cannot produce a safe block: a name the files cannot hold, a count outside 1…1 048 576, a base below 100000 or past 2^32 | fails the run |
| `BADLINE uid\|gid\|passwd\|group <line>` | a line of one of the four files cannot be read | fails the run |

A candidate block must be free of three things: another account's ranges in both
files, **and** any UID `/etc/passwd` declares, **and** any GID `/etc/group`
declares. On a host whose accounts start above 100000 the last two are what keep
the block from mapping a real account's UID into every container. The count is
capped at 1 048 576 (sixteen default blocks) for the same reason.

A site that accepts the repair declares `podman_subuid_repair: true`: the role
then removes **this account's** unusable ranges and adds the block the plan
names (`usermod --del-subuids`/`--add-subuids`), runs `podman system migrate` as
the account so its pause process adopts the mapping, then asserts that
`/proc/self/uid_map` and `/proc/self/gid_map` contain the block. It never
touches another account's line. `podman_subid_nsswitch_file` is read too. A host that delegates `subid:` to an
NSS provider, or whose `passwd:`/`group:` list anything but `files` and
`systemd`, is refused: the plan reads the files, and `systemd` only fills the
dynamic range (61184-65519), which no subordinate block can contain.

`--check` does not report the identifiers: `usermod` and `podman system migrate`
are commands, so a dry run prints `changed=0` even when a real run would rewrite
the two files. Run the play once to converge them; the answer the plan returned
is in the failure message when it refuses.

### Default bounds

`quadlet_default_memory` and `quadlet_default_cpu_quota` give every container
unit a bound it does not declare itself (`MemoryMax=256M`, `CPUQuota=40%`). They
are written as a per-unit drop-in, and only while the unit omits the key: a
Quadlet drop-in wins over the unit file, so writing one beside a declared value
would invert the site's intent. Declaring the key in the unit removes the
drop-in; emptying a default removes it everywhere.

`Memory=` (the older systemd spelling) is not used: systemd 257 ignores it in a
`[Service]` section, and a unit that carried only `Memory=` ran unbounded
(measured: `MemoryMax=infinity`, 143 MB consumed).

## The base image

`images/base/Containerfile` is the image the site's containers start from: the
Debian minimal base pinned by digest, TLS roots, `tzdata`, `curl` for
healthchecks, `procps`, the Scripts interpreter (release 0.3.0, verified against
the release's `SHA256SUMS`), one non-root account (`app`, UID 1000), a locked
root, no setuid bit and no package list. It writes nothing outside a tmpfs,
which is what makes the read-only defaults of the Quadlet role usable.

```sh
podman build -t localhost/benmoussa/container:test images/base
podman run --rm localhost/benmoussa/container:test sh -c 'id; cat /etc/os-release'
```

The image is not built by the roles: the product ships the `Containerfile`, the
site runs the build on the machine that will hold the image. The Debian packages
inside keep their own licences (see `NOTICE`).

## The roles

| Role | Purpose | Status |
|---|---|---|
| `account` | The login account the rootless engine runs as: the group, the account, its UID, GID, home and shell. The name, UID and GID are inventory values (`container`, 1500:1500 by default). It refuses to rewrite an existing identity and creates no subordinate ID, no linger and no engine configuration. | implemented |
| `podman` | The rootless engine for the account `account` creates: packages, the account's `containers.conf`, `registries.conf` and `policy.json` (`read_only`, bounded pids and nofile, `umask`, `crun`, the distribution's seccomp profile, the caller's user namespace, `pull_policy`, an enforcing short-name mode and a policy that accepts only the declared registries), user socket, the opt-in auto-update timer, linger and subordinate IDs. The read-back refuses a `vfs` store, a cgroup other than v2 and a backend other than netavark. It creates no container and never enables the rootful socket. | implemented |
| `quadlet` | The site's Quadlet declarations (template names and drop-ins included), the published host-port floor, the product's global hardening drop-in, the refusal of keys that relax it and of the argument/sandbox keys whatever their value, a user-manager reload and a read-back of every generated unit and declared drop-in. It creates no image, volume, network, pod or container. | implemented |

`playbooks/site.yml` runs `account`, `podman` then `quadlet`, all opt-in with
`account_enabled`, `podman_enabled` and `quadlet_enabled`. The account comes
first because the engine's identifiers and linger target it; the declarations
come last because a generated user unit needs the account, its linger and its
engine.

### Quadlet declarations

`quadlet_units` is a list; each entry is one file in the owning account's
generator directory (`~/.config/containers/systemd/`):

| `type` | File written | User unit generated |
|---|---|---|
| `container` | `<name>.container` | `<name>.service` |
| `volume` | `<name>.volume` | `<name>-volume.service` |
| `network` | `<name>.network` | `<name>-network.service` |
| `pod` | `<name>.pod` | `<name>-pod.service` |
| `image` | `<name>.image` | `<name>-image.service` |
| `build` | `<name>.build` | `<name>-build.service` |
| `kube` | `<name>.kube` | `<name>-kube.service` |

The role does not trust that table: after the reload it reads every declared
unit back with `systemctl --user cat <unit>`, so a declaration the generator
ignored fails the run. `state: absent` removes the file, the two bound drop-ins
the product wrote beside it, and reloads the manager.

An entry may also carry `dropins`: a list of `{name, content}` files written
into `<name>.<type>.d/`. Quadlet reads every `.conf` file there and merges it
into the generated unit, which is the narrow way to relax one property without
emptying `quadlet_forbidden` for every unit. The role refuses a name that does
not end in `.conf` or that the product owns (`quadlet_product_dropins`), keeps
the list it wrote in `<name>.<type>.d/.ansible-managed.json` (a name Quadlet
ignores), removes a drop-in the site stops declaring, and reads every declared
drop-in back through `systemctl --user cat`.

A `container` or `kube` unit must carry `[Install]` with `WantedBy=` or
`RequiredBy=`: Quadlet applies that section at generation and starts nothing at
boot without it, so a unit the product accepted would never come back after a
reboot. A unit another one starts declares `boot: false` instead. Two
declarations may not share a name and a type, and `quadlet_hardened_defaults:
false` removes the drop-in instead of leaving it behind.

A unit file is a string in the inventory. A site that needs a secret keeps it in
its own vault and passes it as a `Secret=` entry of its unit; the product stores
no secret.

```yaml
quadlet_units:
  - name: example
    type: container
    content: |
      [Unit]
      Description=Example service

      [Container]
      Image=docker.io/library/alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
      Exec=sleep infinity

      [Install]
      WantedBy=default.target
    dropins:
      - name: 50-nofile.conf
        content: |
          [Container]
          LimitNOFILE=8192
```

### Hardening defaults

`quadlet_hardened_defaults: true` writes
`container.d/10-container-edition.conf` in the account's generator directory.
Quadlet merges it into every `.container` file; a unit's own drop-in
(`<name>.container.d/`) is merged after it and wins. Relax one key by declaring
it in that unit's `dropins`, not by editing the product's file. The
argument/sandbox keys (`quadlet_forbidden_prefixes`) stay refused there too:
they bypass the hardening drop-in rather than relax one property.

`quadlet_forbidden` names the keys a declared unit may not carry while the
defaults are on. Empty it deliberately if a site needs one.

## What the product does not do

- It does not enable the rootful Podman socket, and it does not write
  `/etc/containers/systemd`.
- It does not build an image: it ships the base `Containerfile`, and the site
  runs `podman build`. It does not pull, start or stop a container, a pod, a
  volume or a network.
- It does not set a password, a key or a privilege on the account it creates:
  the password stays locked, and the site owns the keys and the `sudo` rule.
- It does not store a secret, a registry credential or a site definition.
- It does not manage a firewall port for a unit: the site that publishes a port
  declares it. It refuses a declared `PublishPort` whose host port is below the
  host's `net.ipv4.ip_unprivileged_port_start` (read from the kernel when
  `quadlet_unprivileged_port_start` is empty): lower that sysctl or publish a
  higher port.
- It does not require a digest on a `.kube` unit (its images live in the YAML)
  or a `.build` unit (it names a Containerfile the site owns): the digest rule
  covers `.container` and `.image`, where `image_digest: false` is the opt-out.
  `AutoUpdate=registry` needs the `podman-auto-update.timer`: the role enables
  it when `podman_auto_update: true`.
- It does not put a secret in a unit: `quadlet_units` is written `0644` and is
  not scanned for credentials; keep a credential in the site's vault and hand it
  to the container through the unit's own mechanism.
- It waits up to 30 s for `/run/user/<uid>` after enabling linger; a slower host
  fails the run instead of waiting longer.
- The gate's wiring checks are greps and `--check` runs; the applied paths
  (subordinate IDs, linger, socket, Quadlet generation) are proven by the
  sandbox converge, not by the gate.
- `--check` cannot report an identifier change (`usermod`, `loginctl`): only a
  real converge proves it, and a real converge is the only proof of idempotence.

## Project status

`0.3.0` plans the subordinate IDs the edition collections used to own and
refuses an unsupported host edition; `0.1.0` was the first release. Debian is
the only supported base; a newer Debian release is added when the Server
collection declares it. The product is maintained by one author; there is no
support contract, service level or warranty, express or implied (see
[`CONTRIBUTING.md`](https://github.com/benmoussa-younes/container/blob/main/CONTRIBUTING.md) and [`SECURITY.md`](https://github.com/benmoussa-younes/container/blob/main/SECURITY.md)).

## Forking

A fork is welcome. You maintain it: the licence grants use, study, change and
redistribution, and the collection is delivered **as is**, without warranty or
support beyond the licence.

## Support

- A defect or a question: the repository's Issues are disabled; write to the
  address in [`SECURITY.md`](https://github.com/benmoussa-younes/container/blob/main/SECURITY.md).
- A security report: **not** a public issue — follow [`SECURITY.md`](https://github.com/benmoussa-younes/container/blob/main/SECURITY.md).
- The gate and the release process are described in [`AGENTS.md`](https://github.com/benmoussa-younes/container/blob/main/AGENTS.md).

## Licence

The product code is `AGPL-3.0-or-later`; the documentation is `CC-BY-SA-4.0`.
`NOTICE` states the layers and `REUSE.toml` maps every path. `reuse lint` proves
the map. The base image's Debian packages keep their own licences.

## Contributing and security

External contributions are not accepted at this time; unsolicited pull requests
or patches may be closed without review. No support, service level or warranty
is provided beyond the licences. See [`CONTRIBUTING.md`](https://github.com/benmoussa-younes/container/blob/main/CONTRIBUTING.md) for
the maintainer workflow and the private vulnerability report in
[`SECURITY.md`](https://github.com/benmoussa-younes/container/blob/main/SECURITY.md).
