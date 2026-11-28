# Contributing

Container is a set of Ansible roles that install a rootless Podman engine and
write the Quadlet declarations a site owns. A change is accepted when it keeps
that promise and passes the gate.

## Before you write

- Read `roles/README.md`: one role per concern, one catalog entry per role.
- Keep the invariants: rootless only, Debian, systemd end to end,
  fully-qualified modules, no site data, idempotence. `AGENTS.md` states them.
- A unit definition is the site's, not the product's. A change that adds an
  image name, a port, a volume or a secret belongs in the site repository.

## External contributions

External contributions are **not accepted at this time**. The collection is
maintained by the owner; unsolicited pull requests, patches and issues may be
closed without review. This policy does not limit the rights the licences grant you:
the source is free software, and you may fork it and modify it under the licence
terms.

## Support and warranty

No support, service level or warranty is provided, express or implied. The
product is distributed under **AGPL-3.0-or-later** and the documentation under
**CC-BY-SA-4.0**, without warranty, as stated in [`LICENSE`](LICENSE),
`LICENSES/` and `NOTICE`. The base image contains Debian packages and the Scripts interpreter, each under its own licence; the product neither redistributes them as its own work nor relicenses them. You are responsible for your deployment and
for complying with the licences when you redistribute or modify the code.

## What a change must carry

1. **A reason that survives a reboot.** A value is declared because the machine
   must have it, not because a blog post did. A measurement names the date and
   the command.
2. **A read-back.** A role that writes a value asserts the running system took
   it. Writing a file is not proof: the Quadlet role reads every generated unit
   back from the user manager.
3. **No site data.** No address, host name, registry credential, secret or
   customer name. The example inventory carries documentation values only.
4. **A second run that changes nothing.** Idempotence is a gate, not a goal.

## Lint configuration

The four `tests/sanity/ignore-2.*.txt` files are identical on purpose: every
`tools/**/*.scs` carries a shebang `ansible-test` does not know, and the same
lines apply to each supported `ansible-core` version. The gate checks that each
file names every script.

`.ansible-lint` skips `name[template]` because role task names intentionally
carry the loop variable, warns `var-naming[no-role-prefix]` because the
collection's variables are prefixed by role (`podman_`, `quadlet_`, `account_`)
rather than by the rule's expected pattern, and `.yamllint` disables
`comments-indentation` for the legacy comment blocks (the code is being purged
of comments, after which the rule can return).

## The gate

Run from the repository root; a change is not done until it passes:

```sh
for script in tools/scripts/binaries/*.scs; do scripts check --deny-warnings "$script"; done
for module in tools/scripts/modules/*.scs; do scripts check --module --deny-warnings "$module"; done
scripts run --no-warnings tools/scripts/binaries/gate.scs
```

The gate is the single entry point: it runs `ansible-lint`, `yamllint`,
`reuse lint`, the syntax check, the secret scan, the archive and the proofs.
The two loops check the Scripts interpreter itself, which the gate does not
re-enter. `requirements-dev.txt` pins the Python tools (the CI installs them;
`ansible-core` follows the matrix), and the Scripts release is pinned by URL and
SHA in the workflows.

A change that touches the engine, the socket or the subordinate IDs is **not**
proven by `--check`. Say what was measured, on which machine.

## Commits

- One branch per task, `work/<slug>`.
- English, imperative subject; the body says **why**, not what the diff shows.
- One concern per commit.
- Do not commit an artifact (`dist/`, `artifacts/`), a vault or a site
  inventory.

## Licence of a contribution

The product is `AGPL-3.0-or-later`; the documentation is `CC-BY-SA-4.0`. By
sending a change you agree that it is distributed under those terms.

## Reporting a vulnerability

Do not open a public issue. Follow `SECURITY.md`.
