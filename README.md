maven-release-script
====================

This script provides similar functionality to the Maven release script, but works nicely with git.

I created the script because to get the maven release plugin to work the way I wanted meant keeping a version of Maven 2.0 and not using concurrent builds; this was a huge pain.

Usage
=====

```
Usage:
  release.sh [-a | [ -r RELEASE_VERSION ] [ -n NEXT_DEV_VERSION ] ]  [ -c ASSUMED_POM_VERSION ] [ -s ]
Updates release version, then builds and commits it

  -a    Shorthand for -a auto -n auto
  -r    Sets the release version number to use ('auto' to use the version in pom.xml)
  -n    Sets the next development version number to use (or 'auto' to increment release version)
  -c    Assume this as pom.xml version without inspecting it with xmllint
  -s    If provided, digitally signs the release before deploying it

  -h    For this message
```
