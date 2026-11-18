// LightSequence plugin (art-stream-uep).

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "LightSequenceLibrary.generated.h"

/** Blueprint function library of the LightSequence plugin. */
UCLASS()
class LIGHTSEQUENCE_API ULightSequenceLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/**
	 * Returns the plugin version (VersionName of LightSequence.uplugin), for example "0.1.0".
	 * Every call writes one line to the log (category LogLightSequence).
	 */
	UFUNCTION(BlueprintPure, Category = "LightSequence")
	static FString GetPluginVersion();

	/** Same as GetPluginVersion() without the log line. Returns "unknown" if the plugin is not registered. */
	static FString GetPluginVersionQuiet();
};
