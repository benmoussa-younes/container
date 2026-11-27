# Security policy

## Supported versions

| Version | Supported |
|---|---|
| 0.3.x | yes |
| older | no |

A release is supported until a later release explicitly withdraws it. Debian is
the supported base; a future Debian release is added when the product declares
it.

Security fixes are considered on a **best-effort** basis for the current 0.3.x
tree. There is no long-term support branch, support contract, response-time
guarantee or warranty, express or implied. The product is distributed under
**AGPL-3.0-or-later** and the documentation under **CC-BY-SA-4.0**, without
warranty, as stated in [`LICENSE`](LICENSE) and `LICENSES/`.

## Reporting a vulnerability

Do not open a public issue. Report it privately to:

**younes.benmoussa@pm.me**

Include:

- the product version (`cat VERSION`);
- the role and task, or the file and line;
- the affected Debian release;
- a reproduction, if it is safe to share;
- the impact you believe it has.

We aim to acknowledge a report within five business days. A fix and a disclosure
date are agreed with the reporter. If you need an encrypted channel, ask for the
current security contact key in the first message.

## Scope

In scope:

- the roles in `roles/`, the playbook, the collection archive and the
  repository tooling;
- the engine configuration the role writes: registry search path, engine
  drop-in, user socket, linger and subordinate IDs;
- a defect that makes a correct machine fail or a converge unsafe.

Out of scope:

- any image, container, pod, volume, network or unit file a site declares;
- the services a site adds, including a published port;
- the site's network, registry or Debian mirror;
- a host that is not Debian;
- a site inventory or vault that was edited outside the documented workflow.

## What the product does not do

- It does not enable the rootful Podman socket.
- It does not pull, build, start or stop a container.
- It does not store a registry credential or a secret.
- It does not send telemetry.
- It does not manage a firewall port.

## Hardening baseline

The product declares:

- a rootless engine owned by one existing non-root account, never `root`;
- the rootful socket left disabled;
- subordinate UID and GID ranges planned from `/etc/subuid` and `/etc/subgid`:
  a range another account holds, a range shorter than the declared count, a
  range in one file only or two ranges in one file fail the run; the repair
  removes only this account's ranges and is opt-in (`podman_subuid_repair`);
- one configuration drop-in per concern, named `99-container-podman.conf`, so
  the product never overwrites a site's own file.

Two facts a reader must not infer from this list:

- the engine's own isolation is the Linux user namespace and the default seccomp
  profile; `NoNewPrivileges`, an empty capability set and a read-only rootfs come
  from the Quadlet drop-in, so a **unit the product generated** carries them and
  a container started by hand does not. On Debian 13 rootless, **no LSM confines
  a container**: `podman info` reports `apparmorEnabled: false` and SELinux is not
  the base's security module. A unit that needs more must say so itself;
- `podman.socket` is enabled by default, and that API is root-equivalent **for
  the owning account**: any process of that account can start a container that
  mounts the host's files. Disable it with `podman_socket_enabled: false` on a
  host where the account runs untrusted code.

The exact values are in `roles/*/defaults/main.yml` and the role comments.
