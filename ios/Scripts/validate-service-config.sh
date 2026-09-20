#!/bin/sh
set -eu
# Distribution config contains public legal/support URLs only. User API keys belong only in Keychain.
[ "${CONFIGURATION:-}" = "AppStore" ] || exit 0
fail=0
for key in PRIVACY_POLICY_URL SUPPORT_URL; do
  eval "value=\${$key:-}"
  case "$value" in
    ""|*YOUR_*|*PLACEHOLDER*|*example.com*|*localhost*|*127.0.0.1*)
      echo "error: $key must be a non-placeholder production value for AppStore builds." >&2; fail=1 ;;
  esac
done
[ "$fail" -eq 0 ] || exit 1
# Fail closed if a future build attempts to restore owner-funded relay configuration or bundled provider keys.
for key in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY RELAY_BACKEND_URL TYPESAFE_API_KEY NEBIUS_API_KEY; do
  eval "value=\${$key:-}"
  if [ -n "$value" ]; then
    echo "error: $key must not be present in the user-funded native build configuration." >&2
    exit 1
  fi
done
case "$PRIVACY_POLICY_URL" in https://*) ;; *) echo "error: PRIVACY_POLICY_URL must use HTTPS." >&2; exit 1;; esac
case "$SUPPORT_URL" in https://*) ;; *) echo "error: SUPPORT_URL must use HTTPS." >&2; exit 1;; esac
