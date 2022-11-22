#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"
FROM_DIR="${GITHUB_WORKSPACE}/${FROM_DIR}"

if [ ! -f "${PATH_DIR}/composer.json" ]; then
	echo "Not going to install anything with composer"
	# Nothing to do here
	exit 0;
fi

if [ ! -f "${FROM_DIR}/vendor/composer/installed.json" ]; then
	echo "We don't have previously installed dependencies"
	# Nothing to do here either
	exit 0;
fi



# initialize composer on build dir
mkdir -p "${PATH_DIR}/vendor"
rm -rf "${PATH_DIR}/vendor/composer"
cp -rf "${FROM_DIR}/vendor/composer" "${PATH_DIR}/vendor/composer"

# build list of plugins to be installed
WHITELIST=$(jq -crM '[ .packages[] | .name ] + ["composer/installers"] | unique' "${PATH_DIR}/composer.lock")

# refresh installed.json based on packages previously installed
{
	jq --indent 4 -rM --argjson whitelist "${WHITELIST}" 'del(.packages[] | select( .name as $in | $whitelist | index($in) | not))' "${PATH_DIR}/vendor/composer/installed.json"
} > "${PATH_DIR}/vendor/composer/installed_new.json"

rm -rf "${PATH_DIR}/vendor/composer/installed.json"
mv "${PATH_DIR}/vendor/composer/installed_new.json" "${PATH_DIR}/vendor/composer/installed.json"

# move files from location to new one
while IFS=\= read PACKAGE; do
	PACKAGE_DIR="${PACKAGE#"../../"}"
	PACKAGE_PARENT_DIR="$(dirname "$PACKAGE_DIR")"
	echo "Attempting to restore ${PACKAGE_DIR}"
	mkdir -p "${PATH_DIR:?}/${PACKAGE_PARENT_DIR}"
	rm -rf "${PATH_DIR:?}/${PACKAGE_DIR}"
	cp -rf "${FROM_DIR:?}/${PACKAGE_DIR}" "${PATH_DIR:?}/${PACKAGE_DIR}"
	# TODO: ^ move, instead of copy
done < <(jq -crM 'del(.packages[] | select( .name as $in | ["composer/installers"] | index($in))) | .packages[]."install-path"' "${PATH_DIR}/vendor/composer/installed.json")
unset IFS
