#include "AvenueGameMode.h"
#include "AvenueStreet.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Animation/AnimSequence.h"
#include "Engine/SkeletalMesh.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "DrawDebugHelpers.h"
#include "UnrealClient.h"
#include "HAL/PlatformMisc.h"
#include "Camera/CameraComponent.h"
#include "Components/AudioComponent.h"
#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/InputComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/Canvas.h"
#include "Engine/DirectionalLight.h"
#include "Engine/Engine.h"
#include "Engine/SkyLight.h"
#include "Engine/PostProcessVolume.h"
#include "Engine/StaticMeshActor.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/StaticMesh.h"
#include "EngineUtils.h"
#include "HAL/IConsoleManager.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/GameUserSettings.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Sound/SoundWave.h"

namespace {
USoundWave* Recording(const FString& Name) {
    return LoadObject<USoundWave>(nullptr,*("/Game/Manhattan/Audio/"+Name+"."+Name));
}
bool FloorAt(UWorld* World, const FVector& Start, const FVector& End, FHitResult& Hit,const AActor* Ignore) {
    return World->LineTraceSingleByChannel(Hit,Start,End,ECC_Visibility,FCollisionQueryParams(TEXT("StreetContact"),true,Ignore));
}
}

AAvenueGameMode::AAvenueGameMode() {
    DefaultPawnClass=AAvenueWalker::StaticClass();
    HUDClass=AAvenueHUD::StaticClass();
}

