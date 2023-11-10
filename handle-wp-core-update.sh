#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"

# we need a script, that will check if core is at wrong version & fail - like consistency check
# and also not update if at the same version. 

echo "PATH_DIR: ${PATH_DIR}"
echo "SSH_COMMAND: ${SSH_COMMAND}"
echo "REMOTE_ROOT: ${REMOTE_ROOT}"

run_command() {
    local command=$1
    if [ -z "$SSH_COMMAND" ]; then
        echo "SSH_COMMAND is not set. Unable to execute the command remotely."
        return 1
    fi

    # Execute the command remotely
    eval "$SSH_COMMAND '$command'"
}

# Check if ${RUNNER_TEMP}/core-version-composer exists
if [ ! -f "${RUNNER_TEMP}/core-version-composer" ]; then
    echo "core-version-composer file does not exist."
    exit 0
fi

CORE_VERSION_COMPOSER=$(cat "${RUNNER_TEMP}/core-version-composer")

# If not set exit.
if [ -z "$CORE_VERSION_COMPOSER" ]; then
    echo "CORE_VERSION_COMPOSER is not set."
    exit 0
fi

# Check current version on remote
CORE_VERSION_REMOTE=$(run_command "wp core version --path=${REMOTE_ROOT}")

# If not set fail.
if [ -z "$CORE_VERSION_REMOTE" ]; then
    echo "Could not get version of WordPress Core on remote."
    exit 1
fi

# If versions match, exit.
if [ "$CORE_VERSION_COMPOSER" == "$CORE_VERSION_REMOTE" ]; then
    echo "WordPress Core is already at the correct version."
    exit 0
fi

# If versions don't match, update.
echo "Updating WordPress Core to version $CORE_VERSION_COMPOSER."
run_command "wp core update --version=$CORE_VERSION_COMPOSER --force --path=${REMOTE_ROOT}"


    # - name: Check for WP Core version attribute
    #   id: wpcore
    #   continue-on-error: true
    #   shell: bash
    #   run: |
    #     cd "${{ inputs.built }}"
    #     core_version=$(composer config extra.wordpress-core)
    #     echo core_update_cmd="wp core update --version=$core_version --force --path=${{ inputs.env-remote-root }}" >> $GITHUB_OUTPUT
