// LightSequence plugin (art-stream-uep).

#include "Misc/AutomationTest.h"
#include "LightSequenceLibrary.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLightSequenceSmokePluginVersionTest, "LightSequence.Smoke.PluginVersion",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLightSequenceSmokePluginVersionTest::RunTest(const FString& Parameters)
{
	TestEqual(TEXT("Plugin version equals VersionName of LightSequence.uplugin"), ULightSequenceLibrary::GetPluginVersion(), FString(TEXT("0.1.0")));
	return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
