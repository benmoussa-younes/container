# AGENTS.md — Container

## Build and test

```sh
ansible-lint playbooks roles
yamllint -c .yamllint roles playbooks inventories
reuse lint
scripts check tools/scripts/binaries/gate.scs
scripts run tools/scripts/binaries/gate.scs      # one VERDICT line, exit 0/1
```

The gate is the repository's single entry point. It checks the tree, the
version, the licences, the collection archive and the legacy names. It does not
change tracked files.

## Repository facts

- The collection is `benmoussa.container`, version `0.1.0`.
- The product code is `AGPL-3.0-or-later`; the documentation is
  `CC-BY-SA-4.0`.
- Only `ansible.builtin` is used; `requirements.yml` declares no collection.
- There is no `docs/` and no `.opencode/`: the plan and the board live outside
  the repository.
- A release is a signed tag `v<version>` and three assets: the collection
  tarball, the source tarball and `SHA256SUMS`.
- The engine is rootless only. The rootful socket is never enabled, and
  `/etc/containers/systemd` is never written.
- The product ships one image, the base `images/base/Containerfile`, and no
  definition: a site owns its ports, volumes, networks and secrets.

## Maintenance

- Keep `VERSION`, `galaxy.yml` and `CHANGELOG.md` on the same version.
- A role keeps its `meta/argument_specs.yml` contract and its idempotence.
- No site data in a role: an address, a host name, a registry credential or a
  secret belongs in the site inventory.
- `quadlet` reads every declared unit back with `systemctl --user cat`; a
  declaration the generator ignores is a failure, not a warning.
