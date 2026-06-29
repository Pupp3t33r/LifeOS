# Run the Wallet app with hot reload against the local Aspire stack, on any of the
# three enabled targets. The Gateway-served static build at http://localhost:5022
# keeps working alongside whichever live target you launch here.
#
# Prereqs: the Aspire stack is running (`aspire run`). For web, the Keycloak
# `wallet-app` client must trust http://localhost:5555 (already added to
# lifeos-realm.json — re-import once: `docker volume rm keycloak-data` + restart).
#
# Why targets differ:
#   web     - runs on its OWN origin, so it can't use the Gateway's same-origin
#             reverse-proxy. We point OIDC + Money back at the Gateway via
#             dart-defines, and the Gateway's dev CORS policy allows the origin.
#   windows - native HTTP (no browser origin -> no CORS) and a loopback redirect
#             that's already registered. The app's native defaults already point
#             at http://localhost:5022, so nothing extra is needed.
#   android - localhost on the device is the DEVICE, not your PC. `adb reverse`
#             maps the device's localhost:5022 to the host Gateway, so the native
#             defaults work unchanged and the token issuer still matches Keycloak's
#             KC_HOSTNAME. Debug builds allow cleartext to localhost (see
#             android/app/src/debug/.../network_security_config.xml). The custom
#             scheme redirect (dev.lifeos.wallet) is already registered.
#
# Usage:
#   ./run-dev.ps1                 # web on :5555 (default)
#   ./run-dev.ps1 windows
#   ./run-dev.ps1 android         # add -Device if more than one is connected
param(
    [ValidateSet("web", "windows", "android")]
    [string]$Target = "web",
    [int]$WebPort = 5555,
    [string]$Gateway = "http://localhost:5022",
    [string]$Device
)

switch ($Target) {
    "web" {
        flutter run -d chrome --web-port=$WebPort `
            --dart-define=OIDC_ISSUER="$Gateway/realms/lifeos" `
            --dart-define=MONEY_API_BASE="$Gateway/api/money"
    }
    "windows" {
        # Native defaults already target http://localhost:5022; no CORS/defines.
        flutter run -d windows
    }
    "android" {
        # Forward the gateway port so the device can reach it as localhost:5022.
        # Re-run this script (or just `adb reverse ...`) whenever the device reconnects.
        adb reverse tcp:5022 tcp:5022
        if ($Device) { flutter run -d $Device } else { flutter run }
    }
}
