# AGENTS.md — Container

Ansible roles that install a rootless Podman engine on a Debian host, write the
site's Quadlet declarations and ship the base image. The product owns the
engine, the generator's input and the base; a port, a volume, a network and a
secret remain the site's. It is a capability, not an edition: it reads
`container_host_edition` and owns no identity.

## Build and test

```sh
for script in tools/scripts/binaries/*.scs; do scripts check --deny-warnings "$script"; done
for module in tools/scripts/modules/*.scs; do scripts check --module --deny-warnings "$module"; done
scripts run --no-warnings tools/scripts/binaries/gate.scs  # one VERDICT line, exit 0/1
```

The gate runs `ansible-lint`, `yamllint`, `reuse lint`, the syntax check, the
archive, the secret scan and the proofs; the two loops check the interpreter
itself. `requirements-dev.txt` pins the Python tools; the Scripts release is
pinned by URL and SHA in the workflows.

The sandbox converge runs on this host as root, with the become password file
the owner keeps; it creates the sandbox account, and the teardown is the
owner's:

```sh
ANSIBLE_BECOME_PASSWORD_FILE=~/.ansible/become scripts run tools/scripts/binaries/verify-sandbox.scs
```

The gate is the repository's single entry point: the tree, the version, the
licences, the collection archive and the secret shapes, then the linters and the
playbooks' syntax. It does not change tracked files.

The base image is not built by the gate:

```sh
podman build --timestamp 1795392000 \
  --build-arg VERSION="$(cat VERSION)" \
  --build-arg REVISION="$(git rev-parse HEAD)" \
  --build-arg CREATED="2026-11-23T00:00:00Z" \
  -t localhost/benmoussa/container:test images/base
```

## Conventions

- Rootless only: one non-root account owns the engine. `roles/account` creates
  it (`container`, uid/gid 1500 by default; name, UID, GID, home and shell are
  site values), and the rootful socket is never enabled and
  `/etc/containers/systemd` is never written.
- Only `ansible.builtin` is used; `requirements.yml` declares no collection.
- A role keeps its `meta/argument_specs.yml` contract and its idempotence, and
  reads its own change back (the Quadlet role reads every generated unit).
- No site definition in the product: an image name, a port, a volume or a
  secret belongs in the site inventory.
- Debian 13 ships Podman 5.4.2: a Quadlet key it does not know (`Umask=`) drops
  the whole unit. Check a new key against the installed version before using it.

## Repository facts

- The collection is `benmoussa.container`, version `0.3.0`.
- The product code is `AGPL-3.0-or-later`; the documentation is
  `CC-BY-SA-4.0`. The base image's Debian packages keep their own licences.
- A release is a signed tag `v<version>` and three assets: the collection
  tarball, the source tarball and `SHA256SUMS`.
- `roles/README.md` is the role catalog; `images/base/Containerfile` is the
  image the site's containers start from.

## Commits and releases

- One branch per task, `work/<slug>`; one concern per commit; English,
  imperative subject; the body says why.
- Commits and tags are GPG-signed. A change lands on `main` only when
  `tools/scripts/binaries/gate.scs` prints `VERDICT: PASS`; a release is the maintainer's decision.

## Security

- The engine's defaults are the product's: a read-only root, bounded pids and
  nofile, umask, the `crun` runtime, the distribution's seccomp profile, an
  image policy that accepts only the declared registries; the Quadlet role adds
  the hardening drop-in (which carries `NoNewPrivileges=true`) and refuses a
  unit that relaxes it.
- The base image carries a locked root, one non-root account, no setuid bit and
  no package list; the Scripts interpreter is verified against its release
  `SHA256SUMS`.
- No secret in a tracked file; the site keeps its credentials in its vault.
- A vulnerability report is private: follow `SECURITY.md`.

## Maintenance

- Keep `VERSION`, `galaxy.yml` and `CHANGELOG.md` on the same version.
