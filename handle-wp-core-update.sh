#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"

# Set SSH_AUTH_SOCK to the agent socket
export SSH_AUTH_SOCK=/tmp/ssh_agent.sock

run_command() { 
    local command=$1

    # $SSH_COMMAND is defined in main.js of saucal/action-deploy-ssh
    # TODO: Improve quotes handling & consider maintainability of the logic in long term
    if [ -z "$SSH_COMMAND" ]; then
        echo "SSH_COMMAND is not set. Unable to execute the command remotely."
        return 1
    fi

    # Execute the command remotely
    eval "$SSH_COMMAND '$command'"
    return $?
}

# Check if core-version-composer-to file exists in RUNNER_TEMP
if [ ! -f "${RUNNER_TEMP}/core-version-composer-to" ]; then
    echo "core-version-composer-to file does not exist in ${RUNNER_TEMP}."
    exit 0 # Exit with success code as we dont have a core version in 
fi

CORE_VERSION_COMPOSER_TO=$(cat "${RUNNER_TEMP}/core-version-composer-to")

if [ -f "${RUNNER_TEMP}/core-version-composer-from" ]; then
    CORE_VERSION_COMPOSER_FROM=$(cat "${RUNNER_TEMP}/core-version-composer-from")
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

# Record it for consistency self-heal (reconcile sets extra.wordpress-core to the server's version).
echo "$CORE_VERSION_REMOTE" > "${RUNNER_TEMP}/core-version-remote"

# Core the deploy user cannot write is managed by the host (Pressable, VIP, ...): never update it
# and never fail on it — at most warn that the repo and the server disagree. Recorded for consistency
# self-heal, which then drops extra.wordpress-core from the repo. (No single quotes in here:
# run_command wraps the command in them.)
CORE_ACCESS=$(run_command "cd ${REMOTE_ROOT} && f=\"\$(wp eval \"echo ABSPATH;\" 2>/dev/null)wp-includes/version.php\"; [ -w \"\$f\" ] && echo writable || echo managed")
if [ "$(printf '%s' "$CORE_ACCESS" | tail -n 1 | tr -d '[:space:]')" == "managed" ]; then
    echo "1" > "${RUNNER_TEMP}/core-managed-by-host"
    if [ "$CORE_VERSION_COMPOSER_TO" != "$CORE_VERSION_REMOTE" ]; then
        echo "::warning title=WordPress core is managed by the host::The repo asks for $CORE_VERSION_COMPOSER_TO but the server runs $CORE_VERSION_REMOTE. Core files are not writable by the deploy user, so it is not updated; drop extra.wordpress-core for this site."
    fi
    exit 0
fi

# Already where this build wants it — nothing to check or change (even if the last build said otherwise).
if [ "$CORE_VERSION_COMPOSER_TO" == "$CORE_VERSION_REMOTE" ]; then
    echo "WordPress Core is already at the correct version."
    exit 0
fi

if [ "$CONSISTENCY_CHECK" == "true" ] && [ -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    echo "::warning title=CORE_VERSION_COMPOSER_FROM not set::CONSISTENCY_CHECK is true but CORE_VERSION_COMPOSER_FROM is not set."
    exit 0
fi

# A dry run (pure consistency check / self-heal verify) must never update the server.
if [ "$DRY_RUN" == "true" ]; then
    echo "WordPress Core is not at the expected version ($CORE_VERSION_COMPOSER_TO expected, server has $CORE_VERSION_REMOTE). Dry run: not updating."
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

# If versions don't match, update. We don't care about CONSISTENCY_CHECK here as we 've are already acted on it above, if we do have a FROM version.
echo "Updating WordPress Core to version $CORE_VERSION_COMPOSER_TO."

run_command "cd ${REMOTE_ROOT} && wp core update --version=$CORE_VERSION_COMPOSER_TO --force"
if [ $? -ne 0 ]; then
    echo "Failed to update WordPress Core."
    exit 1
fi

IS_MULTISITE=$(run_command "cd ${REMOTE_ROOT} && wp config get MULTISITE --quiet 2>/dev/null")

if [ -z "$IS_MULTISITE" ]; then
    run_command "cd ${REMOTE_ROOT} && wp core update-db"
else
    run_command "cd ${REMOTE_ROOT} && wp core update-db --network"
fi