#!/usr/bin/env bash
# Tier addressing scheme.
#
# A container's numeric ID encodes its address and its role, so there is no
# separate mapping file to drift out of sync with reality:
#
#   CT XYZ  ->  10.<net>.X.YZ
#
#   X   the tier (a service stack: one application and its dependencies)
#   YZ  the role within the tier, by convention:
#         00  edge     the tier's gateway; the only member with a public route
#         10  database
#         11  application
#         12+ additional members
#
# So CT 410 is tier 4's database at 10.<net>.4.10, and CT 400 is its gateway.
# Reading an ID tells you both where a container sits and what it does, which
# matters at 3am far more than it does while designing the scheme.

# No `set -e` here. This file is sourced, so any shell option it sets leaks into
# the caller: with `set -e` in place, a caller testing a function's return value
# would be killed by the first expected failure instead of handling it. Scripts
# that want strict mode set it themselves.

: "${NET_PREFIX:=10.10}"

# Split a container ID into its tier and member parts.
ct_tier() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    printf '%d' "$((ct / 100))"
}

ct_member() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    printf '%d' "$((ct % 100))"
}

ct_ip() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    printf '%s.%d.%d' "$NET_PREFIX" "$((ct / 100))" "$((ct % 100))"
}

# Every tier member routes through its own edge, so the gateway is derivable.
ct_gateway() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    printf '%s.%d.0' "$NET_PREFIX" "$((ct / 100))"
}

ct_role() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    case "$((ct % 100))" in
        0)  printf 'edge' ;;
        10) printf 'database' ;;
        11) printf 'app' ;;
        *)  printf 'member' ;;
    esac
}

ct_is_edge() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    [[ $((ct % 100)) -eq 0 ]]
}

# An edge owns the tier's whole /24. A member takes a /32 and reaches everything
# else through the edge, so a compromised application container cannot address
# its neighbours directly even within its own tier.
ct_cidr() {
    local ct="$1"
    _require_ct_id "$ct" || return 2
    if ct_is_edge "$ct"; then
        printf '%s/24' "$(ct_ip "$ct")"
    else
        printf '%s/32' "$(ct_ip "$ct")"
    fi
}

_require_ct_id() {
    local ct="${1:-}"
    if [[ ! $ct =~ ^[0-9]+$ ]]; then
        printf 'tiers: container id must be numeric, got %q\n' "$ct" >&2
        return 2
    fi
    # Proxmox reserves IDs below 100, and the scheme needs three digits so that
    # the tier and member are unambiguous.
    if (( ct < 100 || ct > 99999 )); then
        printf 'tiers: container id %s is out of range (100-99999)\n' "$ct" >&2
        return 2
    fi
    if (( ct % 100 > 99 )); then
        printf 'tiers: container id %s has an invalid member part\n' "$ct" >&2
        return 2
    fi
}
