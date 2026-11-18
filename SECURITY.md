# Security policy

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | yes |
| older | no |

A release is supported until a later release explicitly withdraws it. Debian is
the supported base; a future Debian release is added when the product declares
it.

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
- subordinate UID and GID ranges that must exist together, with a collision
  refused rather than overwritten;
- one configuration drop-in per concern, named `99-container-podman.conf`, so
  the product never overwrites a site's own file.

The exact values are in `roles/*/defaults/main.yml` and the role comments.