AAvenueCar::AAvenueCar() {
    Chassis=CreateDefaultSubobject<UBoxComponent>("Chassis");
    SetRootComponent(Chassis);
    Chassis->SetBoxExtent(FVector(222,94,44));
    Chassis->SetCollisionProfileName("BlockAllDynamic");
    Exterior=CreateDefaultSubobject<UStaticMeshComponent>("Sedan");
    Exterior->SetupAttachment(Chassis);
    Exterior->SetRelativeLocation(FVector(0,0,-62));
    Exterior->SetRelativeRotation(FRotator(0,90,0));
    Exterior->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    for(int i=0;i<4;++i) {
        auto* Wheel=CreateDefaultSubobject<UStaticMeshComponent>(*FString::Printf(TEXT("Wheel%d"),i));
        Wheel->SetupAttachment(Exterior);
        Wheel->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Wheels.Add(Wheel); Hubs.Add(FVector::ZeroVector);
    }
    Driver=CreateDefaultSubobject<USkeletalMeshComponent>("Driver");
    Driver->SetupAttachment(Chassis);
    Driver->SetRelativeLocation(FVector(29,-39,-72));
    Driver->SetRelativeRotation(FRotator(0,-90,0));
    Driver->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Driver->SetVisibility(false);
    Driver->SetCastShadow(false);
    const TCHAR* Names[]={TEXT("tesla_forward"),TEXT("tesla_reverse"),TEXT("sedan_road"),TEXT("tire_scuff"),TEXT("tire_scuff_alt")};
    for(const TCHAR* Name:Names) {
        auto* Audio=CreateDefaultSubobject<UAudioComponent>(Name);
        Audio->SetupAttachment(Chassis);
        Audio->bAutoActivate=false;
        AudioLayers.Add(Audio);
    }
}
void AAvenueCar::BeginPlay() {
    Super::BeginPlay();
    for(int32 i=0;i<AudioLayers.Num();++i) {
        UAudioComponent* Audio=AudioLayers[i];
        USoundWave* Wave=Recording(i>=3?FString("tire_scuff"):Audio->GetName());
        if(!Wave) continue;
        Wave->bLooping=i<3;
        Audio->SetSound(Wave);
        Audio->SetRelativeLocation(FVector(i==1?-185:(i>=3?-134:150),0,-27));
        Audio->bOverrideAttenuation=true;
        Audio->AttenuationOverrides.AttenuationShapeExtents.X=i<2?350:550;
        Audio->AttenuationOverrides.FalloffDistance=i<2?4150:8950;
        Audio->SetVolumeMultiplier(.00025f);
    }
    const FString Prefix=TEXT("/Game/Manhattan/Citizens/sam/sam/SkeletalMeshes/sam");
    Driver->SetSkeletalMeshAsset(LoadObject<USkeletalMesh>(nullptr,*Prefix));
    Driver->PlayAnimation(LoadObject<UAnimSequence>(nullptr,*(Prefix+"Sit_Stand")),false);
    Driver->SetPosition(3,false);
    Driver->SetPlayRate(0);
}
void AAvenueCar::SetWheel(int Index,UStaticMesh* Mesh,FVector Center) {
    if(!Wheels.IsValidIndex(Index)) return;
    Wheels[Index]->SetStaticMesh(Mesh);
    Wheels[Index]->SetRelativeLocation(Center);
    Hubs[Index]=Center;
}
void AAvenueCar::ShowDriver(bool Visible) { Driver->SetVisibility(Visible); }
void AAvenueCar::Signal(bool Left) {
    const int Requested=Left?-1:1;
    SignalSide=SignalSide==Requested?0:Requested;
    SignalClock=0;
}
void AAvenueCar::Silence() {
    for(UAudioComponent* Audio:AudioLayers) Audio->Stop();
    VelocityXY=FVector::ZeroVector;
    SignalSide=0;
    SignedSpeed=ShiftWait=SlipAngle=YawRate=Steering=SteeringVelocity=ScuffDuration=ScuffGain=0;
    Sliding=Backing=SignalLit=false;
}
void AAvenueCar::Drive(float Delta,float Throttle,float InputSteer,bool Handbrake) {
    const float Dt=FMath::Min(Delta,.05f);
    if (!Exterior->GetStaticMesh()) {
        Exterior->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,TEXT("/Game/Manhattan/Street/Sedan/StaticMeshes/Sedan.Sedan")));
    }
    const FVector Up=FVector::UpVector;
    FHitResult Floor;
    const FVector Center=GetActorLocation();
    const bool HasFloor=FloorAt(GetWorld(),Center+Up*30,Center-Up*100,Floor,this);
    const bool Grounded=HasFloor && Center.Z-Floor.ImpactPoint.Z<76 && VerticalSpeed<220;
    // Match the Godot drivetrain in metres and radians until the world-space sweep.
    const float Speed=FMath::Abs(SignedSpeed);
    const float PreviousYaw=GetActorRotation().Yaw;
    if(Grounded) {
        bool Braking=(Throttle<0 && !Backing)||(Throttle>0 && Backing);
        if(Braking && Speed<.001f && !Handbrake) {
            ShiftWait+=Dt;
            if(ShiftWait>=.30f) { Backing=Throttle<0; ShiftWait=0; Braking=false; }
        } else ShiftWait=0;
        if(Braking) {
            const float Brake=FMath::Lerp(10.5f,17.f,FMath::SmoothStep(12.f,38.f,Speed));
            SignedSpeed=FMath::FInterpConstantTo(SignedSpeed,0,Dt,Brake*FMath::Abs(Throttle));
        } else if(Handbrake) {
            const float Pull=3*FMath::Max(0.f,Throttle)*FMath::Abs(InputSteer)*FMath::SmoothStep(2.f,6.f,SignedSpeed);
            SignedSpeed=FMath::FInterpConstantTo(SignedSpeed,0,Dt,5.5f+2.7f*FMath::Abs(FMath::Sin(SlipAngle))-Pull);
        } else if(FMath::Abs(Throttle)>.001f) {
            const float Limit=Throttle>0?58.1152f:5.f;
            const float Force=(Throttle>0?5.1f:2.7f)*FMath::Abs(Throttle);
            SignedSpeed=FMath::FInterpConstantTo(SignedSpeed,FMath::Sign(Throttle)*Limit,Dt,Force*FMath::Max(.1f,1-FMath::Pow(Speed/Limit,1.6f)));
        } else SignedSpeed=FMath::FInterpConstantTo(SignedSpeed,0,Dt,1.12f+.001f*Speed*Speed);
        const float Pace=FMath::Abs(SignedSpeed);
        const float Weight=FMath::SmoothStep(4.5f,12.f,Pace);
        const float Limit=FMath::Min(FMath::Lerp(.51f,1.f,Weight),FMath::Atan(3.3f/(1+Pace/20)*2.875f/FMath::Max(1.f,Pace)));
        const float Target=InputSteer*Limit, Tau=FMath::Lerp(.058f,.021f,Weight);
        const float Offset=Steering-Target, Step=(SteeringVelocity+Offset/Tau)*Dt, Decay=FMath::Exp(-Dt/Tau);
        Steering=FMath::Clamp(Target+(Offset+Step)*Decay,-Limit,Limit);
        SteeringVelocity=(SteeringVelocity-Step/Tau)*Decay;
        const float Drift=Handbrake?FMath::SmoothStep(3.5f,8.f,SignedSpeed)*FMath::Abs(InputSteer):0;
        Sliding|=Drift>0;
        float Desired=SignedSpeed*FMath::Tan(Steering)/2.875f*(1+.64f*Drift);
        const float Grip=10.5f*(Handbrake?FMath::Lerp(.4f,.79f,FMath::Abs(Steering)/Limit):1.f)/FMath::Max(3.f,Pace);
        if(Sliding) {
            if(Drift>0 && Desired*SlipAngle<0) Desired=FMath::Lerp(Desired,FMath::Sign(Desired)*Grip,FMath::SmoothStep(.48f,.93f,FMath::Abs(SlipAngle)));
            else if(!Handbrake) Desired+=FMath::Clamp(SlipAngle*.85f,-.75f,.75f);
            YawRate=FMath::FInterpConstantTo(YawRate,Desired,Dt,5.8f);
            SlipAngle=FMath::FInterpConstantTo(FMath::UnwindRadians(SlipAngle-YawRate*Dt),0,Dt,Grip);
            if(Pace<.1f || (Drift==0 && FMath::IsNearlyZero(SlipAngle) && FMath::IsNearlyEqual(Desired,YawRate))) Sliding=false;
        } else { YawRate=Desired; SlipAngle=0; }
        if(Pace<.1f) { YawRate=0; SlipAngle=0; }
        AddActorWorldRotation(FRotator(0,FMath::RadiansToDegrees(YawRate*Dt),0));
        VelocityXY=GetActorForwardVector().GetSafeNormal2D().RotateAngleAxis(FMath::RadiansToDegrees(SlipAngle),Up)*SignedSpeed*100;
        VerticalSpeed=FMath::Clamp(-FVector::DotProduct(Floor.ImpactNormal,VelocityXY)/FMath::Max(.25f,Floor.ImpactNormal.Z),-2200,2200);
    } else { VerticalSpeed-=980*Dt; }
    FHitResult Block;
    FVector Travel=VelocityXY*Dt+Up*(VerticalSpeed*Dt);
    if(Grounded) Travel.Z+=FMath::Clamp(Floor.ImpactPoint.Z+62-Center.Z,-6.f,9.f);
    AddActorWorldOffset(Travel,true,&Block);
    if(Block.bBlockingHit) {
        if(Block.Normal.Z<.5f) {
            const FVector Slide=FVector::VectorPlaneProject(VelocityXY,Block.Normal.GetSafeNormal2D());
            FHitResult Next;
            AddActorWorldOffset(Slide*Dt*(1-Block.Time),true,&Next);
            SignedSpeed=FVector::DotProduct(Slide,GetActorForwardVector().GetSafeNormal2D())*.01f;
            VelocityXY=Slide;
            if(Block.bStartPenetrating) {
                SetActorRotation(FRotator(0,PreviousYaw,0));
                AddActorWorldOffset(Block.Normal*(Block.PenetrationDepth+.25f),false);
            }
        }
        else VerticalSpeed=FMath::Max(0.f,VerticalSpeed);
    }
    if(Grounded) {
        const FRotator Grade=FRotationMatrix::MakeFromXZ(GetActorForwardVector().GetSafeNormal2D(),Floor.ImpactNormal).Rotator();
        SetActorRotation(FMath::RInterpTo(GetActorRotation(),Grade,Dt,6));
    }
    Spin=FMath::Fmod(Spin+FMath::RadiansToDegrees(SignedSpeed*100*Dt/33.5f),360.f);
    for(int i=0;i<Wheels.Num();++i) {
        FHitResult Road;
        const FVector Hub=Exterior->GetComponentTransform().TransformPosition(Hubs[i]);
        const bool Contact=FloorAt(GetWorld(),Hub+Up*18,Hub-Up*47,Road,this);
        const float TravelZ=Contact?FMath::Clamp<float>(Road.ImpactPoint.Z+34-Hub.Z,-8,7):-8;
        Wheels[i]->SetRelativeLocation(Hubs[i]+Up*TravelZ);
        Wheels[i]->SetRelativeRotation(FRotator(0,i<2?FMath::RadiansToDegrees(Steering):0.f,-Spin));
    }
    UpdateAudio(Dt,FMath::Abs(SignedSpeed),SlipAngle,SignedSpeed*YawRate,Grounded);
}
void AAvenueCar::UpdateAudio(float Dt,float Speed,float Slip,float Corner,bool Contact) {
    const float Blend=1-FMath::Exp(-8*Dt);
    const float Low=FMath::SmoothStep(0.f,9.f,Speed);
    const float Reverse=FMath::SmoothStep(0.f,5.f,Speed);
    const float Road=(.15f*FMath::SmoothStep(0.f,3.5f,Speed)+.18f*FMath::SmoothStep(3.5f,27.f,Speed))*(1+.18f*FMath::Min(1.f,FMath::Abs(Corner)/12));
    const float Gain[]={Backing?0:2*FMath::Lerp(.027f,.085f,Low)*(1-FMath::SmoothStep(9.f,11.18f,Speed)),Backing?FMath::Lerp(.085f,.36f,Reverse):0,Contact?2.5f*Road:0};
    const float Pitch[]={1,1+.32f*Reverse,.72f+.5f*FMath::Min(1.f,Speed/58)};
    for(int i=0;i<3;++i) {
        auto* A=AudioLayers[i].Get();
        A->SetVolumeMultiplier(FMath::Lerp(A->VolumeMultiplier,FMath::Max(.00025f,Gain[i]),Blend));
        A->SetPitchMultiplier(FMath::Lerp(A->PitchMultiplier,Pitch[i],Blend));
        if(!A->IsPlaying() && A->Sound) A->Play();
    }
    float SideSpeed=Contact?Speed*FMath::Abs(FMath::Sin(Slip)):0;
    float Intensity=SideSpeed/(4+SideSpeed);
    float Target=.96f*Intensity*FMath::SmoothStep(.15f,1.5f,SideSpeed)*FMath::Lerp(.82f,1.f,FMath::Min(1.f,FMath::Abs(Corner)/10));
    ScuffGain=FMath::Lerp(ScuffGain,Target,1-FMath::Exp(-Dt*(Target>ScuffGain?12:7)));
    if(ScuffGain>.0005f) {
        ScuffAge+=Dt;
        if(ScuffAge>=ScuffDuration) {
            ScuffVoice=1-ScuffVoice; ScuffAge=0; ScuffDuration=FMath::FRandRange(1.7f,3.4f);
            auto* Voice=AudioLayers[3+ScuffVoice].Get();
            if(Voice->Sound) Voice->Play(FMath::FRandRange(0,FMath::Max(0.f,Voice->Sound->GetDuration()-(ScuffDuration+.65f)*1.35f)));
        }
        const float Fade=FMath::Min(1.f,ScuffAge/.55f)*HALF_PI;
        for(int i=0;i<2;++i) {
            auto* Voice=AudioLayers[3+i].Get();
            const float Weight=i==ScuffVoice?(AudioLayers[4-i]->IsPlaying()?FMath::Sin(Fade):1):FMath::Cos(Fade);
            Voice->SetPitchMultiplier(.73f+.57f*Intensity);
            Voice->SetVolumeMultiplier(FMath::Max(.00025f,Weight*ScuffGain));
            if(i!=ScuffVoice && ScuffAge>=.55f) Voice->Stop();
        }
    } else if(ScuffDuration>0) { AudioLayers[3]->Stop(); AudioLayers[4]->Stop(); ScuffDuration=0; }
    if(SignalSide && (SignalClock-=Dt)<=0) {
        SignalLit=!SignalLit;
        UGameplayStatics::PlaySound2D(this,Recording(SignalLit?"turn_signal":"turn_signal_off"),.56f);
        SignalClock=.43f;
    }
}

