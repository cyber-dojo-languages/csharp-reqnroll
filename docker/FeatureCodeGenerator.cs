// Turns .feature files into the C# that Reqnroll's test classes are built from.
//
// Reqnroll performs this during a build, through an MSBuild task, and there is
// no command that does it on its own. Driving the generator library directly is
// what lets a kata skip MSBuild altogether: the whole build then becomes this,
// followed by csc, the way the other csharp start-points already work.
//
// Compiled once when the image is built, so a kata pays only to run it.
// Every feature file is turned into C# by one process, so starting dotnet and
// loading the generator is paid once per run, not once per file.
//
// Arguments, in order:
//   project folder, namespace, generator plugin dll, output dir, feature file...

using System;
using System.Collections.Generic;
using System.IO;
using Reqnroll.BoDi;
using Reqnroll.Configuration;
using Reqnroll.Generator;
using Reqnroll.Generator.Interfaces;

public static class FeatureCodeGenerator
{
    public static int Main(string[] args)
    {
        if (args.Length < 4)
        {
            Console.Error.WriteLine(
                "use: <project-folder> <namespace> <plugin-dll> <out-dir> <feature-file>...");
            return 2;
        }

        // ConfigSource.Default means no reqnroll.json is required in the kata.
        var configuration = new ReqnrollConfigurationHolder(ConfigSource.Default, null);

        var projectSettings = new ProjectSettings
        {
            ProjectName = "dojo",
            AssemblyName = "dojo",
            ProjectFolder = args[0],
            DefaultNamespace = args[1],
            ConfigurationHolder = configuration,
            ProjectPlatformSettings = new ProjectPlatformSettings { Language = "C#" }
        };

        // The plugin is what makes the generated class an NUnit test class
        // rather than one for some other test framework.
        var plugins = new[]
        {
            new GeneratorPluginInfo(args[2], new Dictionary<string, string>())
        };

        var container = new GeneratorContainerBuilder()
            .CreateContainer(configuration, projectSettings, plugins, null);

        var generator = container.Resolve<ITestGenerator>();
        var outDir = args[3];
        var status = 0;

        for (var i = 4; i < args.Length; i++)
        {
            var featureFile = args[i];
            var result = generator.GenerateTestFile(
                new FeatureFileInput(featureFile), new GenerationSettings());

            if (!result.Success)
            {
                // Gherkin the parser cannot read reaches the learner here,
                // naming the feature file, rather than disappearing into a
                // build log. Every such file is named, not just the first.
                foreach (var error in result.Errors)
                {
                    Console.Error.WriteLine($"{featureFile}: {error}");
                }
                status = 1;
                continue;
            }

            // A feature in a sub-directory gets a flat name, so two features
            // with the same filename in different directories do not collide.
            var name = featureFile.StartsWith("./") ? featureFile.Substring(2) : featureFile;
            var outFile = Path.Combine(outDir, name.Replace('/', '_') + ".cs");
            File.WriteAllText(outFile, result.GeneratedTestCode);
        }
        return status;
    }
}
