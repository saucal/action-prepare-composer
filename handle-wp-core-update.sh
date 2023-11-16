#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"
SCRIPT_DIR=$(dirname "$0") # RUNNER_TEMP not available here
SCRIPT_DIR=$(cd "$SCRIPT_DIR" && pwd)

# we need a script, that will check if core is at wrong version & fail - like consistency check
# and also not update if at the same version. 

echo "PATH_DIR: ${PATH_DIR}"
echo "SSH_COMMAND: ${SSH_COMMAND}"
echo "REMOTE_ROOT: ${REMOTE_ROOT}"
echo "CONSISTENCY_CHECK: ${CONSISTENCY_CHECK}"

run_command() {
    local command=$1
    if [ -z "$SSH_COMMAND" ]; then
        echo "SSH_COMMAND is not set. Unable to execute the command remotely."
        return 1
    fi

    # Execute the command remotely
    eval "$SSH_COMMAND '$command'"
}

# Check if core-version-composer-to file exists in SCRIPT_DIR
if [ ! -f "${SCRIPT_DIR}/core-version-composer-to" ]; then
    echo "core-version-composer-to file does not exist in ${SCRIPT_DIR}."
    exit 1 ## TODO switch to 0
fi

CORE_VERSION_COMPOSER_TO=$(cat "${SCRIPT_DIR}/core-version-composer-to")

if [ -f "${SCRIPT_DIR}/core-version-composer-from" ]; then
    CORE_VERSION_COMPOSER_FROM=$(cat "${SCRIPT_DIR}/core-version-composer-from")
fi

# If not set exit.
if [ -z "$CORE_VERSION_COMPOSER_TO" ]; then
    echo "CORE_VERSION_COMPOSER_TO is not set."
    exit 0
fi

echo "CORE_VERSION_COMPOSER_TO: $CORE_VERSION_COMPOSER_TO"

# Check current version on remote
CORE_VERSION_REMOTE=$(run_command "wp core version --path=${REMOTE_ROOT}")

echo "CORE_VERSION_REMOTE: $CORE_VERSION_REMOTE"

# If not set fail.
if [ -z "$CORE_VERSION_REMOTE" ]; then
    echo "Could not get version of WordPress Core on remote."
    exit 1
fi

# If current version is not what we expect, fail.
if [ ! -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    if [ "$CORE_VERSION_COMPOSER_FROM" != "$CORE_VERSION_REMOTE" ]; then
        echo "WordPress Core is not at the expected version on remote."
        exit 1
    fi
fi

# If versions match, exit.
if [ "$CORE_VERSION_COMPOSER_TO" == "$CORE_VERSION_REMOTE" ]; then
    echo "WordPress Core is already at the correct version."
    exit 0
fi

# If versions don't match, update.
echo "Updating WordPress Core to version $CORE_VERSION_COMPOSER_TO."
run_command "wp core update --version=$CORE_VERSION_COMPOSER_TO --force --path=${REMOTE_ROOT}"
