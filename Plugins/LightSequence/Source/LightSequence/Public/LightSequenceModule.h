// LightSequence plugin (art-stream-uep).

#pragma once

#include "Modules/ModuleInterface.h"

/** Runtime module of the LightSequence plugin. */
class FLightSequenceModule : public IModuleInterface
{
public:
	/** Name of the plugin as registered with the plugin manager. */
	static const TCHAR* PluginName;

	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
};
