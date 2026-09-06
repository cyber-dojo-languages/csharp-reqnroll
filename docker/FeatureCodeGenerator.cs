// Turns a .feature file into the C# that Reqnroll's test class is built from.
//
// Reqnroll performs this during a build, through an MSBuild task, and there is
// no command that does it on its own. Driving the generator library directly is
// what lets a kata skip MSBuild altogether: the whole build then becomes this,
// followed by csc, the way the other csharp start-points already work.
//
// Compiled once when the image is built, so a kata pays only to run it.
//
// Arguments, in order:
//   feature file, output file, project folder, namespace, generator plugin dll

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
        if (args.Length != 5)
        {
            Console.Error.WriteLine(
                "use: <feature-file> <out-file> <project-folder> <namespace> <plugin-dll>");
            return 2;
        }

        var featureFile = args[0];
        var outFile = args[1];

        // ConfigSource.Default means no reqnroll.json is required in the kata.
        var configuration = new ReqnrollConfigurationHolder(ConfigSource.Default, null);

        var projectSettings = new ProjectSettings
        {
            ProjectName = "dojo",
            AssemblyName = "dojo",
            ProjectFolder = args[2],
            DefaultNamespace = args[3],
            ConfigurationHolder = configuration,
            ProjectPlatformSettings = new ProjectPlatformSettings { Language = "C#" }
        };

        // The plugin is what makes the generated class an NUnit test class
        // rather than one for some other test framework.
        var plugins = new[]
        {
            new GeneratorPluginInfo(args[4], new Dictionary<string, string>())
        };

        var container = new GeneratorContainerBuilder()
            .CreateContainer(configuration, projectSettings, plugins, null);

        var generator = container.Resolve<ITestGenerator>();
        var result = generator.GenerateTestFile(
            new FeatureFileInput(featureFile), new GenerationSettings());

        if (!result.Success)
        {
            // Gherkin the parser cannot read reaches the learner here, naming
            // the feature file, rather than disappearing into a build log.
            foreach (var error in result.Errors)
            {
                Console.Error.WriteLine($"{featureFile}: {error}");
            }
            return 1;
        }

        File.WriteAllText(outFile, result.GeneratedTestCode);
        return 0;
    }
}
