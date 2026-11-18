// LightSequence plugin (art-stream-uep).

#include "LightSequenceModule.h"
#include "LightSequenceLibrary.h"
#include "LightSequenceLog.h"
#include "Modules/ModuleManager.h"

DEFINE_LOG_CATEGORY(LogLightSequence);

const TCHAR* FLightSequenceModule::PluginName = TEXT("LightSequence");

void FLightSequenceModule::StartupModule()
{
	UE_LOG(LogLightSequence, Log, TEXT("LightSequence module started, plugin version %s"), *ULightSequenceLibrary::GetPluginVersionQuiet());
}

void FLightSequenceModule::ShutdownModule()
{
	UE_LOG(LogLightSequence, Log, TEXT("LightSequence module shut down"));
}

IMPLEMENT_MODULE(FLightSequenceModule, LightSequence)
