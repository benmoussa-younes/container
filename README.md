# Container

Ansible roles that install a **rootless Podman engine** on a **Debian** host,
write the **Quadlet** declarations a site owns and ship the **base image** those
declarations run on. The product owns the engine, the generator's input and the
base; the definitions themselves — ports, volumes, networks, secrets — remain
the site's.

It is the container counterpart of the Server and Workstation collections, and
it is shipped as the collection `benmoussa.container`, version `0.1.0`.

The engine is **rootless only**: one existing non-root account owns it, and the
rootful socket is never enabled. A site that declares units writes them here;
the definitions themselves stay in the site's inventory or its private
repository.

## The base image

`images/base/Containerfile` is the image the site's containers start from: the
Debian minimal base pinned by digest, TLS roots, `tzdata`, `curl` for
healthchecks, `procps`, the Scripts interpreter (release 0.1.2, verified against
the release's `SHA256SUMS`), one non-root account (`app`, UID 1000), a locked
root, no setuid bit and no package list. It writes nothing outside a tmpfs, which is
what makes the read-only defaults of the Quadlet role usable.

```sh
podman build -t localhost/benmoussa/container:0.1.0 images/base
podman run --rm localhost/benmoussa/container:0.1.0 sh -c 'id; cat /etc/os-release'
```

The image is not built by the roles: the product ships the `Containerfile`, the
site runs the build on the machine that will hold the image. The Debian packages
inside keep their own licences (see `NOTICE`).

## Requirements

- a target running **Debian**; the supported release is named in the Server
  collection's identity distribution table, and the engine packages come from
  the distribution;
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

## The roles

| Role | Purpose | Status |
|---|---|---|
| `podman` | The rootless engine: packages, registry search path, engine drop-in, user socket, linger and subordinate IDs. It creates no container. | implemented |
| `quadlet` | The site's Quadlet declarations: unit files, a user-manager reload and a read-back of every generated unit. It creates no image, volume, network or pod. | implemented |

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
its own vault and passes it as an `Environment=` or `Secret=` entry of its unit;
the product stores no secret.

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

## Project

The collection carries the roles, the playbook, `meta/` and the licence texts.
It does not carry an inventory: the site owns its inventory and its vault. The
source archive carries `inventories/example/`, which documents every variable
with TEST-NET-1 values only.

The product code is `AGPL-3.0-or-later`; the documentation is `CC-BY-SA-4.0`.
`NOTICE` states the layers and `REUSE.toml` maps every path. `reuse lint` proves
the map.

## Contributing and security

External contributions are not accepted at this time; unsolicited pull requests
or patches may be closed without review. No support, service level or warranty
is provided beyond the licences. See
[`CONTRIBUTING.md`](https://github.com/benmoussa-younes/container/blob/main/CONTRIBUTING.md)
for the maintainer workflow and the private vulnerability report in
[`SECURITY.md`](https://github.com/benmoussa-younes/container/blob/main/SECURITY.md).
