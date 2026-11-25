#if !UE_BUILD_SHIPPING
#include "AvenueInputTest.h"
#include "../AvenueGameMode.h"
#include "../AvenueStreet.h"
#include "Camera/CameraComponent.h"
#include "Components/PoseableMeshComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/GameViewportClient.h"
#include "EngineUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputKeyEventArgs.h"
#include "Materials/MaterialInterface.h"
#include "UnrealClient.h"

namespace {
enum class EVisit { Drum, Pause, Inside, Return, Closed, Open, Aisle, Order, Serve, Carry, Fly, BackOnFoot, Park, Curb, Contact, Reset };
const FVector Shop(-14795.0317,59958.5815,0), ShopX(.487933,-.872881,0), Out(.872881,.487933,0);
FVector InShop(double X,double Z) { return Shop+ShopX*X+Out*Z; }
bool ResetPending=false, Failed=false;
FVector OriginalSpawn;
struct FVisit {
    AAvenueWalker* Player=nullptr;
    AAvenueCoffee* Coffee=nullptr;
    AAvenueDoor* Drum=nullptr;
    AAvenueCar* Car=nullptr;
    AAvenueTraveller* Sedan=nullptr;
    FDelegateHandle Handle;
    EVisit Stage=EVisit::Drum;
    float Age=0,ParkYaw=0,DrumYaw=0;
    int Waypoint=0;
    bool Started=false, BrewingSeen=false, HandSeen=false, FlightRequested=false, Ascending=false;
    FVector Paused, StartCar;
    FVector Standing, FlightStart;
    FRotator StandingLook;
    double LastContactTick=0;
    TArray<double> ContactFrames;
    void Key(FKey K,bool Down) const {
        auto* V=Player->GetWorld()->GetGameViewport();
        V->InputKey(FInputKeyEventArgs(V->Viewport,FInputDeviceId::CreateFromInternalId(0),K,
            Down?IE_Pressed:IE_Released,Down?1.f:0.f,false,FPlatformTime::Cycles64()));
    }
    void Tap(FKey K) { Key(K,true);Key(K,false); }
    void Require(bool Ok,const TCHAR* Why) const {
        if(!Ok) {
            Failed=true;
            UE_LOG(LogTemp,Error,TEXT("Avenue block regression: %s at %s (stage %d)"),Why,*Player->GetActorLocation().ToCompactString(),int(Stage));
        }
    }
    void Next(EVisit S) { Stage=S; Age=0; }
    void Place(FVector Spot,FVector Direction) {
        Key(EKeys::W,false); Key(EKeys::D,false);
        Player->SetActorLocation(Spot+FVector(0,0,104),false,nullptr,ETeleportType::TeleportPhysics);
        Player->GetCharacterMovement()->StopMovementImmediately();
        Player->GetController()->SetControlRotation(Direction.Rotation());
    }
    void SetSwingStart() {
        Place(InShop(1555,165),-Out); Next(EVisit::Closed);
    }
    void Tick(UWorld* W,ELevelTick,float Dt) {
        if(Player->GetWorld()!=W || W->GetTimeSeconds()<1.5f) return;
        Age+=Dt;
        const FVector Here=Player->GetActorLocation();
        const double D=FVector::DotProduct(Here-Drum->GetActorLocation(),Out);
        if(!Started) {
            Started=true; OriginalSpawn=Here; DrumYaw=Drum->GetActorRotation().Yaw;
            Place(Drum->GetActorLocation()+Out*170,-Out); Key(EKeys::W,true);
            return;
        }
        switch(Stage) {
        case EVisit::Drum:
            if(D<10) {Key(EKeys::W,false);Paused=Here;Next(EVisit::Pause);}
            else if(Age>5) {Require(false,TEXT("cannot push through the revolving entrance")); SetSwingStart();}
            break;
        case EVisit::Pause:
            if(Age>.65f) {
                Require(FVector::Dist2D(Here,Paused)<6,TEXT("released walker drifted inside drum"));
                Key(EKeys::W,true);Next(EVisit::Inside);
            }
            break;
        case EVisit::Inside:
            if(D< -153 || Age>4) {
                Require(D< -150 && FMath::Abs(FMath::FindDeltaAngleDegrees(DrumYaw,Drum->GetActorRotation().Yaw))>15,TEXT("rotor did not clear inside opening"));
                Key(EKeys::W,false); Player->GetController()->SetControlRotation(Out.Rotation());Key(EKeys::W,true);Next(EVisit::Return);
            }
            break;
        case EVisit::Return:
            if(D>154 || Age>5) {Require(D>150,TEXT("revolving exit blocked"));SetSwingStart();}
            break;
        case EVisit::Closed:
            if(Age<.3f) Key(EKeys::W,true);
            if(Age>1.2f) {
                Require(((Here-Shop)|Out)>24,TEXT("closed swing door leaked"));
                Key(EKeys::W,false);Tap(EKeys::E);Next(EVisit::Open);
            }
            break;
        case EVisit::Open:
            if(Age>.7f) {Next(EVisit::Aisle);Key(EKeys::W,true);}
            break;
        case EVisit::Aisle: {
            const FVector Targets[]={InShop(1555,-575),InShop(650,-575),InShop(630,-900)};
            const FVector Goal=(Targets[Waypoint]-Here).GetSafeNormal2D();
            Player->GetController()->SetControlRotation(Goal.Rotation());
            if(FVector::Dist2D(Here,Targets[Waypoint])<15) {
                ++Waypoint; Age=0;
                if(Waypoint==3) {Key(EKeys::W,false);Next(EVisit::Order);}
            } else if(Age>8) {
                Require(false,TEXT("Reserve aisle blocked"));Place(InShop(630,-900),-ShopX);Next(EVisit::Order);
            }
            break;
        }
        case EVisit::Order:
            if(Age>.35f) {
                Require(Coffee->InReach(Here-FVector(0,0,86)),TEXT("counter interaction missing"));
                Player->GetController()->SetControlRotation((Coffee->GetActorLocation()-Player->FindComponentByClass<UCameraComponent>()->GetComponentLocation()).Rotation());
                Tap(EKeys::E);Next(EVisit::Serve);
            }
            break;
        case EVisit::Serve:
            BrewingSeen|=Coffee->Prompt().Contains(TEXT("Brewing"));
            if(Coffee->Cup->IsVisible() && Coffee->Prompt().Contains(TEXT("Brewing")) && Coffee->Barista) {
                auto* Arm=Coffee->Barista->FindComponentByClass<UPoseableMeshComponent>();
                HandSeen|=Arm && Arm->IsVisible() && FVector::Dist2D(Coffee->GetActorLocation(),Coffee->BrewStart)>12;
            }
            if(Age>3.15f) {
                Require(BrewingSeen && HandSeen && Coffee->Prompt().Contains(TEXT("Take")),TEXT("barista did not present the cup"));
                auto* Arm=Coffee->Barista->FindComponentByClass<UPoseableMeshComponent>();
                Require(Arm && FVector::Dist(Arm->GetBoneLocationByName(TEXT("hand_r"),EBoneSpaces::WorldSpace),
                    Coffee->GetActorLocation()+FVector(0,0,7))<12,TEXT("offered cup missed the barista's hand"));
                FScreenshotRequest::RequestScreenshot(TEXT("ReserveHandoff.png"),false,false);
                Tap(EKeys::E);Next(EVisit::Carry);
            }
            break;
        case EVisit::Carry:
            if(Age>.65f) {
                Require(Coffee->Cup->GetAttachParent()==Player->FindComponentByClass<UCameraComponent>() &&
                    Coffee->Cup->GetStaticMesh()==Coffee->HeldModel && Coffee->Cup->GetRelativeTransform().Equals(Coffee->Grip,.1),
                    TEXT("cup/hand did not finish at the source wrist pose"));
                Standing=Here; StandingLook=Player->GetControlRotation();
                FScreenshotRequest::RequestScreenshot(TEXT("HoldingCoffee.png"),false,false);
                Next(EVisit::Fly);
            }
            break;
        case EVisit::Fly: {
            auto* Eye=Player->FindComponentByClass<UCameraComponent>();
            if(!FlightRequested && Age>.18f) { Tap(EKeys::F); FlightRequested=true; }
            if(Player->IsInFreecam() && !Ascending) { FlightStart=Eye->GetComponentLocation(); Key(EKeys::E,true); Ascending=true; }
            if(Age>.7f) {
                Require(Ascending && Here.Equals(Standing,1.) && Eye->GetComponentLocation().Z-FlightStart.Z>350 &&
                        Player->GetMesh()->IsVisible() && !Coffee->Cup->IsVisible(),TEXT("freecam did not leave the body and cup on foot"));
                Key(EKeys::E,false); Tap(EKeys::F); Next(EVisit::BackOnFoot);
            }
            break;
        }
        case EVisit::BackOnFoot:
            if(Age>.15f) {
                Require(!Player->IsInFreecam() && !Player->GetMesh()->IsVisible() && Coffee->Cup->IsVisible() &&
                        StandingLook.Equals(Player->GetControlRotation(),.15f),TEXT("freecam did not restore the standing view"));
                const FVector Crossing=FVector(-20809.9,57389.1,0)+Out*8420-ShopX*1200;
                FHitResult Floor;
                W->LineTraceSingleByChannel(Floor,Crossing+FVector(0,0,600),Crossing-FVector(0,0,600),ECC_Visibility);
                Require(Floor.bBlockingHit,TEXT("no ground at curb approach"));
                StartCar=Floor.ImpactPoint+FVector(0,0,62);
                Car->SetActorLocationAndRotation(StartCar,Out.Rotation()); Car->Silence();
                Place(StartCar+ShopX*163,Out);Tap(EKeys::E);Next(EVisit::Park);
                ParkYaw=Car->GetActorRotation().Yaw; Key(EKeys::D,true);
            }
            break;
        case EVisit::Park:
            if(Age>.55f) {
                Require(Player->Driven==Car && FMath::Abs(FMath::FindDeltaAngleDegrees(ParkYaw,Car->GetActorRotation().Yaw))<.2,
                    TEXT("stationary steering rotated the chassis or failed to enter"));
                Key(EKeys::D,false);
                Next(EVisit::Curb);
            }
            break;
        case EVisit::Curb: {
            if(Age>.4f) Key(EKeys::W,true);
            const float Travel=(Car->GetActorLocation()-StartCar)|Out;
            if(Travel>785 || Age>4.5f) {
                const float Rise=Car->GetActorLocation().Z-StartCar.Z;
                UE_LOG(LogTemp,Display,TEXT("Avenue curb travel %.1f cm, rise %.1f cm, speed %.1f mph"),Travel,Rise,Car->Speed()*.0223694f);
                Require(Travel>760 && Rise>5 && Car->HasTireContact(),TEXT("wheels/chassis caught on the surveyed curb"));
                auto* Driver=Car->FindComponentByClass<UPoseableMeshComponent>();
                bool Shoes=Driver && Driver->IsVisible();
                if(Shoes) for(FName Name:{FName("foot_l"),FName("foot_r")})
                    Shoes &= Driver->GetBoneIndex(Name)!=INDEX_NONE && Car->GetActorTransform().InverseTransformPosition(Driver->GetBoneLocationByName(Name,EBoneSpaces::WorldSpace)).Z> -43;
                Require(Shoes,TEXT("driver ankle below the cabin floor"));
                auto* Spray=Car->FindComponentByClass<UInstancedStaticMeshComponent>();
                Require(Spray && Spray->GetMaterial(0) && Spray->GetMaterial(0)->GetFName()==TEXT("M_WheelPowder")
                    && Spray->GetInstanceCount()>0 && Spray->GetInstanceCount()<=96,TEXT("no bounded wheel spray on the snowy curb"));
                Key(EKeys::W,false);
                Car->Silence();
                // Use the actual traffic Tesla and authored road. Stop it across
                // the lane so the player holds contact for several seconds.
                const FVector Along=-ShopX;
                FHitResult Ground;
                const FVector Lane=FVector(-20809.9,57389.1,0)+Out*8350+Along*1900;
                W->LineTraceSingleByChannel(Ground,Lane+FVector(0,0,400),Lane-FVector(0,0,400),ECC_Visibility);
                Car->SetActorLocationAndRotation(Ground.ImpactPoint+FVector(0,0,62),Along.Rotation());
                Sedan->SetActorTickEnabled(false);
                Sedan->SetActorLocationAndRotation(Ground.ImpactPoint+Along*745,Out.Rotation());
                Key(EKeys::W,true); LastContactTick=FPlatformTime::Seconds(); Next(EVisit::Contact);
            }
            break;
        }
        case EVisit::Contact: {
            const double Now=FPlatformTime::Seconds();
            if(Car->LastDriveBlocker.Get()==Sedan) ContactFrames.Add((Now-LastContactTick)*1000);
            LastContactTick=Now;
            if(Age>5.f) {
                Require(ContactFrames.Num()>=15,TEXT("sustained Tesla-to-Tesla contact was not exercised"));
                if(!ContactFrames.IsEmpty()) {
                    ContactFrames.Sort();
                    UE_LOG(LogTemp,Display,TEXT("Avenue Tesla contact: %d frames p99 %.2f ms worst %.2f ms"),ContactFrames.Num(),
                        ContactFrames[FMath::FloorToInt((ContactFrames.Num()-1)*.99)],ContactFrames.Last());
                }
                Key(EKeys::W,false); ResetPending=true; Next(EVisit::Reset);Tap(EKeys::R);
            }
            break;
        }
        case EVisit::Reset:
            if(Age>5) { Require(false,TEXT("R did not reload the block")); FPlatformMisc::RequestExitWithStatus(false,1); }
            break;
        }
    }
};
TSharedPtr<FVisit> ActiveVisit;
}
void StartAvenueBlockTest(AAvenueWalker& Walker) {
    if(ActiveVisit) FWorldDelegates::OnWorldPostActorTick.Remove(ActiveVisit->Handle);
    if(ResetPending) {
        const bool ResetOk=!Walker.Driven && FVector::Dist2D(Walker.GetActorLocation(),OriginalSpawn)<20;
        if(!ResetOk) UE_LOG(LogTemp,Error,TEXT("Avenue block regression: reset did not restore sidewalk spawn"));
        if(ResetOk && !Failed) UE_LOG(LogTemp,Display,TEXT("Avenue block checks passed: revolving entrance both ways, release, cafe route, handoff, curb, shoes, reset"));
        FPlatformMisc::RequestExitWithStatus(false,(Failed || !ResetOk)?1:0);
        return;
    }
    ActiveVisit=MakeShared<FVisit>();
    ActiveVisit->Player=&Walker;
    for(TActorIterator<AAvenueCar> I(Walker.GetWorld());I;++I) ActiveVisit->Car=*I;
    for(TActorIterator<AAvenueCoffee> I(Walker.GetWorld());I;++I) ActiveVisit->Coffee=*I;
    for(TActorIterator<AAvenueTraveller> I(Walker.GetWorld());I;++I)
        if(I->Traffic && !I->AvenueTraffic) ActiveVisit->Sedan=*I;
    for(TActorIterator<AAvenueDoor> I(Walker.GetWorld());I;++I)
        if(I->Revolving && FVector::Dist2D(I->GetActorLocation(),InShop(1342,-100))<100) ActiveVisit->Drum=*I;
    if(!ActiveVisit->Drum || !ActiveVisit->Coffee || !ActiveVisit->Car || !ActiveVisit->Sedan) {
        UE_LOG(LogTemp,Error,TEXT("Avenue block regression: missing tested actors"));FPlatformMisc::RequestExitWithStatus(false,1);return;
    }
    ActiveVisit->Handle=FWorldDelegates::OnWorldPostActorTick.AddSP(ActiveVisit.ToSharedRef(),&FVisit::Tick);
}
#endif
