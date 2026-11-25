#if !UE_BUILD_SHIPPING
#include "AvenueInputTest.h"
#include "../AvenueGameMode.h"
#include "Camera/PlayerCameraManager.h"
#include "DynamicResolutionState.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Framework/Application/SlateApplication.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "Input/HittestGrid.h"
#include "InputKeyEventArgs.h"
#include "Layout/Children.h"
#include "Layout/WidgetPath.h"
#include "Widgets/SWindow.h"

namespace {
TSharedPtr<SWidget> FindSensitivitySlider(const TSharedRef<SWidget>& Widget)
{
    if (Widget->GetTag() == TEXT("AvenueSensitivity")) return Widget;
    FChildren* Children = Widget->GetChildren();
    for (int32 I = 0; I < Children->Num(); ++I)
        if (auto Found = FindSensitivitySlider(Children->GetChildAt(I))) return Found;
    return nullptr;
}

// Send events before the controller ticks and inspect the result of that frame
// on the next callback. This exercises the actual viewport, bindings, character
// movement, rendered-camera pose and Slate hit testing in the packaged game.
struct FInputCheck {
    TWeakObjectPtr<AAvenueWalker> Walker;
    FDelegateHandle Handle;
    int32 Frame = 0;
    float InitialScale = 1;
    FVector LastPosition = FVector::ZeroVector;
    FRotator LastView = FRotator::ZeroRotator;
    TArray<double> PanTimes;
    float MinScale = 1.f, MaxScale = 0.f;
    double PanStart = 0, LastTime = 0;
    TSharedPtr<SWidget> Slider;
    FVector2D Pointer = FVector2D::ZeroVector;
    bool Failed = false;

    void Require(bool Condition, const TCHAR* What)
    {
        if (Condition) return;
        Failed = true;
        UE_LOG(LogTemp, Error, TEXT("Avenue input regression: %s"), What);
    }

