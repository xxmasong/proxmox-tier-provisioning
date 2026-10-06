#!/usr/bin/env bash
# Tests for the tier addressing scheme.
#
#   tests/test_tiers.sh

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # consumed by the sourced library below
NET_PREFIX=10.10
# shellcheck source=../lib/tiers.sh
source "${SCRIPT_DIR}/../lib/tiers.sh"

PASS=0
FAIL=0

check() {
    local label="$1" expected="$2" actual="$3"
    if [[ $expected == "$actual" ]]; then
        PASS=$((PASS + 1))
        printf '  ok   %s\n' "$label"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL %s\n       expected %q\n       got      %q\n' \
            "$label" "$expected" "$actual"
    fi
}

check_fails() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        printf '  FAIL %s (expected a non-zero exit)\n' "$label"
    else
        PASS=$((PASS + 1))
        printf '  ok   %s\n' "$label"
    fi
}

echo "tier and member decomposition"
check "tier of 410"            "4"   "$(ct_tier 410)"
check "member of 410"          "10"  "$(ct_member 410)"
check "tier of 400"            "4"   "$(ct_tier 400)"
check "member of 400"          "0"   "$(ct_member 400)"
check "tier of 1011"           "10"  "$(ct_tier 1011)"
check "member of 1011"         "11"  "$(ct_member 1011)"

echo "address derivation"
check "ip of 410"              "10.10.4.10"  "$(ct_ip 410)"
check "ip of 400"              "10.10.4.0"   "$(ct_ip 400)"
check "ip of 411"              "10.10.4.11"  "$(ct_ip 411)"
check "ip of 213"              "10.10.2.13"  "$(ct_ip 213)"
check "gateway of 411"         "10.10.4.0"   "$(ct_gateway 411)"
check "gateway of an edge is itself" "10.10.4.0" "$(ct_gateway 400)"

echo "the network prefix is configurable"
check "ip of 410 under 172.20" "172.20.4.10" "$(NET_PREFIX=172.20 ct_ip 410)"

echo "roles"
check "role of 400"            "edge"      "$(ct_role 400)"
check "role of 410"            "database"  "$(ct_role 410)"
check "role of 411"            "app"       "$(ct_role 411)"
check "role of 412"            "member"    "$(ct_role 412)"

echo "edge detection"
if ct_is_edge 400; then PASS=$((PASS+1)); echo "  ok   400 is an edge"
else FAIL=$((FAIL+1)); echo "  FAIL 400 should be an edge"; fi
if ct_is_edge 410; then FAIL=$((FAIL+1)); echo "  FAIL 410 should not be an edge"
else PASS=$((PASS+1)); echo "  ok   410 is not an edge"; fi

echo "CIDR assignment"
# The edge owns the tier subnet; a member gets a /32 so it cannot address its
# neighbours directly.
check "edge takes the /24"     "10.10.4.0/24"  "$(ct_cidr 400)"
check "member takes a /32"     "10.10.4.10/32" "$(ct_cidr 410)"

echo "validation"
check_fails "a non-numeric id is rejected"  ct_ip abc
check_fails "an empty id is rejected"       ct_ip ""
check_fails "an id below 100 is rejected"   ct_ip 99
check_fails "a negative id is rejected"     ct_ip -5
check_fails "an oversized id is rejected"   ct_ip 100000

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
