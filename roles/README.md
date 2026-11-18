# Roles

One role per concern. A role is `implemented` when it has its defaults, its
argument spec, its tasks and its gate; `planned` when it has a contract only.

| Role | Purpose | Status |
|---|---|---|
| `podman` | The rootless Podman engine for one existing non-root account: packages, registry search path, engine drop-in with the product's defaults (`no_new_privileges`, bounded pids and log size, umask, crun), user socket, linger and subordinate IDs. It creates no container and never enables the rootful socket. | implemented |
| `quadlet` | The site's Quadlet declarations: unit files in the owning account's generator directory, the product's global hardening drop-in (`NoNewPrivileges`, capabilities dropped, read-only, init, bounds), the refusal of keys that relax it, a user-manager reload and a read-back of every generated unit. It creates no image, volume, network, pod or container. | implemented |

`playbooks/site.yml` runs `podman` then `quadlet`, both opt-in with
`podman_enabled` and `quadlet_enabled`. The declarations come second because a
generated user unit needs the owning account, its linger and its engine first.