    void Tick(UWorld* World, ELevelTick, float Dt)
    {
        AAvenueWalker* P = Walker.Get();
        if (!P || P->GetWorld() != World || World->GetTimeSeconds() < 2.f) return;
        auto* PC = CastChecked<APlayerController>(P->GetController());
        auto* VC = World->GetGameViewport();
        const auto Device = FInputDeviceId::CreateFromInternalId(0);
        auto Key = [&](FKey K, bool Down) {
            VC->InputKey(FInputKeyEventArgs(VC->Viewport,Device,K,Down ? IE_Pressed : IE_Released,
                Down ? 1.f : 0.f,false,FPlatformTime::Cycles64()));
        };
        auto Axis = [&](FKey K, float Delta) {
            VC->InputAxis(FInputKeyEventArgs(VC->Viewport,Device,K,Delta,Dt,1,FPlatformTime::Cycles64()));
        };
        auto& App = FSlateApplication::Get();
        const FVector Here = P->GetActorLocation();
        const FRotator View = PC->GetControlRotation();
        const bool PreviouslyFailed = Failed;

        switch (Frame++) {
        case 0:
            Require(P->PointerReleased && PC->bShowMouseCursor, TEXT("launch captured the cursor"));
            Key(EKeys::LeftMouseButton,true);
            Key(EKeys::LeftMouseButton,false);
            InitialScale = P->LookSensitivity;
            UE_LOG(LogTemp, Display, TEXT("Avenue controls: quality=%d sensitivity=%.4f"), P->Quality, InitialScale);
            Require(P->GetCharacterMovement()->IsMovingOnGround(), TEXT("spawn is not grounded"));
            Key(EKeys::W,true);
            break;
        case 1:
            Require(FVector::DotProduct(Here-LastPosition,P->GetActorForwardVector()) > .1, TEXT("W produced no first-frame forward movement"));
            Key(EKeys::W,false); Key(EKeys::S,true);
            break;
        case 2:
            Require(FVector::DotProduct(Here-LastPosition,P->GetActorForwardVector()) < -.1, TEXT("W to S did not reverse on the first frame"));
            Key(EKeys::S,false);
            break;
        case 3:
            Require(FVector::Dist2D(Here,LastPosition) < .1, TEXT("character coasted after key release"));
            Key(EKeys::W,true); Key(EKeys::D,true);
            Axis(EKeys::MouseX,400); Axis(EKeys::MouseY,60); // The scene viewport reports up as positive.
            break;
        case 4: {
            const FRotator Delta = (View-LastView).GetNormalized();
            Require(FMath::IsNearlyEqual(Delta.Yaw,14.f*InitialScale,.03f)
                && FMath::IsNearlyEqual(Delta.Pitch,2.1f*InitialScale,.03f), TEXT("mouse direction or gain"));
            const FVector Diagonal = FRotator(0,View.Yaw+45,0).Vector();
            Require(FVector::DotProduct((Here-LastPosition).GetSafeNormal2D(),Diagonal) > .998,
                TEXT("diagonal walk used the previous heading"));
            Require(View.Equals(PC->PlayerCameraManager->GetCameraRotation(),.05f), TEXT("camera pose lagged behind look input"));
            Key(EKeys::Escape,true);
            break;
        }
        case 5:
            Require(P->MenuOpen, TEXT("Escape did not open settings"));
            Key(EKeys::W,false); Key(EKeys::D,false); Key(EKeys::Escape,false);
            break;
        case 6: {
            Slider = FindSensitivitySlider(VC->GetWindow().ToSharedRef());
            Require(Slider.IsValid(), TEXT("sensitivity slider is missing"));
            if (!Slider) break;
            const FGeometry& G = Slider->GetCachedGeometry();
            Pointer = G.LocalToAbsolute(G.GetLocalSize()*.5f);
            // A background test window can live on a different macOS Space.
            // Resolve this window's painted hit grid, then use Slate's normal event router.
            auto Widgets = VC->GetWindow()->GetHittestGrid().GetBubblePath(Pointer,0.f,false,0);
            FWidgetPath Path(Widgets);
            Require(Path.IsValid() && Path.GetLastWidget() == Slider, TEXT("painted slider does not own its track"));
            if (!Path.IsValid() || Path.GetLastWidget() != Slider) break;
            App.RoutePointerDownEvent(Path,FPointerEvent(FSlateApplicationBase::CursorPointerIndex,Pointer,Pointer,
                {EKeys::LeftMouseButton},EKeys::LeftMouseButton,0,FModifierKeysState()));
            Require(Slider->HasMouseCapture(), TEXT("slider did not capture the press"));
            break;
        }
        case 7: case 8: {
            const FGeometry& G = Slider->GetCachedGeometry();
            const bool RightEnd = Frame==9;
            const FVector2D Next = G.LocalToAbsolute(FVector2D(RightEnd ? G.GetLocalSize().X+30 : -30.f,-42.f));
            App.RoutePointerMoveEvent(FWidgetPath(), FPointerEvent(FSlateApplicationBase::CursorPointerIndex,Next,Pointer,{EKeys::LeftMouseButton},EKeys::Invalid,0,FModifierKeysState()),false);
            Pointer = Next;
            Require(FMath::IsNearlyEqual(P->LookSensitivity,RightEnd ? P->MaxLookSensitivity : P->MinLookSensitivity),
                TEXT("drag outside the track lost the slider or missed an endpoint"));
            break;
        }
        case 9: {
            const FGeometry& G=Slider->GetCachedGeometry();
            // 100% is two thirds of the logarithmic track, inside the thumb travel.
            const float Width=G.GetLocalSize().X;
            const FVector2D Unity=G.LocalToAbsolute(FVector2D(8.f+(Width-16.f)*2.f/3.f,G.GetLocalSize().Y*.5f));
            App.RoutePointerMoveEvent(FWidgetPath(),FPointerEvent(FSlateApplicationBase::CursorPointerIndex,Unity,Pointer,{EKeys::LeftMouseButton},EKeys::Invalid,0,FModifierKeysState()),false);
            Pointer=Unity;
            Require(P->LookSensitivity==1.f,TEXT("the actual slider could not select exactly 100%"));
            App.RoutePointerUpEvent(FWidgetPath(), FPointerEvent(FSlateApplicationBase::CursorPointerIndex,Pointer,Pointer,{},EKeys::LeftMouseButton,0,FModifierKeysState()));
            Require(!Slider->HasMouseCapture(), TEXT("slider retained the cursor after release"));
            FConfigFile Saved;
            Saved.Read(FConfigCacheIni::GetDestIniFilename(TEXT("GameUserSettings"),nullptr,*FPaths::GeneratedConfigDir()));
            float SavedScale = 0;
            Require(Saved.GetFloat(TEXT("FifthAvenue"),TEXT("LookSensitivity"),SavedScale)
                && SavedScale==1.f, TEXT("released slider did not persist 100%"));
            App.ProcessKeyDownEvent(FKeyEvent(EKeys::Escape,FModifierKeysState(),0,false,0,0));
            App.ProcessKeyUpEvent(FKeyEvent(EKeys::Escape,FModifierKeysState(),0,false,0,0));
            Require(!P->MenuOpen, TEXT("Escape did not close the focused menu"));
            break;
        }
        case 10:
            Require(P->PointerReleased && PC->bShowMouseCursor, TEXT("closing settings captured the cursor"));
            Key(EKeys::LeftMouseButton,true);
            Key(EKeys::LeftMouseButton,false);
            P->SetLookSensitivity(InitialScale);
            Require(FVector::Dist2D(Here,LastPosition)<.1 && P->GetVelocity().Size2D()<.1,
                TEXT("movement resumed without a fresh key press"));
            IConsoleManager::Get().FindConsoleVariable(TEXT("t.MaxFPS"))->Set(0.f,ECVF_SetByCode);
            PanStart = LastTime = FPlatformTime::Seconds();
            break;
        default: {
            const double Now = FPlatformTime::Seconds();
            PanTimes.Add((Now-LastTime)*1000);
            LastTime = Now;
            // Pan continuously through two full circles at the player's saved sensitivity.
            Axis(EKeys::MouseX,90.f*Dt/(.035f*InitialScale));
            if (PanTimes.Num()%20==1) {
                FDynamicResolutionStateInfos Info;
                GEngine->GetDynamicResolutionCurrentStateInfos(Info);
                if (Info.Status==EDynamicResolutionStatus::Enabled) {
                    const float Scale = Info.ResolutionFractionApproximations[GDynamicPrimaryResolutionFraction];
                    if (Scale>0) {
                        MinScale=FMath::Min(MinScale,Scale);
                        MaxScale=FMath::Max(MaxScale,Scale);
                    }
                }
            }
            if (Now-PanStart >= 8.) {
                PanTimes.Sort();
                UE_LOG(LogTemp,Display,TEXT("Avenue look-around: frames=%d p95=%.2fms p99=%.2fms worst=%.2fms"),
                    PanTimes.Num(),PanTimes[FMath::FloorToInt(.95*(PanTimes.Num()-1))],
                    PanTimes[FMath::FloorToInt(.99*(PanTimes.Num()-1))],PanTimes.Last());
                if (MaxScale>0.f) UE_LOG(LogTemp,Display,TEXT("Avenue render scale: %.1f%% to %.1f%%"),100*MinScale,100*MaxScale);
                if (!Failed) UE_LOG(LogTemp,Display,TEXT("Avenue input checks passed"));
                Finish(*P);
                return;
            }
        }
        }
        LastPosition = Here;
        LastView = View;
        if (Failed && !PreviouslyFailed && Frame <= 10) {
            Key(EKeys::W,false); Key(EKeys::S,false); Key(EKeys::D,false);
            if (P->MenuOpen) P->ToggleMenu();
            Frame=10; // Measure turning independently of the functional checks.
        }
    }

    void Finish(AAvenueWalker& P)
    {
        P.SetLookSensitivity(InitialScale);
        GConfig->Flush(false,GGameUserSettingsIni);
        const uint8 ExitCode = Failed ? 1 : 0;
        FWorldDelegates::OnWorldPreActorTick.Remove(Handle);
        FPlatformMisc::RequestExitWithStatus(false,ExitCode);
    }
};
}

void StartAvenueInputTest(AAvenueWalker& Walker)
{
    auto Check = MakeShared<FInputCheck>();
    Check->Walker = &Walker;
    Check->Handle = FWorldDelegates::OnWorldPreActorTick.AddLambda(
        [Check](UWorld* World,ELevelTick Tick,float Dt) { Check->Tick(World,Tick,Dt); });
}
#endif