AAvenueWalker::AAvenueWalker() {
    PrimaryActorTick.bCanEverTick=true;
    GetCapsuleComponent()->InitCapsuleSize(30,87);
    Camera=CreateDefaultSubobject<UCameraComponent>("Eyes");
    Camera->SetupAttachment(GetCapsuleComponent());
    Camera->SetRelativeLocation(FVector(0,0,75));
    Camera->bUsePawnControlRotation=true;
    Camera->FieldOfView=85;
    GetMesh()->SetCastShadow(false);
    GetMesh()->SetOwnerNoSee(true);
    bUseControllerRotationYaw=true;
    auto* Movement=GetCharacterMovement();
    Movement->MaxWalkSpeed=214.58f;
    Movement->MaxAcceleration=5400;
    Movement->BrakingDecelerationWalking=5000;
    Movement->GroundFriction=12;
    Movement->AirControl=.62f;
    Movement->JumpZVelocity=465;
}
void AAvenueWalker::BeginPlay() {
    Super::BeginPlay();
    auto* Settings=GEngine->GetGameUserSettings();
    GConfig->GetFloat(TEXT("FifthAvenue"),TEXT("LookSensitivity"),LookSensitivity,GGameUserSettingsIni);
    LookSensitivity=FMath::Clamp(LookSensitivity,.25f,1.5f);
    if(!GConfig->GetInt(TEXT("FifthAvenue"),TEXT("Quality"),Quality,GGameUserSettingsIni)) Quality=0;
    Bench=FParse::Param(FCommandLine::Get(),TEXT("AvenueBench"));
    RoadTest=FParse::Param(FCommandLine::Get(),TEXT("AvenueRoadTest"));
    if(Settings) ChangeQuality(Quality);
    Night=Bench;
    ToggleDay();
    if(Bench) {
        BenchStart=LastFrame=FPlatformTime::Seconds();
        BlockBench=FParse::Param(FCommandLine::Get(),TEXT("AvenueBlockBench"));
        DrivingBench=FParse::Param(FCommandLine::Get(),TEXT("AvenueDriveBench"));
        for(int i=0;i<4;i++) {
            auto* Flash=NewObject<UPointLightComponent>(this);
            Flash->SetMobility(EComponentMobility::Movable);
            Flash->SetCastShadows(false);
            Flash->SetAttenuationRadius(720);
            Flash->SetLightColor(FLinearColor(1,.58,.21));
            Flash->SetIntensity(0);
            Flash->RegisterComponent();
            Flashes.Add(Flash);
        }
    }
}
void AAvenueWalker::SetLookSensitivity(float Value) {
    const float NewValue=FMath::Clamp(FMath::GridSnap(Value,.05f),.25f,1.5f);
    if(FMath::IsNearlyEqual(NewValue,LookSensitivity)) return;
    LookSensitivity=NewValue;
    GConfig->SetFloat(TEXT("FifthAvenue"),TEXT("LookSensitivity"),LookSensitivity,GGameUserSettingsIni);
}
void AAvenueWalker::ChangeQuality(int NewQuality) {
    Quality=FMath::Clamp(NewQuality,0,3);
    if(auto* S=GEngine->GetGameUserSettings()) {
        S->SetOverallScalabilityLevel(Quality);
        S->SetShadowQuality(FMath::Max(1,Quality));
        S->SetTextureQuality(FMath::Max(2,Quality));
        S->SetResolutionScaleValueEx(72.f+Quality*(28.f/3.f));
        S->SetFrameRateLimit(60);
        S->ApplyNonResolutionSettings();
        if(Bench) IConsoleManager::Get().FindConsoleVariable(TEXT("t.MaxFPS"))->Set(0.f,ECVF_SetByCode);
        S->SaveSettings();
        GConfig->SetInt(TEXT("FifthAvenue"),TEXT("Quality"),Quality,GGameUserSettingsIni);
        GConfig->Flush(false,GGameUserSettingsIni);
    }
}
void AAvenueWalker::SetupPlayerInputComponent(UInputComponent* I) {
    Super::SetupPlayerInputComponent(I);
    I->BindAxis("Forward",this,&AAvenueWalker::MoveForward);
    I->BindAxis("Right",this,&AAvenueWalker::MoveRight);
    I->BindAxis("Yaw",this,&AAvenueWalker::LookYaw);
    I->BindAxis("Pitch",this,&AAvenueWalker::LookPitch);
    I->BindKey(EKeys::E,IE_Pressed,this,&AAvenueWalker::DriveOrInteract);
    I->BindKey(EKeys::T,IE_Pressed,this,&AAvenueWalker::ToggleDay);
    I->BindKey(EKeys::J,IE_Pressed,this,&AAvenueWalker::LookAtHerald);
    I->BindKey(EKeys::F,IE_Pressed,this,&AAvenueWalker::ToggleFlight);
    I->BindKey(EKeys::Escape,IE_Pressed,this,&AAvenueWalker::ToggleMenu);
    I->BindKey(EKeys::SpaceBar,IE_Pressed,this,&AAvenueWalker::StartJump);
    I->BindKey(EKeys::SpaceBar,IE_Released,this,&ACharacter::StopJumping);
    I->BindKey(EKeys::LeftShift,IE_Pressed,this,&AAvenueWalker::StartSprint);
    I->BindKey(EKeys::LeftShift,IE_Released,this,&AAvenueWalker::EndSprint);
    I->BindKey(EKeys::Left,IE_Pressed,this,&AAvenueWalker::LeftSignal);
    I->BindKey(EKeys::Right,IE_Pressed,this,&AAvenueWalker::RightSignal);
}
void AAvenueWalker::MoveForward(float V) {
    Forward=V;
    if(!MenuOpen&&!Driven) AddMovementInput(GetCharacterMovement()->IsFlying()?GetControlRotation().Vector():GetActorForwardVector(),V);
}
void AAvenueWalker::MoveRight(float V) { Side=V; if(!MenuOpen&&!Driven) AddMovementInput(GetActorRightVector(),V); }
void AAvenueWalker::LookYaw(float V) {
    if(MenuOpen || V==0) return;
    if(Driven) OrbitHold=1.5f;
    AddControllerYawInput(V*LookSensitivity*FMath::RadiansToDegrees(Driven?.0034f:.0026f));
}
void AAvenueWalker::LookPitch(float V) {
    if(MenuOpen || V==0) return;
    if(Driven) OrbitHold=1.5f;
    AddControllerPitchInput(V*LookSensitivity*FMath::RadiansToDegrees(Driven?.0025f:.0026f));
}
void AAvenueWalker::StartJump() { if(!MenuOpen&&!Driven&&GetCharacterMovement()->IsMovingOnGround()) { Step(); Jump(); } }
void AAvenueWalker::Step() {
    FHitResult Floor;
    FloorAt(GetWorld(),GetActorLocation(),GetActorLocation()-FVector(0,0,130),Floor,this);
    const bool Snow=Floor.GetActor() && Floor.GetActor()->ActorHasTag("Snow");
    const FString Name=FString::Printf(TEXT("footstep_%s_%03d"),Snow?TEXT("snow"):TEXT("concrete"),FMath::RandRange(0,4));
    UGameplayStatics::PlaySoundAtLocation(this,Recording(Name),GetActorLocation(),.48f,FMath::FRandRange(.96f,1.04f));
}
void AAvenueWalker::Tick(float Dt) {
    Super::Tick(Dt);
    if(RoadTest) CheckStreet(Dt);
    if(Bench) Benchmark(Dt);
    if(MenuOpen) return;
    if(Driven) {
        const float LastYaw=Driven->GetActorRotation().Yaw;
        Driven->Drive(Dt,Forward,Side,Sprint);
        const float Pace=FMath::Abs(Driven->Speed())*.01f;
        FRotator Orbit=GetControlRotation();
        auto* PC=Cast<APlayerController>(Controller);
        if(PC && PC->IsInputKeyDown(EKeys::LeftMouseButton)) {
            Orbit.Yaw+=FMath::FindDeltaAngleDegrees(LastYaw,Driven->GetActorRotation().Yaw);
            OrbitHold=1.5f;
        } else if(Pace>1) {
            OrbitHold=FMath::Max(0.f,OrbitHold-Dt);
            if(OrbitHold==0) {
                const float Gap=FMath::FindDeltaAngleDegrees(Orbit.Yaw,Driven->GetActorRotation().Yaw);
                const float Rate=FMath::Lerp(1.35f,5.5f,FMath::SmoothStep(5.f,25.f,FMath::Abs(Gap)));
                Orbit.Yaw+=FMath::Clamp(Gap*(1-FMath::Exp(-Rate*Dt)),-137.5f*Dt,137.5f*Dt);
                Orbit.Pitch=FMath::Lerp(FRotator::NormalizeAxis(Orbit.Pitch),-17.76f,1-FMath::Exp(-1.8f*Dt));
            }
        }
        Controller->SetControlRotation(Orbit);
        const FVector Pivot=Driven->GetActorLocation()+FVector(0,0,53);
        const FVector Desired=Pivot-Orbit.Vector()*(580+FMath::Min(Pace*4.5f,95.f));
        FHitResult Wall;
        const bool Hit=GetWorld()->SweepSingleByChannel(Wall,Pivot,Desired,FQuat::Identity,ECC_Visibility,
            FCollisionShape::MakeSphere(25),FCollisionQueryParams(TEXT("ChaseCamera"),true,Driven));
        Camera->SetWorldLocation(Hit?Wall.Location:Desired);
        const FVector LookAhead=FRotator(0,Orbit.Yaw,0).Vector()*170*FMath::Cos(FMath::DegreesToRadians(Orbit.Pitch));
        Camera->SetWorldRotation((Pivot+LookAhead-Camera->GetComponentLocation()).Rotation());
    } else {
        GetCharacterMovement()->MaxWalkSpeed=Sprint?715.26f:214.58f;
        if(GetCharacterMovement()->IsMovingOnGround()) StepDistance+=GetVelocity().Size2D()*Dt;
        if(StepDistance>(Sprint?155:99)) { Step(); StepDistance=0; }
    }
}
void AAvenueWalker::DriveOrInteract() {
    if(MenuOpen) return;
    if(!Driven) {
        for(TActorIterator<AAvenueCoffee> It(GetWorld());It;++It) {
            if(!It->Prompt().IsEmpty() && FVector::DistSquared(It->GetActorLocation(),GetActorLocation())<FMath::Square(235.f)) {
                It->Use(Camera); return;
            }
        }
    }
    if(Driven) {
        FVector Exit=Driven->GetActorLocation()-Driven->GetActorRightVector()*170+FVector(0,0,75);
        if(!GetWorld()->FindTeleportSpot(this,Exit,GetActorRotation())) return;
        SetActorLocation(Exit);
        Driven->Silence(); Driven->ShowDriver(false); Driven=nullptr;
        GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
        GetCharacterMovement()->SetMovementMode(MOVE_Walking);
        Camera->SetRelativeLocation(FVector(0,0,75));
        Camera->bUsePawnControlRotation=true;
        return;
    }
    for(TActorIterator<AAvenueDoor> It(GetWorld());It;++It) {
        if(!It->Revolving && FVector::DistSquared(It->GetActorLocation(),GetActorLocation())<FMath::Square(280.f)) {
            It->Interact(); return;
        }
    }
    for(TActorIterator<AAvenueCar> It(GetWorld());It;++It) {
        if(FVector::DistSquared(It->GetActorLocation(),GetActorLocation())>FMath::Square(400.f)) continue;
        Driven=*It;
        Driven->ShowDriver(true);
        GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        GetCharacterMovement()->DisableMovement();
        Camera->bUsePawnControlRotation=false;
        OrbitHold=0;
        Controller->SetControlRotation(FRotator(-17.76f,Driven->GetActorRotation().Yaw,0));
        break;
    }
}
void AAvenueWalker::ToggleFlight() {
    if(!Driven) GetCharacterMovement()->SetMovementMode(GetCharacterMovement()->IsFlying()?MOVE_Walking:MOVE_Flying);
}
void AAvenueWalker::LookAtHerald() {
    if(Driven) return;
    if(HeraldReturn.IsSet()) {
        SetActorTransform(HeraldReturn.GetValue(),false,nullptr,ETeleportType::TeleportPhysics);
        Controller->SetControlRotation(ReturnLook);
        GetCharacterMovement()->StopMovementImmediately();
        HeraldReturn.Reset();
        return;
    }
    const FVector P(-39100,34100,0);
    FHitResult Floor;
    if(!FloorAt(GetWorld(),P+FVector(0,0,4000),P-FVector(0,0,2000),Floor,this)) return;
    HeraldReturn=GetActorTransform();
    ReturnLook=GetControlRotation();
    GetCharacterMovement()->StopMovementImmediately();
    SetActorLocation(Floor.ImpactPoint+FVector(0,0,95));
    Controller->SetControlRotation(FRotator(12,-49,0));
}
void AAvenueWalker::ToggleDay() {
    Night=!Night;
    for(TActorIterator<AStaticMeshActor> It(GetWorld());It;++It) {
        if(!It->ActorHasTag("CitySkin")) continue;
        auto* Component=It->GetStaticMeshComponent();
        if(!CitySkin) CitySkin=UMaterialInstanceDynamic::Create(Component->GetMaterial(0),this);
        Component->SetMaterial(0,CitySkin);
    }
    if(CitySkin) CitySkin->SetScalarParameterValue(TEXT("NightWindows"),Night?1.f:0.f);
    TArray<AActor*> Lamps;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("NightLamp"),Lamps);
    for(AActor* Lamp:Lamps) Lamp->SetActorHiddenInGame(!Night);
    for(TActorIterator<APostProcessVolume> It(GetWorld());It;++It) {
        It->Settings.AutoExposureMinBrightness=Night?-.75f:8.f;
        It->Settings.AutoExposureMaxBrightness=Night?6.f:13.f;
    }
    TArray<AActor*> Moons;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("Moon"),Moons);
    for(AActor* Moon:Moons) Moon->SetActorHiddenInGame(!Night);
    for(TActorIterator<ADirectionalLight> It(GetWorld());It;++It) {
        auto* L=CastChecked<UDirectionalLightComponent>(It->GetLightComponent());
        L->SetAtmosphereSunLight(!Night);
        It->SetActorRotation(Night?FVector(191,-77,-329).Rotation():FRotator(-31,135,0));
        L->SetIntensity(Night?.18f:6500.f);
        L->SetLightColor(Night?FLinearColor(.40f,.48f,.68f):FLinearColor(1,.90f,.79f));
    }
    for(TActorIterator<ASkyLight> It(GetWorld());It;++It) It->GetLightComponent()->SetIntensity(Night?.16f:650.f);
}
void AAvenueWalker::ToggleMenu() {
    MenuOpen=!MenuOpen;
    if(!MenuOpen) GConfig->Flush(false,GGameUserSettingsIni);
    if(auto* PC=Cast<APlayerController>(Controller)) {
        PC->bShowMouseCursor=MenuOpen;
        if(MenuOpen) PC->SetInputMode(FInputModeGameAndUI());
        else PC->SetInputMode(FInputModeGameOnly());
    }
}
void AAvenueHUD::DrawHUD() {
    Super::DrawHUD();
    auto* P=Cast<AAvenueWalker>(GetOwningPawn());
    if(!P||!Canvas) return;
    if(P->MenuOpen) {
        float X=Canvas->ClipX*.5f-160,Y=Canvas->ClipY*.5f;
        DrawRect(FLinearColor(.02,.025,.03,.96),X-24,Y-65,368,219);
        DrawText(TEXT("Graphics quality"),FLinearColor::White,X,Y-45);
        DrawRect(FLinearColor(.25,.27,.3),X,Y,320,8);
        DrawRect(FLinearColor(.8,.84,.92),X+P->Quality*104,Y-6,10,20);
        DrawText(TEXT("Low                   Medium                 High                  Ultra"),FLinearColor::White,X,Y+22);
        DrawText(FString::Printf(TEXT("Mouse sensitivity   %.0f%%"),100*P->LookSensitivity),FLinearColor::White,X,Y+57);
        DrawRect(FLinearColor(.25,.27,.3),X,Y+96,320,8);
        DrawRect(FLinearColor(.8,.84,.92),X+(P->LookSensitivity-.25f)*249.6f,Y+90,10,20);
        float MX,MY;
        if(PlayerOwner->IsInputKeyDown(EKeys::LeftMouseButton)&&PlayerOwner->GetMousePosition(MX,MY)&&FMath::Abs(MY-Y)<24&&MX>=X-4&&MX<=X+324) {
            int Level=FMath::Clamp(FMath::RoundToInt((MX-X)*3/320),0,3);
            if(Level!=P->Quality) P->ChangeQuality(Level);
        } else if(PlayerOwner->IsInputKeyDown(EKeys::LeftMouseButton)&&PlayerOwner->GetMousePosition(MX,MY)&&FMath::Abs(MY-Y-100)<20&&MX>=X-4&&MX<=X+324) {
            P->SetLookSensitivity(.25f+1.25f*(MX-X)/320.f);
        }
    } else {
        if(!P->Driven) for(TActorIterator<AAvenueCoffee> It(GetWorld());It;++It) {
            if(FVector::DistSquared(It->GetActorLocation(),P->GetActorLocation())<FMath::Square(235.f))
                DrawText(It->Prompt(),FLinearColor::White,Canvas->ClipX*.43,Canvas->ClipY*.62);
        }
        DrawText(TEXT("WASD   Move / drive      E   Interact      T   Day / night      J   Herald Square      Esc   Graphics"),FLinearColor::White,22,Canvas->ClipY-32);
        if(P->Driven) DrawText(FString::Printf(TEXT("%d mph"),FMath::RoundToInt(FMath::Abs(P->Driven->Speed())*.0223694f)),FLinearColor::White,Canvas->ClipX-130,Canvas->ClipY-78,nullptr,1.6f);
    }
}

