// LightSequence plugin (art-stream-uep).

#include "LightSequenceLibrary.h"
#include "LightSequenceLog.h"
#include "LightSequenceModule.h"
#include "Interfaces/IPluginManager.h"
#include "HAL/IConsoleManager.h"

#include UE_INLINE_GENERATED_CPP_BY_NAME(LightSequenceLibrary)

// Console command for diagnostics and the P0 packaging check: calls the same function as Blueprint.
// Usable as "-ExecCmds=LightSequence.PrintVersion" in non-Shipping builds (ExecCmds is compiled out of Shipping).
static FAutoConsoleCommand GLightSequencePrintVersionCommand(
	TEXT("LightSequence.PrintVersion"),
	TEXT("Calls ULightSequenceLibrary::GetPluginVersion() and writes the plugin version to the log (LogLightSequence)."),
	FConsoleCommandDelegate::CreateLambda([]()
	{
		ULightSequenceLibrary::GetPluginVersion();
	}));

FString ULightSequenceLibrary::GetPluginVersionQuiet()
{
	const TSharedPtr<IPlugin> Plugin = IPluginManager::Get().FindPlugin(FLightSequenceModule::PluginName);
	if (!Plugin.IsValid())
	{
		return TEXT("unknown");
	}
	return Plugin->GetDescriptor().VersionName;
}

FString ULightSequenceLibrary::GetPluginVersion()
{
	const FString Version = GetPluginVersionQuiet();
	UE_LOG(LogLightSequence, Log, TEXT("GetPluginVersion called: %s"), *Version);
	return Version;
}
