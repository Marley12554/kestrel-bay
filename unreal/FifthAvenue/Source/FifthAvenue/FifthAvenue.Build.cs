using UnrealBuildTool;

public class FifthAvenue : ModuleRules
{
    public FifthAvenue(ReadOnlyTargetRules target) : base(target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PrivateDependencyModuleNames.AddRange(new[] {"Slate", "SlateCore", "RenderCore"});
        PublicDependencyModuleNames.AddRange(new[] {"Core", "CoreUObject", "Engine", "InputCore"});
    }
}
