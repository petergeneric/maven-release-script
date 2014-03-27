#!/bin/bash

function die_with() {
	echo "$*" >&2
	exit 1
}

function die_unless_xmllint_has_xpath() {
	which xmllint >/dev/null 2>/dev/null || die_with "Missing xmllint command, please install it (from libxml2)"
	
	if [ "$(xmllint 2>&1 | grep xpath | wc -l)" = "0" ] ; then
		die_with "xmllint command is missing the --xpath option, please install the libxml2 version"
	fi
}

function usage() {
	echo "Usage:"
	echo "  $0 [ -r RELEASE_VERSION ] [ -n NEXT_DEV_VERSION ] [ -c ASSUMED_POM_VERSION ]"
	echo "Updates release version, then builds and commits it"
	echo ""
	echo "  -r    Sets the release version number to use ('auto' to use the version in pom.xml)"
	echo "  -n    Sets the next development version number to use (or 'auto' to increment release version)"
	echo "  -c    Assume this as pom.xml version without inspecting it with xmllint"
	echo ""
	echo "  -h    For this message"
	echo ""
	echo "Version 1.0"
}

while getopts ":r:n:c:h:" o; do
    case "${o}" in
        -r)
            RELEASE_VERSION="${OPTARG}"
            ;;
        -n)
            NEXT_VERSION="${OPTARG}"
            ;;
        -c)
        	CURRENT_VERSION="${OPTARG}"
        	;;
        -h)
        	usage
        	exit 0
        	;;
        *)
            usage
            exit 10
            ;;
    esac
done
shift $((OPTIND-1))


# If there are any uncommitted changes we must abort immediately
if [ $(git status -s | wc -l) != "0" ] ; then
	git status -s
	die_with "There are uncommitted changes, please commit or stash them to continue with the release:"
fi

#################################################################
# FIGURE OUT RELEASE VERSION NUMBER AND NEXT DEV VERSION NUMBER #
#################################################################

# Extract the current version (requires xmlllint with xpath suport)
die_unless_xmllint_has_xpath
CURRENT_VERSION=$(xmllint --xpath "/*[local-name() = 'project']/*[local-name() = 'version']/text()" pom.xml)


# Prompt for release version (or compute it automatically if requested)
RELEASE_VERSION_DEFAULT=$(echo "$CURRENT_VERSION" | perl -pe 's/-SNAPSHOT//')
if [ -z "$RELEASE_VERSION" ] ; then
	read -p "Version to release [${RELEASE_VERSION_DEFAULT}]" RELEASE_VERSION
		
	if [ -z "$RELEASE_VERSION" ] ; then
		RELEASE_VERSION=$RELEASE_VERSION_DEFAULT
	fi
elif [ "$RELEASE_VERSION" = "auto" ] ; then
	RELEASE_VERSION=$RELEASE_VERSION_DEFAULT
fi

if [ "$RELEASE_VERSION" = "$CURRENT_VERSION" ] ; then
	die_with "Release version requested is exactly the same as the current pom.xml version (${CURRENT_VERSION})! Is the version in pom.xml definitely a -SNAPSHOT version?"
fi


# Prompt for next version (or compute it automatically if requested)
NEXT_VERSION_DEFAULT=$(echo "$RELEASE_VERSION" | perl -pe 's{^(([0-9]\.)+)([0-9]+)$}{$1 . ($3 + 1)}e')
if [ -z "$NEXT_VERSION" ] ; then
	read -p "Next snapshot version [${NEXT_VERSION_DEFAULT}]" NEXT_VERSION
	
	if [ -z "$NEXT_VERSION" ] ; then
		NEXT_VERSION=$NEXT_VERSION_DEFAULT
	fi
elif [ "$NEXT_VERSION" = "auto" ] ; then
	NEXT_VERSION=$NEXT_VERSION_DEFAULT
fi

# Add -SNAPSHOT to the end (and make sure we don't accidentally have it twice)
NEXT_VERSION="$(echo "$NEXT_VERSION" | perl -pe 's/-SNAPSHOT//gi')-SNAPSHOT"

if [ "$NEXT_VERSION" = "${RELEASE_VERSION}-SNAPSHOT" ] ; then
	die_with "Release version and next version are the same version!"
fi


echo ""
echo "Using $RELEASE_VERSION for release"
echo "Using $NEXT_VERSION for next development version"

#################################################################
# START THE RELEASE PROCESS #
#################################################################
VCS_RELEASE_TAG="v${RELEASE_VERSION}"

# if a release tag of this version already exists then abort immediately
if [ $(git tag -l "${VCS_RELEASE_TAG}" | wc -l) != "0" ] ; then
	die_with "A tag already exists ${VCS_RELEASE_TAG} for the release version ${RELEASE_VERSION}"
fi

mvn versions:set -DgenerateBackupPoms=false -DnewVersion=$RELEASE_VERSION || die_with "Failed to set release version on pom.xml files"

# Commit the updated pom.xml files
git commit -a -m "Release version ${RELEASE_VERSION}" || die_with "Failed to commit updated pom.xml versions for release!"

# TODO build and deploy the release
mvn3 clean package source:jar javadoc:jar package gpg:sign deploy || die_with "Build/Deploy failure. Release failed."

# TODO tag the release (N.B. should this be before perform the release?)
git tag "v${RELEASE_VERSION}" || die_with "Failed to create tag ${RELEASE_VERSION}!"

######################################
# Start the next development process #
######################################

mvn versions:set -DgenerateBackupPoms=false "-DnewVersion=${NEXT_VERSION}" || die_with "Failed to set next dev version on pom.xml files"

git commit -a -m "Start next development version ${NEXT_VERSION}" || die_with "Failed to commit updated pom.xml versions for next dev version!"

