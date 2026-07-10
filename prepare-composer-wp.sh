#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"
FROM_DIR="${GITHUB_WORKSPACE}/${FROM_DIR}"

if [ ! -f "${PATH_DIR}/composer.json" ]; then
	echo "Not going to install anything with composer"
	# Nothing to do here
	exit 0;
fi

# Single source of truth for composer<->packages.saucal.com auth. Runs whenever there's a
# composer project, before the copy-forward early-exit, so any later composer run in this dir
# (e.g. the consistency-check reconcile in the same job) is authenticated. Mirrors
# build/build-for-deployment.sh.
if [ -n "${SATIS_KEY}" ]; then
	echo "Setup authentication for our SatisPress instance"
	( cd "${PATH_DIR}" && composer config http-basic.packages.saucal.com "${SATIS_KEY}" "$(composer config homepage | sed 's,http[s]\?://,,')" )
fi

if [ ! -f "${FROM_DIR}/vendor/composer/installed.json" ]; then
	echo "We don't have previously installed dependencies"
	# Nothing to do here either
	exit 0;
fi

FROM_PATHS="$(jq -rcM '.extra."installer-paths" | with_entries( .key |= ( sub("{.*?}\/"; ""; "g") | "../../" + . ) | .value |= ( tostring | @base64 ) | { "key": .value, "value": .key } )' "${FROM_DIR}/composer.json")"
TO_PATHS="$(jq -rcM '.extra."installer-paths" | with_entries( .key |= ( sub("{.*?}\/"; ""; "g") | "../../" + . ) | .value |= ( tostring | @base64 ) | { "key": .value, "value": .key } )' "${PATH_DIR}/composer.json")"
REPLACES="$(jq --argjson from_paths "${FROM_PATHS}" --argjson to_paths "${TO_PATHS}" -rcnM '$from_paths | with_entries( .value = ( if $to_paths[ .key ] then { from: .value, to: $to_paths[ .key ] } else null end ) | select( .value != null ) ) | to_entries | map_values( .value )')"


# initialize composer on build dir
mkdir -p "${PATH_DIR}/vendor"
rm -rf "${PATH_DIR}/vendor/composer"
cp -rf "${FROM_DIR}/vendor/composer" "${PATH_DIR}/vendor/composer"

# build list of plugins to be installed
WHITELIST=$(jq -crM '[ .packages[] | .name ] + ["composer/installers"] | unique' "${PATH_DIR}/composer.lock")

# refresh installed.json based on packages previously installed
{
	jq --indent 4 -rM --argjson repls "$REPLACES" --argjson whitelist "${WHITELIST}" '
	del(.packages[] | select( .name as $in | $whitelist | index($in) | not)) |
	.packages[] |= (
		if
			.name != "composer/installers"
		then ( 
			."old-install-path" = ."install-path" | 
			."install-path" |= reduce $repls[] as $r (.; sub($r.from; $r.to))
		)
		end
	)' "${FROM_DIR}/vendor/composer/installed.json"
} > "${PATH_DIR}/vendor/composer/installed.json"

# move files from location to new one
while IFS=\= read PACKAGE; do
	# split the package into two variables, before colon is from path and after is to path
	PACKAGE_FROM="$( echo "$PACKAGE" | cut -d ':' -f 1 )"
	PACKAGE_TO="$( echo "$PACKAGE" | cut -d ':' -f 2 )"
	echo "Attempting to restore ${PACKAGE_FROM} to ${PACKAGE_TO}"
	PACKAGE_TO_PARENT_DIR="$(dirname "$PACKAGE_TO")"

	mkdir -p "${PATH_DIR:?}/${PACKAGE_TO_PARENT_DIR}"
	rm -rf "${PATH_DIR:?}/${PACKAGE_TO}"
	cp -rf "${FROM_DIR:?}/${PACKAGE_FROM}" "${PATH_DIR:?}/${PACKAGE_TO}"
	# TODO: ^ move, instead of copy
done < <(jq -crM '.packages[] | select( ."old-install-path" != null) | ( ."old-install-path" | sub("^..\/..\/"; "") ) + ":" + ( ."install-path" | sub("^..\/..\/"; "") )' "${PATH_DIR}/vendor/composer/installed.json")
unset IFS

jq 'del(.packages[]."old-install-path")' "${PATH_DIR}/vendor/composer/installed.json" > "${PATH_DIR}/vendor/composer/installed.json.tmp"
mv -f "${PATH_DIR}/vendor/composer/installed.json.tmp" "${PATH_DIR}/vendor/composer/installed.json"
