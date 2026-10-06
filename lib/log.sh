#!/usr/bin/env bash
# Logging helpers. Colour only when stderr is a terminal, so captured output and
# CI logs stay free of escape codes.

if [[ -t 2 ]]; then
    _C_INFO=$'\033[36m'; _C_OK=$'\033[32m'; _C_WARN=$'\033[33m'
    _C_ERR=$'\033[31m';  _C_OFF=$'\033[0m'
else
    _C_INFO=''; _C_OK=''; _C_WARN=''; _C_ERR=''; _C_OFF=''
fi

log_info() { printf '%s==>%s %s\n' "$_C_INFO" "$_C_OFF" "$*" >&2; }
log_ok()   { printf '%s ok%s %s\n' "$_C_OK"   "$_C_OFF" "$*" >&2; }
log_warn() { printf '%swarn%s %s\n' "$_C_WARN" "$_C_OFF" "$*" >&2; }
log_err()  { printf '%serr%s %s\n'  "$_C_ERR"  "$_C_OFF" "$*" >&2; }

die() { log_err "$*"; exit 1; }
