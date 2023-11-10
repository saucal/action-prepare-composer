
# MANIFEST_PATH="${RUNNER_TEMP}/git-manifest-$(openssl rand -hex 10)"

cp "$GITHUB_ACTION_PATH/handle-wp-core-update.sh" "${RUNNER_TEMP}/handle-wp-core-update.sh"

CORE_VERSION_COMPOSER=$(composer config extra.wordpress-core)

if [ -z "$CORE_VERSION_COMPOSER" ]; then
    echo "CORE_VERSION_COMPOSER is not set."
    exit 0
fi

echo "$CORE_VERSION_COMPOSER" > "${RUNNER_TEMP}/core-version-composer"

