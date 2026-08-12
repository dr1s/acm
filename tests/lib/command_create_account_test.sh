#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_DIR

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/utils/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/assert.sh"

init_command_environment() {
    CONFIG_FILE="${SCRIPT_DIR}/conf/wowserver.conf"
    CONFIG_NAME="test"
    export CONFIG_FILE CONFIG_NAME
}

log_info() { :; }
log_warn() { :; }
log_error() { :; }

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/commands/create-account.sh"

ORIGINAL_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'cd "${ORIGINAL_DIR}" && rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"

# Fake container command that simulates the worldserver console.
# It prints AC> prompts and records the commands it receives.
FAKE_CONTAINER_CMD="${TMP_DIR}/fake_container_cmd"
COMMAND_LOG="${TMP_DIR}/commands.log"
cat > "${FAKE_CONTAINER_CMD}" <<EOF
#!/usr/bin/env bash
echo "AC>"
while IFS= read -r line; do
    echo "\${line}" >> "${COMMAND_LOG}"
    echo "AC>"
    if [[ "\${line}" == "account set gmlevel"* ]]; then
        exit 0
    fi
done
EOF
chmod +x "${FAKE_CONTAINER_CMD}"

CONTAINER_CMD="${FAKE_CONTAINER_CMD}"
export CONTAINER_CMD

WORLD_CONTAINER_ID="test-worldserver-id"
container_ps_q() { echo "${WORLD_CONTAINER_ID}"; }

# --help exits 0
if ! (command_create_account --help) >/dev/null 2>&1; then
    fail "create-account --help should exit 0"
fi

# Missing username/password fails
if (command_create_account) >/dev/null 2>&1; then
    fail "create-account without credentials should fail"
fi

if (command_create_account myuser) >/dev/null 2>&1; then
    fail "create-account without password should fail"
fi

# Unknown argument fails
if (command_create_account myuser mypass --unknown) >/dev/null 2>&1; then
    fail "create-account with unknown arg should fail"
fi

# Successful account creation
command_create_account myuser mypass >/dev/null 2>&1
assert_eq "account create myuser mypass" "$(sed -n '1p' "${COMMAND_LOG}")" "create-account should send account create command"
assert_eq "account set gmlevel myuser 3 -1" "$(sed -n '2p' "${COMMAND_LOG}")" "create-account should send gmlevel command"

# Credentials with special characters are passed through intact
rm -f "${COMMAND_LOG}"
command_create_account 'user$[name"' 'pass\"word' >/dev/null 2>&1
assert_eq 'account create user$[name" pass\"word' "$(sed -n '1p' "${COMMAND_LOG}")" "create-account should preserve special characters in credentials"
assert_eq 'account set gmlevel user$[name" 3 -1' "$(sed -n '2p' "${COMMAND_LOG}")" "create-account should preserve special characters in gmlevel command"

# Fails if worldserver is not running
container_ps_q() { :; }
if (command_create_account myuser mypass) >/dev/null 2>&1; then
    fail "create-account should fail when worldserver is not running"
fi

echo "PASS: command_create_account_test"
