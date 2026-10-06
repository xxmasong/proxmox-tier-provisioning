# xenit-infra

Provisioning scripts for a tiered Proxmox LXC estate, where a container's ID
encodes both its address and its role.

Built from running a multi-tier self-hosted stack — Postgres, reverse proxies,
ERP, CI and a dozen application containers — on nested Proxmox hosts. The
addressing scheme and the backup-verification habit are the two things that
repaid the effort most, so they are what this packages.

## The addressing scheme

```
CT XYZ  ->  10.<net>.X.YZ

  X   the tier: one application and its dependencies
  YZ  the role within that tier
        00  edge      the tier's gateway, the only member with a public route
        10  database
        11  application
        12+ further members
```

So `CT 410` is tier 4's database at `10.10.4.10`, reached through `CT 400` at
`10.10.4.0`. Reading an ID tells you where a container sits and what it does,
with no inventory file to drift out of sync with reality — which matters far more
at 3am than it does while designing the scheme.

```bash
$ source lib/tiers.sh
$ ct_ip 410;  ct_role 410;  ct_gateway 410
10.10.4.10
database
10.10.4.0
```

The edge owns the tier's `/24`; every other member takes a **`/32` plus an
explicit gateway**, so a compromised application container cannot address its
neighbours directly even inside its own tier.

## Provisioning

```bash
bin/provision-ct 410 --role database --memory 4096 --disk 32
bin/provision-ct 400 --dry-run        # print the commands, change nothing
```

Everything is derived from the ID, so the common case needs no flags. Defaults
are sized by role rather than uniformly — a database gets memory for its shared
buffers, an edge is a router and gets almost nothing.

It is **idempotent**: against an existing container it reconciles the settings it
manages via `pct set` and leaves the rest alone, so an edit is a re-run rather
than a destroy-and-recreate.

## Backup verification

A dump you have never test-restored is not a backup.

```bash
bin/verify-backup latest --ct 410 --check 'pg_isready -U postgres'
```

This restores the archive into a scratch container, waits for it to come up, runs
the check inside it, and destroys it again — on failure as well as success, via an
`EXIT` trap, because a half-restored container left behind will trip up the next
run. Without `--check` it reports that only the restore itself was verified,
rather than implying more than it tested.

## Tests

```bash
tests/test_tiers.sh        # 26 assertions
shellcheck -x bin/* lib/*.sh tests/*.sh
```

### Two bash traps the tests caught

Both are the kind of thing that works until it doesn't:

1. **A sourced library must not `set -e`.** `lib/tiers.sh` originally began with
   `set -euo pipefail`. Because the file is *sourced*, those options leak into
   the caller — so the test script was killed by the first deliberately-invalid
   input instead of asserting on it. A library leaves shell options to its caller.

2. **A bare call inside a command substitution does not trip `set -e`.**
   `ct_tier "$CT" >/dev/null` was meant to validate the ID and abort, but the
   failure was swallowed: the error printed and provisioning carried on with an
   empty address. It needs an explicit `|| die`.

## Layout

```
lib/
  tiers.sh         address and role derivation from a container ID
  log.sh           logging, colour only when stderr is a terminal
bin/
  provision-ct     create or reconcile one container
  verify-backup    restore-and-check a backup in a scratch container
tests/
  test_tiers.sh    assertions for the addressing scheme
```

## Scope and limits

- **Proxmox LXC only.** No VM support, and nothing here is cloud-portable; it
  targets bare-metal or VPS Proxmox hosts.
- `provision-ct` reconciles hostname, memory, cores, network and `onboot`. It
  does **not** reconcile disk size, since shrinking a volume is not a safe
  automatic action.
- No secret management. Credentials belong in a store the host already has, not
  in these scripts.
- Addresses and names in this repository are illustrative. A real deployment
  supplies its own via `NET_PREFIX`, `TEMPLATE`, `STORAGE` and `BRIDGE`.
- Single-host. Clustered Proxmox would need the node name threaded through every
  `pct` call.

## Licence

MIT
