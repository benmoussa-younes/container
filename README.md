# Container

[![Release](https://img.shields.io/badge/release-0.1.0-blue)](https://github.com/benmoussa-younes/container/releases/tag/v0.1.0)
[![Licence](https://img.shields.io/badge/licence-AGPL--3.0--or--later-blue)](LICENSE)
[![CI](https://github.com/benmoussa-younes/container/actions/workflows/ci.yml/badge.svg)](https://github.com/benmoussa-younes/container/actions/workflows/ci.yml)

Ansible roles that install a **rootless Podman engine** on a **Debian** host,
write the **Quadlet** declarations a site owns and ship the **base image** those
declarations run on. The product owns the engine, the generator's input and the
base; the definitions themselves — ports, volumes, networks, secrets — remain
the site's.

It installs on a host that already carries an edition — Server Edition or
Workstation Edition — and it **owns no identity**: no `os-release`, no login
banner, no boot splash, no version line of its own. The edition says what the
machine is; this collection says what it runs. It is shipped as the collection
`benmoussa.container`.

## What it does

- **One rootless engine**: packages, registry search path, the engine's
  drop-in, the user socket, linger and subordinate IDs. The rootful socket is
  never enabled and `/etc/containers/systemd` is never written.
- **The engine's defaults, decided**: Debian leaves `no_new_privileges` off,
  the log size unbounded and the pids limit at 1024. The product turns the
  first on, bounds the other two, sets `umask` 0077 and names the `crun`
  runtime.
- **The site's Quadlet declarations**: `container`, `volume`, `network`, `pod`,
  `image`, `build` and `kube` files in the owning account's generator
  directory, a user-manager reload and a read-back of every generated unit.
- **A hardening baseline in one drop-in**: `container.d/*.conf` is merged into
  every container unit of the account — no new privileges, all capabilities
  dropped, read-only rootfs with tmpfs, an init, pids and ulimit bounds,
  journald logs. A unit's own drop-in still wins.
- **A refusal, not a warning**: a declared unit that carries `Network=host`,
  `User=0`, `NoNewPrivileges=false`, `ReadOnly=false` or
  `SecurityLabelDisable=true` fails the run while the hardened defaults are on.
- **A base image**: the Debian minimal base pinned by digest, TLS roots,
  `tzdata`, `curl`, `procps` and the Scripts interpreter, one non-root
  account, a locked root, no setuid bit and a branded os-release.

## Requirements

- a target running **Debian 13** (`trixie`), the release both editions support
  today, with the engine packages taken from the distribution;
- `ansible-core` **2.19 or later** on the controller, with SSH access to the
  target;
- an existing human account that will own the rootless engine; the product
  creates no account;
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
ansible-galaxy collection install benmoussa-container-0.1.0.tar.gz
```

Or, from the signed tag:

```sh
ansible-galaxy collection install \
  git+https://github.com/benmoussa-younes/container.git,v0.1.0
```

The release also carries `container-0.1.0-src.tar.gz` (the source tree with the
example inventory and the repository tooling) and `SHA256SUMS`. Verify the
checksums before installing:

```sh
sha256sum -c SHA256SUMS
```

## Quick start

Create the site inventory from the source archive's `inventories/example/`, or
write a minimal one:

```yaml
all:
  vars:
    ansible_user: debian
    ansible_python_interpreter: /usr/bin/python3

    # The engine. The account must already exist; `quadlet` follows it.
    podman_enabled: true
    podman_user: "{{ ansible_user }}"
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

## The base image

`images/base/Containerfile` is the image the site's containers start from: the
Debian minimal base pinned by digest, TLS roots, `tzdata`, `curl` for
healthchecks, `procps`, the Scripts interpreter (release 0.1.2, verified against
the release's `SHA256SUMS`), one non-root account (`app`, UID 1000), a locked
root, no setuid bit and no package list. It writes nothing outside a tmpfs,
which is what makes the read-only defaults of the Quadlet role usable.

```sh
podman build -t localhost/benmoussa/container:0.1.0 images/base
podman run --rm localhost/benmoussa/container:0.1.0 sh -c 'id; cat /etc/os-release'
```

The image is not built by the roles: the product ships the `Containerfile`, the
site runs the build on the machine that will hold the image. The Debian packages
inside keep their own licences (see `NOTICE`).

## The roles

| Role | Purpose | Status |
|---|---|---|
| `podman` | The rootless engine for one existing non-root account: packages, registry search path, engine drop-in with the product's defaults, user socket, linger and subordinate IDs. It creates no container and never enables the rootful socket. | implemented |
| `quadlet` | The site's Quadlet declarations, the product's global hardening drop-in, the refusal of keys that relax it, a user-manager reload and a read-back of every generated unit. It creates no image, volume, network, pod or container. | implemented |

`playbooks/site.yml` runs `podman` then `quadlet`, both opt-in with
`podman_enabled` and `quadlet_enabled`. The declarations come second because a
generated user unit needs the owning account, its linger and its engine first.

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
ignored fails the run. `state: absent` removes the file and reloads the manager.

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
      Image=docker.io/library/alpine:3.20
      Exec=sleep infinity

      [Install]
      WantedBy=default.target
```

### Hardening defaults

`quadlet_hardened_defaults: true` writes
`container.d/10-container-edition.conf` in the account's generator directory.
Quadlet merges it into every `.container` file; a unit's own drop-in
(`<name>.container.d/`) is merged after it and wins. Relax one key by adding
that drop-in beside the unit, not by editing the product's file.

`quadlet_forbidden` names the keys a declared unit may not carry while the
defaults are on. Empty it deliberately if a site needs one.

## What the product does not do

- It does not enable the rootful Podman socket, and it does not write
  `/etc/containers/systemd`.
- It does not build an image: it ships the base `Containerfile`, and the site
  runs `podman build`. It does not pull, start or stop a container, a pod, a
  volume or a network.
- It does not create or modify an account.
- It does not store a secret, a registry credential or a site definition.
- It does not manage a firewall port for a unit: the site that publishes a port
  declares it.

## Project status

`0.1.0` is the first release. Debian is the only supported base; a newer Debian
release is added when the Server collection declares it. The product is
maintained by one author; there is no support contract, service level or
warranty, express or implied (see [`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`SECURITY.md`](SECURITY.md)).

## Support

- A defect or a question: open an issue on
  [GitHub](https://github.com/benmoussa-younes/container/issues).
- A security report: **not** a public issue — follow [`SECURITY.md`](SECURITY.md).
- The gate and the release process are described in [`AGENTS.md`](AGENTS.md).

## Licence

The product code is `AGPL-3.0-or-later`; the documentation is `CC-BY-SA-4.0`.
`NOTICE` states the layers and `REUSE.toml` maps every path. `reuse lint` proves
the map. The base image's Debian packages keep their own licences.

## Contributing and security

External contributions are not accepted at this time; unsolicited pull requests
or patches may be closed without review. No support, service level or warranty
is provided beyond the licences. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for
the maintainer workflow and the private vulnerability report in
[`SECURITY.md`](SECURITY.md).