AActor* AAvenueGameMode::PlaceSurveyActor(UWorld* TargetWorld,TSubclassOf<AActor> ActorType,FTransform Placement) {
    if(!TargetWorld || !ActorType) return nullptr;
    FActorSpawnParameters Params;
    Params.OverrideLevel=TargetWorld->GetCurrentLevel();
    Params.ObjectFlags=RF_Transactional;
    Params.SpawnCollisionHandlingOverride=ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
    return TargetWorld->SpawnActor<AActor>(ActorType,Placement,Params);
}

// Packaged regression route through the two painted crossings at Fifth and 33rd.
void AAvenueWalker::CheckStreet(float Dt) {
    if(!Controller) return;
    TestTime+=FMath::Min(Dt,.05f);
    if(RoadStage==0 && TestTime<1) return;
    auto Fail=[this](const TCHAR* Why) {
        UE_LOG(LogTemp,Error,TEXT("Avenue road test failed: %s"),Why);
        RoadTest=false; FPlatformMisc::RequestExitWithStatus(true,1);
    };
    if(RoadStage==0) {
        Controller->SetIgnoreLookInput(true);
        Controller->SetIgnoreMoveInput(true);
        const FVector Start=GetActorLocation();
        const FRotator View=GetControlRotation();
        LookAtHerald();
        if(!HeraldReturn.IsSet() || FVector::Dist(Start,GetActorLocation())<10000) { Fail(TEXT("Herald arrival")); return; }
        LookAtHerald();
        if(!Start.Equals(GetActorLocation(),.1f) || !View.Equals(GetControlRotation(),.01f)) { Fail(TEXT("Herald return")); return; }
        // Look through the authored Reserve swing door, toward the coffee counter.
        SetActorLocation(FVector(-13510,58970,108));
        Controller->SetControlRotation((FVector(-15352,59081,123)-(GetActorLocation()+FVector(0,0,75))).Rotation());
        RoadStage=1;
    } else if(RoadStage==1 && TestTime>3) {
        FScreenshotRequest::RequestScreenshot(TEXT("ReserveNight.png"),false,false);
        RoadStage=2;
    } else if(RoadStage==2 && TestTime>4) {
        TArray<AActor*> Moons;
        UGameplayStatics::GetAllActorsWithTag(this,TEXT("Moon"),Moons);
        if(Moons.Num()!=1) { Fail(TEXT("lunar mesh missing")); return; }
        GetCharacterMovement()->SetMovementMode(MOVE_Flying);
        SetActorLocation(FVector(-13510,58970,51000));
        Controller->SetControlRotation((Moons[0]->GetActorLocation()-Camera->GetComponentLocation()).Rotation());
        RoadStage=3;
    } else if(RoadStage==3 && TestTime>6) {
        FScreenshotRequest::RequestScreenshot(TEXT("LunarStreet.png"),false,false);
        RoadStage=4;
    } else if(RoadStage==4 && TestTime>7) {
        ToggleDay();
        TActorIterator<AAvenueCar> Car(GetWorld());
        if(!Car) { Fail(TEXT("sedan missing")); return; }
        const FVector Along(-.487933,.872881,0), Across(.872881,.487933,0);
        const FVector Road=FVector(-20809.9,57389.1,0)+8350*Across+1900*Along;
        FHitResult Floor;
        if(!FloorAt(GetWorld(),Road+FVector(0,0,280),Road-FVector(0,0,200),Floor,this)) { Fail(TEXT("crossing has no pavement")); return; }
        TestStart=Floor.ImpactPoint+FVector(0,0,62);
        Car->SetActorLocationAndRotation(TestStart,Along.Rotation());
        SetActorLocation(TestStart+Across*155+FVector(0,0,26));
        DriveOrInteract();
        if(!Driven) { Fail(TEXT("could not enter car")); return; }
        Controller->SetControlRotation(Along.Rotation()+FRotator(-9,0,0));
        RoadStage=5; TestTime=0;
    } else if(RoadStage==5) {
        Forward=1;
        if(TestTime>6) {
            const float Travel=FVector::DotProduct(Driven->GetActorLocation()-TestStart,FVector(-.487933,.872881,0));
            if(Travel<3600 || FMath::Abs(Driven->Speed())<500) { UE_LOG(LogTemp,Error,TEXT("Crossing travel %.1f cm speed %.1f"),Travel,Driven->Speed()); Fail(TEXT("stalled on crossing")); return; }
            UE_LOG(LogTemp,Display,TEXT("Avenue road test passed: J round trip and %.1f feet across the painted crossing"),Travel/30.48f);
            FScreenshotRequest::RequestScreenshot(TEXT("CrossingDay.png"),false,false);
            RoadStage=6;
        }
    } else if(RoadStage==6 && TestTime>7) { RoadTest=false; FPlatformMisc::RequestExit(false); }
}

