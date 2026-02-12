#!/usr/bin/env bash
set -Eeu

# After the dotnet command has run ~/.nuget/packages contains reqnroll/  
# so it is important the current user is sandbox.
# Also, the /tmp dir has a csproj file (copied into the docker/ dir ready to be used
# in the start-point)

[ "$(whoami)" == sandbox ] || (>&2 echo 'User must be sandbox' ; kill -INT $$)
cd /tmp
dotnet new install Reqnroll.Templates
dotnet new reqnroll-project
