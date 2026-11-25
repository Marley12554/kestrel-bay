#include "Modules/ModuleManager.h"

#if PLATFORM_MAC && !WITH_EDITOR
#include "GameFramework/GameUserSettings.h"
#include "Misc/ConfigCacheIni.h"
#include "Misc/DelayedAutoRegister.h"

// macOS creates Unreal's preload window before the game module starts gameplay.
// Change the old borderless preference before the engine asks Cocoa for that window.
static FDelayedAutoRegisterHelper MigrateDesktopWindow(EDelayedRegisterRunPhase::IniSystemReady, [] {
    UGameUserSettings::LoadConfigIni();
    bool Migrated = false;
    GConfig->GetBool(TEXT("FifthAvenue"), TEXT("DesktopWindowMigrated"), Migrated, GGameUserSettingsIni);
    if (Migrated) return;

    const TCHAR* Section = TEXT("/Script/Engine.GameUserSettings");
    int32 Mode;
    if (GConfig->GetInt(Section, TEXT("FullscreenMode"), Mode, GGameUserSettingsIni)
        && Mode != EWindowMode::Windowed) {
        GConfig->SetInt(Section, TEXT("FullscreenMode"), EWindowMode::Windowed, GGameUserSettingsIni);
        GConfig->SetInt(Section, TEXT("LastConfirmedFullscreenMode"), EWindowMode::Windowed, GGameUserSettingsIni);
        GConfig->SetInt(Section, TEXT("ResolutionSizeX"), 1152, GGameUserSettingsIni);
        GConfig->SetInt(Section, TEXT("ResolutionSizeY"), 720, GGameUserSettingsIni);
        GConfig->SetInt(Section, TEXT("LastUserConfirmedResolutionSizeX"), 1152, GGameUserSettingsIni);
        GConfig->SetInt(Section, TEXT("LastUserConfirmedResolutionSizeY"), 720, GGameUserSettingsIni);
    }
    GConfig->SetBool(TEXT("FifthAvenue"), TEXT("DesktopWindowMigrated"), true, GGameUserSettingsIni);
    GConfig->Flush(false, GGameUserSettingsIni);
});
#endif

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, FifthAvenue, "FifthAvenue");
