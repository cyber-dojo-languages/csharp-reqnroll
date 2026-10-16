#!/bin/bash -Eeu

# Appends one test framework to the test_frameworks list the base image
# wrote in /versions.json, keeping any entry an earlier image added. Stops
# the build if the list is not found, rather than record nothing.
add_test_framework()
{
  local -r name="${1}"
  local -r version="${2}"
  local -r entry="{\"name\": \"${name}\", \"version\": \"${version}\"}"
  if [ -z "${version}" ]; then
    echo "Found no version for ${name}" >&2
    exit 1
  fi
  if grep -q '"test_frameworks": \[\]' /versions.json; then
    sed -i "s|\"test_frameworks\": \[\]|\"test_frameworks\": [${entry}]|" /versions.json
  else
    sed -i "/\"test_frameworks\": \[/s|}\]|}, ${entry}]|" /versions.json
  fi
  if ! grep -q -F "${entry}" /versions.json; then
    echo "Could not add ${name} to /versions.json" >&2
    cat /versions.json >&2
    exit 1
  fi
}

# Returns the version nuget resolved for one package, read from the directory
# it unpacked the package into in the sandbox user's NuGet cache.
package_version()
{
  ls "/home/sandbox/.nuget/packages/${1}" | sort -V | tail -n 1
}

add_test_framework Reqnroll "$(package_version reqnroll.nunit)"
add_test_framework NUnit "$(package_version nunit)"
cat /versions.json
