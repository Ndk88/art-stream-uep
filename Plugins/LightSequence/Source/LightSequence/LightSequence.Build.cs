// LightSequence plugin (art-stream-uep).

using UnrealBuildTool;

public class LightSequence : ModuleRules
{
	public LightSequence(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
		});

		PrivateDependencyModuleNames.AddRange(new string[]
		{
			"Projects", // IPluginManager: plugin version from the descriptor
		});
	}
}
