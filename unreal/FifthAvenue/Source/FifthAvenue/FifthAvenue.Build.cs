using UnrealBuildTool;

public class FifthAvenue : ModuleRules
{
    public FifthAvenue(ReadOnlyTargetRules target) : base(target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {"Core", "CoreUObject", "Engine", "InputCore"});
    }
}
