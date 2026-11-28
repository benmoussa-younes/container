# Roles

One role per concern. A role is `implemented` when it has its defaults, its
argument spec, its tasks and its gate; `planned` when it has a contract only.

| Role | Purpose | Status |
|---|---|---|
| `account` | The login account the rootless engine runs as: the group, the account, its UID, GID, home and shell. The name, UID, GID, home and shell are inventory values (`container`, 1500:1500 by default); the role refuses to rewrite an existing identity, and it creates no subordinate ID, no linger and no engine configuration. | implemented |
| `podman` | The rootless Podman engine for the account `account` creates: packages, registry search path, engine drop-in with the product's defaults (`no_new_privileges`, bounded pids, umask, crun), user socket, the auto-update timer (opt-in), linger and subordinate IDs (planned from both files, refused when another account holds the same range, repaired only on request, then read back from the kernel). It reads `container_host_edition` (`server` only) and refuses an absent or unsupported value; it removes the retired `99-podman.conf` before writing its own `99-container-podman.conf`, so one file owns each configuration. It creates no container and never enables the rootful socket. | implemented |
| `quadlet` | The site's Quadlet declarations: unit files (template names included) in the owning account's generator directory, the published host-port floor, the product's global hardening drop-in (`NoNewPrivileges`, capabilities dropped, read-only, init, bounds), the refusal of keys that relax it, a user-manager reload and a read-back of every generated unit. It creates no image, volume, network, pod or container. | implemented |

`playbooks/site.yml` runs `account`, `podman` then `quadlet`, all opt-in with
`account_enabled`, `podman_enabled` and `quadlet_enabled`. The account comes
first because the engine's subordinate IDs and linger target it; the
declarations come last because a generated user unit needs the account, its
linger and its engine.
