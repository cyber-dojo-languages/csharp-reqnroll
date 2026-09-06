#!/usr/bin/env bash
set -Eeu

# Everything here exists so that a kata's test run never starts MSBuild.
#
# dotnet test restores, builds and runs in one command, and that took about two
# seconds, most of it MSBuild rather than compiling. The other csharp
# start-points already avoid it: they call csc directly with an explicit list of
# references and run the tests with the NUnit console runner. Reqnroll could not
# do the same because turning a .feature file into C# is an MSBuild task with no
# command of its own, so the generator below supplies the missing piece.
#
# Three things are prepared, all of them identical for every kata and every run:
#   1. the packages, in ~/.nuget/packages, as before
#   2. the generator, compiled once
#   3. the reference assemblies csc is pointed at
#
# After the dotnet commands have run ~/.nuget/packages contains reqnroll/,
# so it is important the current user is sandbox.

[ "$(whoami)" == sandbox ] || (>&2 echo 'User must be sandbox' ; kill -INT $$)

readonly GENERATOR_DIR="${HOME}/reqnroll_generator"
readonly REFS_DIR="${HOME}/dojo_refs"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 1. the packages
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
cd /tmp
dotnet new install Reqnroll.Templates.DotNet
dotnet new reqnroll-project --testExecutionFramework nunit --framework net9.0 --name temp
dotnet restore

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 2. the reference assemblies, from a build of the very csproj the start-point
#    ships, so the list a kata compiles against is the list it would have had.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
mkdir -p /tmp/refs_build
cp /config.csproj /tmp/refs_build/dojo.csproj
cd /tmp/refs_build
cat > Placeholder.cs <<'CS'
public static class Placeholder
{
    public static int Answer() { return 42; }
}
CS
dotnet build -p:RestoreSources="${HOME}/.nuget/packages/"

mkdir -p "${REFS_DIR}"
cp bin/Debug/net9.0/*.dll "${REFS_DIR}/"
# The kata compiles its own assembly of this name every run, so shipping one
# would let a stale copy answer for the learner's edit.
rm -f "${REFS_DIR}/dojo.dll"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 3. the feature-file generator
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Found rather than named. The csproj asks for a lowest acceptable version and
# nuget resolves whatever satisfies it, so a version written here is a second
# opinion that goes stale the first time the resolved one moves.
readonly GENERATOR_PACKAGE="$(dirname "$(find "${HOME}/.nuget/packages/reqnroll.tools.msbuild.generation" \
  -path '*/build/netstandard2.0/Reqnroll.Generator.dll' | sort | tail -1)")"
readonly CSC="$(find /usr/share/dotnet/sdk -name csc.dll | head -1)"
readonly SHARED="$(ls -d /usr/share/dotnet/shared/Microsoft.NETCore.App/* | tail -1)"

mkdir -p "${GENERATOR_DIR}"
cp "${GENERATOR_PACKAGE}"/*.dll "${GENERATOR_DIR}/"

generator_refs=''
for dll in "${GENERATOR_PACKAGE}"/*.dll; do generator_refs="${generator_refs} -r:${dll}"; done
for dll in "${SHARED}"/System.*.dll "${SHARED}"/netstandard.dll; do generator_refs="${generator_refs} -r:${dll}"; done

# Compiled from inside the directory, with a relative filename. csc reads a
# leading slash as the start of an option, so an absolute source path is taken
# for a flag it does not recognise.
cp /FeatureCodeGenerator.cs "${GENERATOR_DIR}/"
cd "${GENERATOR_DIR}"
dotnet "${CSC}" \
  -nologo \
  -target:exe \
  -main:FeatureCodeGenerator \
  -out:feature_code_generator.dll \
  ${generator_refs} \
  FeatureCodeGenerator.cs
rm -f "${GENERATOR_DIR}/FeatureCodeGenerator.cs"

# Names the runtime the generator is hosted on. Without it dotnet refuses to
# start the assembly at all.
cat > "${GENERATOR_DIR}/feature_code_generator.runtimeconfig.json" <<'JSON'
{
  "runtimeOptions": {
    "tfm": "net10.0",
    "framework": { "name": "Microsoft.NETCore.App", "version": "10.0.0" }
  }
}
JSON

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 4. the test runner, which the other csharp start-points also use in place of
#    dotnet test.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
dotnet tool install --global NUnit.ConsoleRunner.NetCore --version 3.22.0

ls -l "${GENERATOR_DIR}/feature_code_generator.dll"
echo "reference assemblies: $(ls -1 "${REFS_DIR}" | wc -l)"