void AAvenueWalker::Benchmark(float Dt) {
    if(!Controller) return;
    if(DrivingBench && !Driven) {
        TActorIterator<AAvenueCar> It(GetWorld());
        if(It) {
            SetActorLocation(It->GetActorLocation()+It->GetActorRightVector()*160+FVector(0,0,32));
            DriveOrInteract();
        }
        if(!Driven) {
            UE_LOG(LogTemp,Error,TEXT("Driving benchmark could not enter the sedan"));
            Bench=false;
            FPlatformMisc::RequestExitWithStatus(true,1);
            return;
        }
    }
    const double Now=FPlatformTime::Seconds(), Elapsed=Now-BenchStart;
    const double FrameMs=(Now-LastFrame)*1000.;
    LastFrame=Now;
    // The same camera path runs twice. Keep simulation and rendering active.
    const bool Stress=Elapsed>=26.;
    if(FParse::Param(FCommandLine::Get(),TEXT("AvenueCapture")) && !Captured && Elapsed>4) {
        FScreenshotRequest::RequestScreenshot(TEXT("FifthStreet.png"),false,false);
        Captured=true;
    }
    if(Elapsed>=6 && Elapsed<26) BaselineTimes.Add(FrameMs);
    if(Stress && Elapsed<46) StressTimes.Add(FrameMs);
    const float Phase=FMath::Fmod(float(FMath::Max(0.,Elapsed-6.)),20.f);
    const FVector Along(-.4879,.8729,0), Across(.8729,.4879,0);
    const FVector Anchor=BlockBench?FVector(-27340,22810,680):FVector(-13740,64020,0);
    const FVector Foot=Anchor+Along*(FMath::Sin(Phase*.314159f)*480);
    if(DrivingBench && Driven) {
        BenchPeakSpeed=FMath::Max(BenchPeakSpeed,FMath::Abs(Driven->Speed()));
        Forward=Phase<10?.66f:-.55f;
        Side=.18f*FMath::Sin(Phase*.42f);
        Sprint=Phase>6.5f && Phase<7.6f;
        Controller->SetControlRotation(Driven->GetActorRotation()+FRotator(-8,0,0));
    } else {
        SetActorLocation(Foot+FVector(0,0,92),false);
        Controller->SetControlRotation(FRotator(BlockBench?11:2, (BlockBench?-151:-122)+25*FMath::Sin(Phase*.314159f),0));
    }
    if(Stress) {
        for(int i=0;i<Flashes.Num();++i) Flashes[i]->SetIntensity(FMath::Max(0.f,Flashes[i]->Intensity-Dt*38000));
        if(Elapsed>=NextBurst) {
            NextBurst=Elapsed+.08;
            for(int i=0;i<8;++i) {
                const FVector From=(DrivingBench && Driven?Driven->GetActorLocation():Anchor)-Along*(450+220*i)+Across*(i%2?190:-260)+FVector(0,0,142);
                const FVector To=From+Across*(i%2?-2400:2400)+FVector(0,0,70*FMath::Sin(Elapsed+i));
                FHitResult Hit;
                FloorAt(GetWorld(),From,To,Hit,this);
                DrawDebugLine(GetWorld(),From,Hit.bBlockingHit?Hit.ImpactPoint:To,FColor(255,191,98),false,.055,0,1.3);
                if(i<Flashes.Num()) { Flashes[i]->SetWorldLocation(From); Flashes[i]->SetIntensity(2900); }
            }
        }
    }
    if(Elapsed>=46 && !StressTimes.IsEmpty() && !BaselineTimes.IsEmpty()) {
        FString Output=TEXT("scenario,frames,mean_ms,p95_ms,p99_ms,worst_ms,over_16_67_ms\n");
        auto Report=[&Output](const TCHAR* Name,TArray<double>& Samples) {
            Samples.Sort();
            double Sum=0; int Late=0;
            for(double Ms:Samples) { Sum+=Ms; Late+=Ms>1000./60.; }
            const int Last=Samples.Num()-1;
            Output+=FString::Printf(TEXT("%s,%d,%.3f,%.3f,%.3f,%.3f,%d\n"),Name,Samples.Num(),Sum/Samples.Num(),Samples[FMath::CeilToInt(.95*Last)],Samples[FMath::CeilToInt(.99*Last)],Samples.Last(),Late);
        };
        Report(DrivingBench?TEXT("driving"):(BlockBench?TEXT("west36"):TEXT("street")),BaselineTimes);
        Report(DrivingBench?TEXT("driving_effects"):(BlockBench?TEXT("west36_effects"):TEXT("simulated_shootout")),StressTimes);
        if(DrivingBench) UE_LOG(LogTemp,Display,TEXT("Driving benchmark peak speed %.1f mph"),BenchPeakSpeed*.0223694f);
        FString File;
        if(!FParse::Value(FCommandLine::Get(),TEXT("AvenueReport="),File)) File=FPaths::ProjectSavedDir()/TEXT("AvenueBench.csv");
        if(!FFileHelper::SaveStringToFile(Output,*File)) FFileHelper::SaveStringToFile(Output,*(FPaths::ProjectSavedDir()/TEXT("AvenueBench.csv")));
        UE_LOG(LogTemp,Display,TEXT("Fifth Avenue frame times: %s"),*Output);
        Bench=false;
        FPlatformMisc::RequestExit(false);
    }
}
