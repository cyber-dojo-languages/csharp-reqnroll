#!/usr/bin/env bash
set -Eeu

readonly REGEX="image_name\": \"(.*)\""
readonly JSON=`cat docker/image_name.json`
[[ ${JSON} =~ ${REGEX} ]]
readonly IMAGE_NAME="${BASH_REMATCH[1]}"

# Fails when what the image holds is not what is named here. Reqnroll is
# checked as well as dotnet because the image installs it from a template that
# resolves whatever is current, so its version moves on its own. Checking only
# dotnet let the start-point go on telling learners 3.3.3 while the image had
# moved to 3.3.4.
check_version()
{
  local -r what="${1}"
  local -r expected="${2}"
  local -r actual="$(docker run --rm --interactive ${IMAGE_NAME} sh -c "${3}")"

  if echo "${actual}" | grep --quiet "${expected}"; then
    echo "VERSION CONFIRMED as ${what} ${expected}"
  else
    echo "VERSION EXPECTED: ${what} ${expected}"
    echo "VERSION   ACTUAL: ${actual}"
    exit 42
  fi
}

check_version dotnet 10.0.103 'dotnet --version'
check_version reqnroll 3.3.4 'ls /home/sandbox/.nuget/packages/reqnroll.nunit'
check_version nunit 4.5.1 'ls /home/sandbox/.nuget/packages/nunit'
