#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"
SCRIPT_DIR=$(dirname "$0") # RUNNER_TEMP not available here
SCRIPT_DIR=$(cd "$SCRIPT_DIR" && pwd)

# Set SSH_AUTH_SOCK to the agent socket
export SSH_AUTH_SOCK=/tmp/ssh_agent.sock

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
    exit 0 # Exit with success code as we dont have a core version in composer.json
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
echo "CORE_VERSION_COMPOSER_FROM: $CORE_VERSION_COMPOSER_FROM"

# Check current version on remote
CORE_VERSION_REMOTE=$(run_command "cd ${REMOTE_ROOT} && wp core version")

echo "CORE_VERSION_REMOTE: $CORE_VERSION_REMOTE"

# If not set fail.
if [ -z "$CORE_VERSION_REMOTE" ]; then
    echo "Could not get version of WordPress Core on remote."
    exit 1
fi

if [ "$CONSISTENCY_CHECK" == "true" ] && [ -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    echo "CONSISTENCY_CHECK is true but CORE_VERSION_COMPOSER_FROM is not set."
    exit 1
fi

# If current version is not what we expect and CONSISTENCY_CHECK is true, fail, else log a warning
if [ ! -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    if [ "$CORE_VERSION_COMPOSER_FROM" != "$CORE_VERSION_REMOTE" ]; then
        echo "WordPress Core is not at the expected version."

        if [ "$CONSISTENCY_CHECK" == "true" ]; then
            exit 1
        else
            echo "Continuing with update as CONSISTENCY_CHECK is false."
        fi
    fi
fi

# If versions match, exit.
if [ "$CORE_VERSION_COMPOSER_TO" == "$CORE_VERSION_REMOTE" ]; then
    echo "WordPress Core is already at the correct version."
    exit 0
fi

# If versions don't match, update. We don't care about CONSISTENCY_CHECK here as we 've are already acted on it above, if we do have a FROM version.
echo "Updating WordPress Core to version $CORE_VERSION_COMPOSER_TO."
run_command "cd ${REMOTE_ROOT} && wp core update --version=$CORE_VERSION_COMPOSER_TO --force"

