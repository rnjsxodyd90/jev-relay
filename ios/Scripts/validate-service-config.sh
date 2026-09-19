#!/bin/sh
set -eu
# Distribution config only: Debug and ordinary Release remain buildable with no live service.
[ "${CONFIGURATION:-}" = "AppStore" ] || exit 0
fail=0
for key in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY RELAY_BACKEND_URL PRIVACY_POLICY_URL SUPPORT_URL; do
  eval "value=\${$key:-}"
  case "$value" in
    ""|*YOUR_*|*PLACEHOLDER*|*example.com*|*localhost*|*127.0.0.1*)
      echo "error: $key must be a non-placeholder production value for AppStore builds." >&2; fail=1 ;;
  esac
done
[ "$fail" -eq 0 ] || exit 1
case "$SUPABASE_URL" in https://*) ;; *) echo "error: SUPABASE_URL must use HTTPS." >&2; exit 1;; esac
case "$RELAY_BACKEND_URL" in https://*) ;; *) echo "error: RELAY_BACKEND_URL must use HTTPS." >&2; exit 1;; esac
case "$PRIVACY_POLICY_URL" in https://*) ;; *) echo "error: PRIVACY_POLICY_URL must use HTTPS." >&2; exit 1;; esac
case "$SUPPORT_URL" in https://*) ;; *) echo "error: SUPPORT_URL must use HTTPS." >&2; exit 1;; esac
