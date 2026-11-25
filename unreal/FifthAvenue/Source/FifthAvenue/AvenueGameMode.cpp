#include "AvenueGameMode.h"
#if !UE_BUILD_SHIPPING
#include "Tests/AvenueInputTest.h"
#endif
#include "AvenueSettings.h"
#include "AvenueSnow.h"
#include "AvenueWalkMovement.h"
#include "Engine/GameViewportClient.h"
#include "Framework/Application/SlateApplication.h"
#include "AvenueStreet.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SpotLightComponent.h"
#include "Components/PoseableMeshComponent.h"
#include "Components/TextRenderComponent.h"
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
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
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
#include "UObject/ConstructorHelpers.h"

namespace {
constexpr float WalkSpeedCm = 214.58f;
constexpr float SprintSpeedCm = 715.26f;
constexpr float LookDegreesPerCount = .035f;
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
    Chassis->SetBoxExtent(FVector(222,94,35));
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
    SeatedDriver=CreateDefaultSubobject<UPoseableMeshComponent>("PedalPose");
    SeatedDriver->SetupAttachment(Driver);
    SeatedDriver->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    SeatedDriver->SetCastShadow(false);
    SeatedDriver->SetVisibility(false);
    for (int SideIndex : {-1, 1}) {
        auto* Lamp=CreateDefaultSubobject<USpotLightComponent>(SideIndex<0 ? TEXT("LeftLowBeam") : TEXT("RightLowBeam"));
        Lamp->SetupAttachment(Chassis);
        Lamp->SetRelativeLocation(FVector(202,SideIndex*76,6));
        Lamp->SetRelativeRotation(FRotator(-6,0,0));
        Lamp->SetLightColor(FLinearColor(.82f,.91f,1.f));
        Lamp->IntensityUnits=ELightUnits::Lumens;
        Lamp->SetIntensity(1050);
        Lamp->SetInnerConeAngle(15);
        Lamp->SetOuterConeAngle(28);
        Lamp->SetAttenuationRadius(3800);
        Lamp->SetCastShadows(false);
        Lamp->SetVisibility(false);
        Headlights.Add(Lamp);
    }
    RearPlate=CreateDefaultSubobject<UTextRenderComponent>("NYCPlate");
    RearPlate->SetupAttachment(Chassis);
    RearPlate->SetRelativeLocation(FVector(-229.8,0,8.3));
    RearPlate->SetRelativeRotation(FRotator(0,180,0));
    RearPlate->SetText(FText::FromString(TEXT("NYC")));
    RearPlate->SetHorizontalAlignment(EHTA_Center);
    RearPlate->SetVerticalAlignment(EVRTA_TextCenter);
    RearPlate->SetWorldSize(11);
    RearPlate->SetTextRenderColor(FColor(24,40,57));
    RearPlate->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Wind=CreateDefaultSubobject<UAudioComponent>("Airflow");
    Wind->SetupAttachment(Chassis);
    Wind->bAutoActivate=false;
    IndicatorClick=CreateDefaultSubobject<UAudioComponent>("IndicatorClick");
    IndicatorClick->SetupAttachment(Chassis);
    IndicatorClick->bAutoActivate=false;
    IndicatorClick->SetRelativeLocation(FVector(55,-36,32));
    IndicatorClick->bOverrideAttenuation=true;
    IndicatorClick->AttenuationOverrides.AttenuationShapeExtents.X=450;
    IndicatorClick->AttenuationOverrides.FalloffDistance=1600;
    IndicatorClick->SetVolumeMultiplier(.9f);
    WheelPowder=CreateDefaultSubobject<UInstancedStaticMeshComponent>("TirePowder");
    WheelPowder->SetupAttachment(Chassis);
    WheelPowder->SetAbsolute(true,true,true);
    WheelPowder->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    WheelPowder->SetCanEverAffectNavigation(false);
    WheelPowder->SetCastShadow(false);
    WheelPowder->SetNumCustomDataFloats(4);
    static ConstructorHelpers::FObjectFinder<UStaticMesh> PowderQuad(TEXT("/Engine/BasicShapes/Plane"));
    static ConstructorHelpers::FObjectFinder<UMaterialInterface> PowderMaterial(TEXT("/Game/Manhattan/Surface/M_WheelPowder"));
    WheelPowder->SetStaticMesh(PowderQuad.Object);
    WheelPowder->SetMaterial(0,PowderMaterial.Object);
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
    ClickSounds={Recording(TEXT("turn_signal_off")),Recording(TEXT("turn_signal"))};
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
    PoseAvenueDriver(*this,*Driver,*SeatedDriver,TEXT("sam"));
    const FName Slots[]={TEXT("TeslaHeadlamp"),TEXT("Ln12Mtl"),TEXT("TeslaIndicator")};
    for (FName Slot:Slots) {
        int32 Index=Exterior->GetMaterialIndex(Slot);
        LensMaterials.Add(Index==INDEX_NONE ? nullptr : Exterior->CreateDynamicMaterialInstance(Index));
    }
    if (auto* Wave=Recording(TEXT("winter_airflow"))) { Wave->bLooping=true; Wind->SetSound(Wave); }
}
void AAvenueCar::SetWheel(int Index,UStaticMesh* Mesh,FVector Center) {
    if(!Wheels.IsValidIndex(Index)) return;
    Wheels[Index]->SetStaticMesh(Mesh);
    Wheels[Index]->SetRelativeLocation(Center);
    Hubs[Index]=Center;
}
void AAvenueCar::ShowDriver(bool Visible) {
    Occupied=Visible;
    SeatedDriver->SetVisibility(Visible);
    for (auto& Lamp:Headlights) Lamp->SetVisibility(Visible);
    if (Visible && Wind->Sound) { Wind->SetVolumeMultiplier(.00025f); Wind->Play(); }
    else Wind->Stop();
    UpdateLamps(false);
}
void AAvenueCar::UpdateLamps(bool Braking) {
    if (LensMaterials.Num()!=3) return;
    if (LensMaterials[0]) LensMaterials[0]->SetScalarParameterValue(TEXT("Level"),Occupied ? 3.f : 0.f);
    if (LensMaterials[1]) LensMaterials[1]->SetScalarParameterValue(TEXT("Level"),Occupied && Braking ? 5.f : .12f);
    if (LensMaterials[2]) LensMaterials[2]->SetScalarParameterValue(TEXT("SignalSide"),Occupied && SignalLit ? SignalSide : 0);
}
void AAvenueCar::Signal(bool Left) {
    const int Requested=Left?-1:1;
    SignalSide=SignalSide==Requested?0:Requested;
    SignalClock=0; SignalLit=false; SignalTurned=false; SignalYaw=GetActorRotation().Yaw;
}
void AAvenueCar::Silence() {
    for(UAudioComponent* Audio:AudioLayers) Audio->Stop();
    IndicatorClick->Stop();
    VelocityXY=FVector::ZeroVector;
    SignalSide=0;
    SignedSpeed=ShiftWait=SlipAngle=YawRate=Steering=SteerHold=PreviousSteer=ScuffDuration=ScuffGain=0;
    VerticalSpeed=0; HadSupport=false;
    Backing=SignalLit=SignalTurned=false;
}
void AAvenueCar::Drive(float Delta, float Throttle, float InputSteer, bool Handbrake, UAvenueSnow& Surface, int Quality)
{
#if !UE_BUILD_SHIPPING
    LastDriveBlocker.Reset();
#endif
    // Small steps keep tire impulses and curb contact stable through a render hitch.
    const float Time = FMath::Min(Delta, .12f);
    const int32 Steps = FMath::Clamp(FMath::CeilToInt(Time * 90.f), 1, 12);
    for (int32 Step = 0; Step < Steps; ++Step)
        MoveOnTires(Time / Steps, Throttle, InputSteer, Handbrake);
    UpdateTireSurface(Surface,Time,Quality);
    UpdateAudio(Time, VelocityXY.Size2D() * .01f, SlipAngle, SignedSpeed * YawRate, HasTireContact());
    UpdateLamps(Handbrake || (Backing ? Throttle > 0 : Throttle < 0));
}

void AAvenueCar::UpdateDriveSpeed(float Dt, float Throttle, bool Handbrake)
{
    const float Pace = FMath::Abs(SignedSpeed);
    bool Braking = (Throttle < 0 && !Backing) || (Throttle > 0 && Backing);
    if (Braking && Pace < .035f && !Handbrake) {
        ShiftWait += Dt;
        if (ShiftWait >= .30f) { Backing = Throttle < 0; ShiftWait = 0; Braking = false; }
    } else ShiftWait = 0;
    if (Braking || Handbrake || FMath::IsNearlyZero(Throttle)) {
        const float Drag = Braking ? FMath::Lerp(10.5f, 17.f, FMath::SmoothStep(12.f, 38.f, Pace))
            : (Handbrake ? 5.5f : 1.12f + .001f * Pace * Pace);
        SignedSpeed = FMath::FInterpConstantTo(SignedSpeed, 0.f, Dt, Drag);
    } else {
        const float Limit = Throttle > 0 ? 58.1152f : 5.f;
        const float Force = (Throttle > 0 ? 5.1f : 2.7f) * FMath::Abs(Throttle);
        SignedSpeed = FMath::FInterpConstantTo(SignedSpeed, FMath::Sign(Throttle) * Limit, Dt,
            Force * FMath::Max(.1f, 1.f - FMath::Pow(Pace / Limit, 1.6f)));
    }
}

void AAvenueCar::ApplyAxleGrip(float Dt, float Axle, float WheelAngle, float Load, float Grip)
{
    // Planar rigid body in metres. Contact speed includes the motion of the axle
    // around the center of mass. Limit lateral impulse by the supported tire load.
    const FVector Forward = GetActorForwardVector().GetSafeNormal2D();
    const FVector Right(-Forward.Y, Forward.X, 0);
    const FVector Lateral = Right * FMath::Cos(WheelAngle) - Forward * FMath::Sin(WheelAngle);
    const float Lever = Axle * FMath::Cos(WheelAngle);
    constexpr float InertiaPerMass = 1.55f;
    const float SideSpeed = FVector::DotProduct(VelocityXY * .01f, Lateral) + Lever * YawRate;
    const float MaxImpulse = Grip * 9.81f * Load * Dt;
    const float Impulse = FMath::Clamp(-SideSpeed / (1.f + Lever * Lever / InertiaPerMass), -MaxImpulse, MaxImpulse);
    VelocityXY += Lateral * (Impulse * 100.f);
    YawRate += Lever * Impulse / InertiaPerMass;
}

void AAvenueCar::MoveOnTires(float Dt, float Throttle, float InputSteer, bool Handbrake)
{
    if (Dt <= SMALL_NUMBER) return;
    constexpr float Radius = 34.5f, Droop = 12.f, Bump = 10.5f;
    const FVector Up = FVector::UpVector;
    const FVector Center = GetActorLocation();
    const FVector Forward = GetActorForwardVector().GetSafeNormal2D();
    const FVector Right(-Forward.Y, Forward.X, 0);
    SignedSpeed = FVector::DotProduct(VelocityXY, Forward) * .01f;
    const float Pace = FMath::Abs(SignedSpeed);
    if (InputSteer * PreviousSteer <= 0.f) SteerHold = 0;
    SteerHold += Dt * FMath::Abs(InputSteer);
    PreviousSteer = InputSteer;
    const float Highway = FMath::SmoothStep(14.3f, 32.2f, Pace);
    const float Held = FMath::SmoothStep(.045f, .51f, SteerHold);
    const float Strength = Handbrake ? 1.f : FMath::Lerp(1.f, FMath::Lerp(.055f, 1.f, Held), Highway);
    const float Lock = FMath::Min(.57f, FMath::Atan(2.875f * 6.8f / FMath::Max(1.f, Pace * Pace)) + .026f);
    const float TargetSteer = InputSteer * Strength * Lock;
    const float Rate = FMath::Abs(TargetSteer) < FMath::Abs(Steering) ? 2.9f : 1.75f;
    Steering = FMath::FInterpConstantTo(Steering, TargetSteer, Dt, Rate);

    float Height[4], Deflection[4];
    bool Contact[4];
    ContactCount = 0;
    float SupportSum = 0;
    const FCollisionQueryParams Query(SCENE_QUERY_STAT(AvenueTire), true, this);
    for (int I = 0; I < 4; ++I) {
        const FVector Hub = Exterior->GetComponentTransform().TransformPosition(Hubs[I]) + VelocityXY * Dt;
        FHitResult Hit;
        const bool Found = GetWorld()->SweepSingleByChannel(Hit, Hub + Up * (Bump + 23), Hub - Up * (Droop + 6),
            FQuat::Identity, ECC_Visibility, FCollisionShape::MakeSphere(Radius), Query);
        Contact[I] = Found && !Hit.bStartPenetrating && Hit.ImpactNormal.Z > .42 && Hit.Location.Z >= Hub.Z - Droop;
        StreetTires[I]=Contact[I] && Hit.GetActor() && Hit.GetActor()->ActorHasTag(TEXT("CitySkin"));
        Height[I] = Contact[I] ? Hit.Location.Z : Hub.Z - Droop;
        Deflection[I] = Height[I] - Hub.Z;
        if (Contact[I]) { ++ContactCount; SupportSum += Deflection[I]; }
    }
    float AccelZ = -980.f;
    if (ContactCount > 0) {
        const float Support = Center.Z + SupportSum / ContactCount;
        const float SupportSpeed = HadSupport ? FMath::Clamp((Support - PreviousSupport) / Dt, -1700.f, 1700.f) : 0.f;
        PreviousSupport = Support;
        const float Load = ContactCount * .25f;
        AccelZ = FMath::Clamp(-980.f + Load * (980.f + 155.f * (Support - Center.Z) + 20.f * (SupportSpeed - VerticalSpeed)), -980.f, 3200.f);
        const float OldSpeed = SignedSpeed;
        UpdateDriveSpeed(Dt, Throttle, Handbrake);
        VelocityXY += Forward * ((SignedSpeed - OldSpeed) * 100.f * Load);
        const float FrontGrip=1.04f*FMath::Lerp(1.f,.57f,(TireCover[0]+TireCover[1])*.5f);
        const float RearGrip=(Handbrake?.18f:1.04f)*FMath::Lerp(1.f,.57f,(TireCover[2]+TireCover[3])*.5f);
        ApplyAxleGrip(Dt, 1.481f, Steering, .25f * (int(Contact[0]) + int(Contact[1])), FrontGrip);
        ApplyAxleGrip(Dt, -1.391f, 0.f, .25f * (int(Contact[2]) + int(Contact[3])), RearGrip);
        if (Pace < .04f && VelocityXY.Size2D() < 3.f && FMath::Abs(Throttle) < .01f) {
            VelocityXY = FVector::ZeroVector;
            YawRate = 0;
        }
    }
    HadSupport = ContactCount > 0;
    if (ContactCount == 0) YawRate *= FMath::Exp(-.28f * Dt);
    VerticalSpeed += AccelZ * Dt;
    float Lift = VerticalSpeed * Dt;
    if (ContactCount) Lift = FMath::Max(Lift, SupportSum / ContactCount - Bump);
    FVector Travel = VelocityXY * Dt + Up * Lift;
    FHitResult Hit;
    const FQuat Before = GetActorQuat();
    FRotator Orientation = GetActorRotation();
    Orientation.Yaw += FMath::RadiansToDegrees(YawRate * Dt);
    if (ContactCount >= 3) {
        const FVector Axle = Forward * 287.2f + Up * ((Height[0] + Height[1] - Height[2] - Height[3]) * .5f);
        const FVector Track = Right * 160.f + Up * ((Height[1] + Height[3] - Height[0] - Height[2]) * .5f);
        const FRotator Grade = FRotationMatrix::MakeFromZX(FVector::CrossProduct(Axle, Track).GetSafeNormal(),
            FRotator(0, Orientation.Yaw, 0).Vector()).Rotator();
        const float Blend = 1.f - FMath::Exp(-12.f * Dt);
        Orientation.Pitch = FMath::Lerp(Orientation.Pitch, Grade.Pitch, Blend);
        Orientation.Roll = FMath::Lerp(Orientation.Roll, Grade.Roll, Blend);
    }
    SetActorLocationAndRotation(Center + Travel, Orientation, true, &Hit);
    if (Hit.bBlockingHit) {
        if (Hit.bStartPenetrating) {
            SetActorRotation(Before);
            AddActorWorldOffset(Hit.Normal * (Hit.PenetrationDepth + .15), true);
        }
        if (Hit.Normal.Z < .50) {
#if !UE_BUILD_SHIPPING
            LastDriveBlocker=Hit.GetActor();
#endif
            const FVector Normal = Hit.Normal.GetSafeNormal2D();
            VelocityXY -= Normal * FMath::Min(0., FVector::DotProduct(VelocityXY, Normal));
            YawRate *= .65f;
        } else if (VerticalSpeed < 0) VerticalSpeed = 0;
        AddActorWorldOffset(FVector::VectorPlaneProject(Travel * (1.f - Hit.Time), Hit.Normal), true);
    }
    const FVector Heading = GetActorForwardVector().GetSafeNormal2D();
    SignedSpeed = FVector::DotProduct(VelocityXY, Heading) * .01f;
    SlipAngle = FMath::Atan2(FVector::CrossProduct(Heading, VelocityXY).Z, FMath::Max(100., FMath::Abs(SignedSpeed) * 100.));
    Spin = FMath::Fmod(Spin + FMath::RadiansToDegrees(SignedSpeed * 100.f * Dt / Radius), 360.f);
    for (int I = 0; I < 4; ++I) {
        const FTransform Pose = Exterior->GetComponentTransform();
        const FVector Mount = Pose.TransformPosition(Hubs[I]);
        Wheels[I]->SetWorldLocation(Mount + Up * FMath::Clamp(float(Height[I] - Mount.Z), -Droop, Bump));
        Wheels[I]->SetRelativeRotation(FRotator(0, I < 2 ? FMath::RadiansToDegrees(Steering) : 0, -Spin));
    }
}
void AAvenueCar::UpdateTireSurface(UAvenueSnow& Surface,float Dt,int Quality) {
    const float Motion=FMath::SmoothStep(.65f,7.f,FMath::Abs(SignedSpeed));
    const float PuffsPerSecond=FMath::Lerp(20.f,48.f,Quality/3.f);
    bool Dirty=false;
    for(int I=0;I<Wheels.Num();++I) {
        const FVector Foot=Wheels[I]->GetComponentLocation()-FVector(0,0,34.5);
        TireCover[I]=StreetTires[I] ? Surface.Coverage(Foot) : 0.f;
        const float Rate=Motion*FMath::SmoothStep(.015f,.60f,TireCover[I]);
        if(Rate>.06f) {
            PowderClock[I]+=Dt*PuffsPerSecond*Rate;
            while(PowderClock[I]>=1.f) {
                PowderClock[I]-=1.f;
                const FVector Spray=(I%2 ? 1.f : -1.f)*GetActorRightVector()*.5f
                    -GetActorForwardVector()*(.54f*FMath::Sign(SignedSpeed))+FVector::UpVector*.72f;
                const FVector Velocity=FMath::VRandCone(Spray.GetSafeNormal(),FMath::DegreesToRadians(22.f))*FMath::FRandRange(120.f,300.f);
                const FVector Jitter=GetActorRightVector()*FMath::FRandRange(-9.f,9.f)+GetActorForwardVector()*FMath::FRandRange(-10.f,10.f);
                const FTransform Spawn(Foot+Jitter+FVector(0,0,4));
                if(NextPuff<WheelPowder->GetInstanceCount()) WheelPowder->UpdateInstanceTransform(NextPuff,Spawn,true,false,true);
                else WheelPowder->AddInstance(Spawn,true);
                const float Data[]={float(GetWorld()->GetTimeSeconds()),float(Velocity.X),float(Velocity.Y),float(Velocity.Z)};
                WheelPowder->SetCustomData(NextPuff,MakeArrayView(Data),false);
                NextPuff=(NextPuff+1)%96;
                Dirty=true;
            }
        } else PowderClock[I]=0;
        Surface.Tire(I,Foot,StreetTires[I]);
    }
    if(Dirty) WheelPowder->MarkRenderInstancesDirty();
}

void AAvenueCar::UpdateAudio(float Dt,float Speed,float Slip,float Corner,bool Contact) {
    const float Blend=1-FMath::Exp(-8*Dt);
    const float Low=FMath::SmoothStep(0.f,9.f,Speed);
    const float Reverse=FMath::SmoothStep(0.f,5.f,Speed);
    const float Snow=(TireCover[2]+TireCover[3])*.5f;
    const float Road=(.15f*FMath::SmoothStep(0.f,3.5f,Speed)+.18f*FMath::SmoothStep(3.5f,27.f,Speed))*(1+.18f*FMath::Min(1.f,FMath::Abs(Corner)/12))*FMath::Lerp(1.f,.70f,Snow);
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
    float Target=2.f*FMath::Lerp(.48f,.25f,Snow)*Intensity*FMath::SmoothStep(.15f,1.5f,SideSpeed)*FMath::Lerp(.82f,1.f,FMath::Min(1.f,FMath::Abs(Corner)/10));
    ScuffGain=FMath::Lerp(ScuffGain,Target,1-FMath::Exp(-Dt*(Target>ScuffGain?12:7)));
    if(ScuffGain>.0005f) {
        ScuffAge+=Dt;
        if(ScuffAge>=ScuffDuration) {
            ScuffVoice=1-ScuffVoice; ScuffAge=0; ScuffDuration=FMath::FRandRange(1.7f,3.4f);
            ScuffPitch[ScuffVoice]=FMath::FRandRange(.965f,1.035f);
            auto* Voice=AudioLayers[3+ScuffVoice].Get();
            if(Voice->Sound) Voice->Play(FMath::FRandRange(0,FMath::Max(0.f,Voice->Sound->GetDuration()-(ScuffDuration+.65f)*1.35f)));
        }
        const float Fade=FMath::Min(1.f,ScuffAge/.55f)*HALF_PI;
        for(int i=0;i<2;++i) {
            auto* Voice=AudioLayers[3+i].Get();
            const float Weight=i==ScuffVoice?(AudioLayers[4-i]->IsPlaying()?FMath::Sin(Fade):1):FMath::Cos(Fade);
            Voice->SetPitchMultiplier((FMath::Lerp(.73f,.51f,Snow)+.57f*Intensity)*ScuffPitch[i]);
            FVector Speaker=Voice->GetRelativeLocation();
            Speaker.Y=FMath::Lerp(Speaker.Y,double(65.f*FMath::Clamp(Corner/5.f,-1.f,1.f)),double(Blend));
            Voice->SetRelativeLocation(Speaker);
            Voice->SetVolumeMultiplier(FMath::Max(.00025f,Weight*ScuffGain));
            if(i!=ScuffVoice && ScuffAge>=.55f) Voice->Stop();
        }
    } else if(ScuffDuration>0) { AudioLayers[3]->Stop(); AudioLayers[4]->Stop(); ScuffDuration=0; }
    Wind->SetVolumeMultiplier(FMath::Lerp(Wind->VolumeMultiplier,.50f*FMath::SmoothStep(3.f,45.f,Speed),Blend));
    Wind->SetPitchMultiplier(.82f+.27f*FMath::Min(1.f,Speed/45.f));
    SignalTurned |= SignalSide && !Backing && SignalSide*FMath::FindDeltaAngleDegrees(SignalYaw,GetActorRotation().Yaw)>28.f;
    if (SignalTurned && FMath::Abs(Steering)<.035f && FMath::Abs(PreviousSteer)<.1f) {SignalSide=0; SignalTurned=SignalLit=false;}
    if(SignalSide && (SignalClock-=Dt)<=0) {
        SignalLit=!SignalLit;
        IndicatorClick->SetSound(ClickSounds[SignalLit?1:0]);
        IndicatorClick->Play();
        SignalClock=.38f;
    }
}

AAvenueWalker::AAvenueWalker(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer.SetDefaultSubobjectClass<UAvenueWalkMovement>(ACharacter::CharacterMovementComponentName)) {
    PrimaryActorTick.bCanEverTick=true;
    GetCapsuleComponent()->InitCapsuleSize(27,86);
    Camera=CreateDefaultSubobject<UCameraComponent>("Eyes");
    Snow=CreateDefaultSubobject<UAvenueSnow>("StreetSnow");
    Camera->SetupAttachment(GetCapsuleComponent());
    Camera->SetRelativeLocation(FVector(0,0,75));
    Camera->bUsePawnControlRotation=true;
    Camera->FieldOfView=85;
    Camera->PostProcessSettings.bOverride_MotionBlurAmount=true;
    Camera->PostProcessSettings.MotionBlurAmount=0;
    GetMesh()->SetCastShadow(false);
    GetMesh()->SetOwnerNoSee(true);
    bUseControllerRotationYaw=true;
    auto* Movement=GetCharacterMovement();
    Movement->MaxWalkSpeed=WalkSpeedCm;
    Movement->MaxAcceleration=5400;
    Movement->BrakingDecelerationWalking=5000;
    Movement->GroundFriction=12;
    Movement->AirControl=.62f;
    Movement->JumpZVelocity=335;
}
void AAvenueWalker::BeginPlay() {
    Super::BeginPlay();
    for(TActorIterator<AAvenueDoor> It(GetWorld());It;++It) if(It->Revolving) EntryDoors.Add(*It);
    auto* Settings=GEngine->GetGameUserSettings();
    GConfig->GetFloat(TEXT("FifthAvenue"),TEXT("LookSensitivity"),LookSensitivity,GGameUserSettingsIni);
    LookSensitivity=FMath::Clamp(LookSensitivity,MinLookSensitivity,MaxLookSensitivity);
    GConfig->GetInt(TEXT("FifthAvenue"),TEXT("Motion"),MotionLevel,GGameUserSettingsIni);
    MotionLevel=FMath::Clamp(MotionLevel,0,2);
    GetMesh()->SetRelativeLocationAndRotation(FVector(0,0,-86),FRotator(0,-90,0));
    GetMesh()->SetVisibility(false);
    for (int32 Index=0; Index<5; ++Index) {
        ConcreteSteps.Add(Recording(FString::Printf(TEXT("footstep_concrete_%03d"), Index)));
        SnowSteps.Add(Recording(FString::Printf(TEXT("footstep_snow_%03d"), Index)));
    }
    if (FSlateApplication::IsInitialized())
        FSlateApplication::Get().OnApplicationActivationStateChanged().AddUObject(this, &AAvenueWalker::OnAppActivationChanged);
    if(!GConfig->GetInt(TEXT("FifthAvenue"),TEXT("Quality"),Quality,GGameUserSettingsIni)) Quality=0;
    Bench=FParse::Param(FCommandLine::Get(),TEXT("AvenueBench"));
    RoadTest=FParse::Param(FCommandLine::Get(),TEXT("AvenueRoadTest"));
    TArray<AActor*> Clouds;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("Snowfall"),Clouds);
    if(!Clouds.IsEmpty()) {
        SnowCloud=Clouds[0];
        auto* Mesh=SnowCloud->FindComponentByClass<UHierarchicalInstancedStaticMeshComponent>();
        if(Mesh) Flakes=Mesh->CreateDynamicMaterialInstance(0);
    }
    if(Settings) ChangeQuality(Quality);
    Night=Bench;
    ToggleDay();
    if(TActorIterator<AAvenueCoffee> It{GetWorld()}) Reserve=*It;
    if(TActorIterator<AAvenueCar> It{GetWorld()}) Parked=*It;
    Snow->Initialize(CitySkin);
    auto StartBed=[this](const TCHAR* Name,float Volume) -> UAudioComponent* {
        if(auto* W=Recording(Name)) {
            W->bLooping=true;
            return UGameplayStatics::SpawnSound2D(this,W,Volume);
        }
        return nullptr;
    };
    OutdoorBed=StartBed(TEXT("winter_city"),.22f);
    IndoorBed=StartBed(TEXT("reserve_room"),.001f);
#if !UE_BUILD_SHIPPING
    if (FParse::Param(FCommandLine::Get(), TEXT("AvenueInputTest"))) StartAvenueInputTest(*this);
    if (FParse::Param(FCommandLine::Get(), TEXT("AvenueBlockTest"))) StartAvenueBlockTest(*this);
#endif
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
void AAvenueWalker::EndPlay(const EEndPlayReason::Type Reason) {
    if(OutdoorBed) OutdoorBed->Stop();
    if(IndoorBed) IndoorBed->Stop();
    if (FSlateApplication::IsInitialized())
        FSlateApplication::Get().OnApplicationActivationStateChanged().RemoveAll(this);
    if (SettingsPanel) {
        if (auto* Viewport=GetWorld()->GetGameViewport()) Viewport->RemoveViewportWidgetContent(SettingsPanel.ToSharedRef());
        SettingsPanel.Reset();
        if (auto* PC=Cast<APlayerController>(Controller)) {
            PC->bShowMouseCursor=false;
            PC->SetInputMode(FInputModeGameOnly());
        }
    }
    Super::EndPlay(Reason);
}
void AAvenueWalker::SetLookSensitivity(float Value) {
    const float NewValue=FMath::Clamp(Value,MinLookSensitivity,MaxLookSensitivity);
    if(FMath::IsNearlyEqual(NewValue,LookSensitivity)) return;
    LookSensitivity=NewValue;
    GConfig->SetFloat(TEXT("FifthAvenue"),TEXT("LookSensitivity"),LookSensitivity,GGameUserSettingsIni);
}
void AAvenueWalker::ChangeQuality(int NewQuality) {
    Quality=FMath::Clamp(NewQuality,0,3);
    if(Driven) Camera->PostProcessSettings.MotionBlurAmount=Quality>=2 ? .08f*MotionLevel : 0.f;
    if(Flakes) Flakes->SetScalarParameterValue(TEXT("Density"),.25f+.25f*Quality);
    if(auto* S=GEngine->GetGameUserSettings()) {
        S->SetOverallScalabilityLevel(Quality);
        S->SetShadowQuality(FMath::Max(1,Quality));
        S->SetTextureQuality(FMath::Max(2,Quality));
        const float ScaleCeiling=72.f+Quality*(28.f/3.f);
        IConsoleManager::Get().FindConsoleVariable(TEXT("r.DynamicRes.MinScreenPercentage"))->Set(60.f+Quality*5.f,ECVF_SetByGameSetting);
        IConsoleManager::Get().FindConsoleVariable(TEXT("r.DynamicRes.MaxScreenPercentage"))->Set(ScaleCeiling,ECVF_SetByGameSetting);
        S->SetResolutionScaleValueEx(ScaleCeiling);
        S->SetDynamicResolutionEnabled(true);
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
    I->BindKey(EKeys::R,IE_Pressed,this,&AAvenueWalker::ResetPrototype);
    I->BindKey(EKeys::J,IE_Pressed,this,&AAvenueWalker::LookAtHerald);
    I->BindKey(EKeys::F,IE_Pressed,this,&AAvenueWalker::ToggleFlight);
    I->BindKey(EKeys::H,IE_Pressed,this,&AAvenueWalker::ToggleHints);
    I->BindKey(EKeys::B,IE_Pressed,this,&AAvenueWalker::CycleMotion);
    I->BindKey(EKeys::V,IE_Pressed,this,&AAvenueWalker::ReleasePointer);
    I->BindKey(EKeys::LeftMouseButton,IE_Pressed,this,&AAvenueWalker::CapturePointer);
    I->BindKey(EKeys::Escape,IE_Pressed,this,&AAvenueWalker::ToggleMenu);
    I->BindKey(EKeys::SpaceBar,IE_Pressed,this,&AAvenueWalker::StartJump);
    I->BindKey(EKeys::SpaceBar,IE_Released,this,&ACharacter::StopJumping);
    I->BindKey(EKeys::LeftShift,IE_Pressed,this,&AAvenueWalker::StartSprint);
    I->BindKey(EKeys::LeftShift,IE_Released,this,&AAvenueWalker::EndSprint);
    I->BindKey(EKeys::Left,IE_Pressed,this,&AAvenueWalker::LeftSignal);
    I->BindKey(EKeys::Right,IE_Pressed,this,&AAvenueWalker::RightSignal);
}
void AAvenueWalker::MoveForward(float V) { Forward=MenuOpen ? 0.f : V; }
void AAvenueWalker::MoveRight(float V) { Side=MenuOpen ? 0.f : V; }
void AAvenueWalker::QueueWalkInput() {
    if (MenuOpen || Driven || Freecam || !Controller || !IsLocallyControlled()) return;
    const FRotator View=GetControlRotation();
    const FRotator Yaw(0,View.Yaw,0);
    const FVector Ahead=GetCharacterMovement()->IsFlying() ? View.Vector() : Yaw.Vector();
    AddMovementInput(Ahead,Forward);
    AddMovementInput(Yaw.RotateVector(FVector::RightVector),Side);
}
FVector AAvenueWalker::GuideThroughDoor(FVector Velocity, float Dt) {
    if (Velocity.IsNearlyZero()) return FVector::ZeroVector;
    for (auto& Door : EntryDoors)
        if (FVector::DistSquared2D(GetActorLocation(), Door->GetActorLocation()) < 190.f*190.f)
            return Door->Guide(*this, Velocity, Dt);
    return Velocity;
}
void AAvenueWalker::StartSprint() {
    if (MenuOpen) return;
    Sprint=true;
    GetCharacterMovement()->MaxWalkSpeed=SprintSpeedCm;
}
void AAvenueWalker::EndSprint() {
    Sprint=false;
    GetCharacterMovement()->MaxWalkSpeed=WalkSpeedCm;
}
void AAvenueWalker::LookYaw(float V) {
    if(MenuOpen || PointerReleased || V==0) return;
    if(Driven) OrbitHold=1.5f;
    AddControllerYawInput(V*LookSensitivity*LookDegreesPerCount);
}
void AAvenueWalker::LookPitch(float V) {
    if(MenuOpen || PointerReleased || V==0) return;
    if(Driven) OrbitHold=1.5f;
    AddControllerPitchInput(V*LookSensitivity*LookDegreesPerCount);
}
void AAvenueWalker::StartJump() { if(!MenuOpen&&!Driven&&GetCharacterMovement()->IsMovingOnGround()) { Step(); Jump(); } }
void AAvenueWalker::Landed(const FHitResult& Hit) {
    if(GetVelocity().Z< -100 && !Driven && !Freecam) Step();
    Super::Landed(Hit);
}
void AAvenueWalker::Step() {
    FHitResult Floor;
    if(!FloorAt(GetWorld(),GetActorLocation(),GetActorLocation()-FVector(0,0,150),Floor,this)) return;
    const FVector Heading=GetVelocity().IsNearlyZero()?GetActorForwardVector():GetVelocity().GetSafeNormal2D();
    const FVector AcrossFoot(-Heading.Y,Heading.X,0);
    const bool OnStreet=Floor.GetActor() && Floor.GetActor()->ActorHasTag("CitySkin") && !(Reserve && Reserve->Indoors(Floor.ImpactPoint));
    const float Cover=OnStreet?Snow->Coverage(Floor.ImpactPoint+AcrossFoot*(LeftFoot?-10.3:10.3)):0.f;
    LastStep=LastStep<0?FMath::RandHelper(5):(LastStep+FMath::RandRange(1,4))%5;
    const float Pitch=FMath::FRandRange(.96f,1.04f),Gain=Sprint?.63f:.38f;
    if(Cover<.995f) UGameplayStatics::PlaySound2D(this,ConcreteSteps[LastStep],Gain*FMath::Sqrt(1-Cover),Pitch);
    if(Cover>.005f) UGameplayStatics::PlaySound2D(this,SnowSteps[LastStep],Gain*FMath::Sqrt(Cover),Pitch);
    if(OnStreet) Snow->Footprint(Floor.ImpactPoint,Heading,LeftFoot);
    LeftFoot=!LeftFoot;
}
void AAvenueWalker::Tick(float Dt) {
    Super::Tick(Dt);
    if(RoadTest) CheckStreet(Dt);
    if(Bench) Benchmark(Dt);
    if(MenuOpen) return;
    if(Freecam) Fly(Dt);
    const float Inside=Reserve && !Driven && Reserve->Indoors(Camera->GetComponentLocation())?1.f:0.f;
    RoomMix=FMath::FInterpTo(RoomMix,Inside,Dt,2.5f);
    if(OutdoorBed) OutdoorBed->SetVolumeMultiplier((Driven?.16f:.22f)*FMath::Lerp(1.f,.20f,RoomMix));
    if(IndoorBed) IndoorBed->SetVolumeMultiplier(FMath::Lerp(.001f,.20f,RoomMix));
    if(Driven) {
        const float LastYaw=Driven->GetActorRotation().Yaw;
        const auto* InputPC=Cast<APlayerController>(Controller);
        const float Pedal=InputPC && InputPC->IsInputKeyDown(EKeys::Down) ? -1.f :
            InputPC && InputPC->IsInputKeyDown(EKeys::Up) ? 1.f : Forward;
        Driven->Drive(Dt,Pedal,Side,Sprint,*Snow,Quality);
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
    } else if(!Freecam) UpdateStride(Dt);
    Snow->Update(Freecam?Camera->GetComponentLocation():(Driven?Driven->GetActorLocation():GetActorLocation()),Dt);
    if(SnowCloud) {
        const FVector Eye=Camera->GetComponentLocation();
        const FVector Anchor(FMath::GridSnap(Eye.X,3000.),FMath::GridSnap(Eye.Y,3000.),FMath::GridSnap(Eye.Z,1500.));
        if(!SnowCloud->GetActorLocation().Equals(Anchor,1)) SnowCloud->SetActorLocation(Anchor);
    }
    if(CitySkin && Parked) {
        const FVector Under=Parked->GetActorLocation()-Parked->GetActorUpVector()*62;
        const FVector Fwd=Parked->GetActorForwardVector();
        CitySkin->SetVectorParameterValue(TEXT("CarFoot"),FLinearColor(Under.X,Under.Y,Under.Z));
        CitySkin->SetVectorParameterValue(TEXT("CarHeading"),FLinearColor(Fwd.X,Fwd.Y,0));
    }
}
void AAvenueWalker::DriveOrInteract() {
    if(MenuOpen || Freecam) return;
    if(!Driven) {
        for(TActorIterator<AAvenueCoffee> It(GetWorld());It;++It) {
            if(!It->Prompt().IsEmpty() && It->InReach(GetActorLocation()-FVector(0,0,86))) {
                It->Use(Camera); return;
            }
        }
    }
    if(Driven) {
        if(FMath::Abs(Driven->Speed())>15.f) return;
        const FVector Location=Driven->GetActorLocation();
        const FVector Right=Driven->GetActorRightVector().GetSafeNormal2D();
        const FVector Back=-Driven->GetActorForwardVector().GetSafeNormal2D();
        const FCollisionQueryParams Query(TEXT("SedanExit"),false,this);
        bool Clear=false;
        FVector Exit;
        for(FVector Offset:{-Right*165,Right*165,Back*297}) {
            const FVector Beside=Location+Offset;
            FHitResult Floor;
            if(!FloorAt(GetWorld(),Beside+FVector(0,0,65),Beside-FVector(0,0,200),Floor,Driven) || Floor.ImpactNormal.Z<.65f) continue;
            Exit=Floor.ImpactPoint+FVector(0,0,88);
            if(!GetWorld()->OverlapBlockingTestByChannel(Exit,FQuat::Identity,ECC_Pawn,GetCapsuleComponent()->GetCollisionShape(),Query)) { Clear=true; break; }
        }
        if(!Clear) return;
        SetActorLocation(Exit,false,nullptr,ETeleportType::TeleportPhysics);
        Controller->SetControlRotation(FRotator(0,Driven->GetActorRotation().Yaw,0));
        Driven->Silence(); Driven->ShowDriver(false); Driven=nullptr;
        GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
        GetCharacterMovement()->SetMovementMode(MOVE_Walking);
        Camera->SetRelativeLocation(FVector(0,0,75));
        Camera->bUsePawnControlRotation=true;
        Camera->PostProcessSettings.bOverride_MotionBlurAmount=true;
        Camera->PostProcessSettings.MotionBlurAmount=0;
        if(Reserve) Reserve->ShowHeldCup(true);
        return;
    }
    for(TActorIterator<AAvenueDoor> It(GetWorld());It;++It) {
        if(!It->Revolving && FVector::DistSquared(It->GetActorLocation(),GetActorLocation())<FMath::Square(280.f)) {
            It->Interact(GetActorLocation()); return;
        }
    }
    for(TActorIterator<AAvenueCar> It(GetWorld());It;++It) {
        if(FVector::DistSquared(It->GetActorLocation(),GetActorLocation())>FMath::Square(580.f)) continue;
        Driven=*It;
        Driven->ShowDriver(true);
        GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        GetCharacterMovement()->DisableMovement();
        Camera->bUsePawnControlRotation=false;
        Camera->PostProcessSettings.bOverride_MotionBlurAmount=true;
        Camera->PostProcessSettings.MotionBlurAmount=(MotionLevel>0 && Quality>=2)? .08f*MotionLevel : 0.f;
        Camera->SetFieldOfView(85);
        if(Reserve) Reserve->ShowHeldCup(false);
        OrbitHold=0;
        Controller->SetControlRotation(FRotator(-17.76f,Driven->GetActorRotation().Yaw,0));
        break;
    }
}
void AAvenueWalker::ToggleFlight() {
    if(MenuOpen || Driven || !Controller) return;
    ClearGameInput();
    Freecam=!Freecam;
    if(Freecam) {
        BodyLook=GetControlRotation();
        GetCharacterMovement()->DisableMovement();
        bUseControllerRotationYaw=false;
        if(!GetMesh()->GetSkeletalMeshAsset()) {
            const FString Sam=TEXT("/Game/Manhattan/Citizens/sam/sam/SkeletalMeshes/sam");
            GetMesh()->SetSkeletalMeshAsset(LoadObject<USkeletalMesh>(nullptr,*Sam));
            GetMesh()->PlayAnimation(LoadObject<UAnimSequence>(nullptr,*(Sam+"Idle_Standing")),true);
        }
        GetMesh()->SetOwnerNoSee(false);
        GetMesh()->SetVisibility(true);
        Camera->DetachFromComponent(FDetachmentTransformRules::KeepWorldTransform);
        Camera->SetWorldLocation(GetActorLocation()+GetActorRotation().RotateVector(FVector(-280,150,179)));
        Controller->SetControlRotation((GetActorLocation()+FVector(0,0,14)-Camera->GetComponentLocation()).Rotation());
        Camera->SetFieldOfView(85);
        Camera->PostProcessSettings.MotionBlurAmount=0;
    } else {
        GetMesh()->SetOwnerNoSee(true);
        GetMesh()->SetVisibility(false);
        Camera->AttachToComponent(GetCapsuleComponent(),FAttachmentTransformRules::SnapToTargetNotIncludingScale);
        Camera->SetRelativeLocation(FVector(0,0,75));
        Controller->SetControlRotation(BodyLook);
        bUseControllerRotationYaw=true;
        GetCharacterMovement()->SetMovementMode(MOVE_Walking);
    }
    if(Reserve) Reserve->ShowHeldCup(!Freecam);
}
void AAvenueWalker::Fly(float Dt) {
    const auto* PC=Cast<APlayerController>(Controller);
    if(!PC) return;
    const FRotator View=PC->GetControlRotation();
    const float Vertical=int(PC->IsInputKeyDown(EKeys::E))-int(PC->IsInputKeyDown(EKeys::Q));
    const FVector Move=View.Vector()*Forward+FRotationMatrix(View).GetUnitAxis(EAxis::Y)*Side+FVector::UpVector*Vertical;
    if(Move.IsNearlyZero()) return;
    FVector Position=Camera->GetComponentLocation()+Move.GetSafeNormal()*FlightMph*44.704f*Dt;
    Position.X=FMath::Clamp(Position.X,-135000.,135000.);
    Position.Y=FMath::Clamp(Position.Y,-150000.,150000.);
    Position.Z=FMath::Clamp(Position.Z,170.,180000.);
    Camera->SetWorldLocation(Position);
}
void AAvenueWalker::CycleMotion() {
    if(MenuOpen) return;
    MotionLevel=(MotionLevel+2)%3;
    GConfig->SetInt(TEXT("FifthAvenue"),TEXT("Motion"),MotionLevel,GGameUserSettingsIni);
    GConfig->Flush(false,GGameUserSettingsIni);
    if(Driven) Camera->PostProcessSettings.MotionBlurAmount=Quality>=2 ? .08f*MotionLevel : 0.f;
}
void AAvenueWalker::UpdateStride(float Dt) {
    const float Speed=GetCharacterMovement()->IsMovingOnGround() ? GetVelocity().Size2D() : 0.f;
    const float Effort=FMath::SmoothStep(WalkSpeedCm,SprintSpeedCm,Speed);
    const float Stride=FMath::Lerp(98.f,212.f,Effort);
    const float Distance=Speed*Dt;
    StepDistance+=Distance;
    if(StepDistance>=Stride) { Step(); StepDistance=FMath::Fmod(StepDistance,Stride); }
    WalkPhase=FMath::Fmod(WalkPhase+Distance/Stride,2.f);
    GaitAmount=FMath::FInterpConstantTo(GaitAmount,FMath::SmoothStep(10.f,WalkSpeedCm,Speed),Dt,8.f);
    if(GaitAmount==0) WalkPhase=.5f;
    RunMix=FMath::FInterpConstantTo(RunMix,Effort,Dt,5.f);
    LensMix=FMath::Max(RunMix,FMath::Lerp(LensMix,RunMix,1-FMath::Exp(-4.8f*Dt)));
    const float Strength=MotionLevel==2 ? 1.f : .45f*MotionLevel;
    const float SideBob=FMath::Sin(WalkPhase*PI)*FMath::Lerp(.9f,2.2f,RunMix);
    const float Vertical=-FMath::Cos(WalkPhase*2*PI)*FMath::Lerp(1.7f,3.4f,RunMix);
    Camera->SetRelativeLocation(FVector(0,0,75)+FVector(0,SideBob,Vertical)*GaitAmount*Strength);
    Camera->SetFieldOfView(85+4*LensMix*Strength);
    Camera->PostProcessSettings.MotionBlurAmount=Quality>=2 ? .10f*RunMix*Strength : 0;
}
void AAvenueWalker::ReleasePointer() {
    auto* PC=Cast<APlayerController>(Controller);
    if(!PC || MenuOpen) return;
    ClearGameInput();
    PointerReleased=true; PC->bShowMouseCursor=true;
    PC->SetInputMode(FInputModeGameAndUI().SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock).SetHideCursorDuringCapture(false));
}
void AAvenueWalker::CapturePointer() {
    auto* PC=Cast<APlayerController>(Controller);
    if(!PC || MenuOpen || !PointerReleased) return;
    PointerReleased=false; PC->bShowMouseCursor=false;
    PC->SetInputMode(FInputModeGameOnly().SetConsumeCaptureMouseDown(false));
}
void AAvenueWalker::ResetPrototype() {
    if (MenuOpen) return;
    ClearGameInput();
    GConfig->Flush(false, GGameUserSettingsIni);
    const FString Map = UGameplayStatics::GetCurrentLevelName(this, true);
    UGameplayStatics::OpenLevel(this, FName(*Map));
}
void AAvenueWalker::LookAtHerald() {
    if(Driven || Freecam) return;
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
        if(!LampGlass && It->ActorHasTag("LampGlass")) {
            auto* Component=It->GetStaticMeshComponent();
            int Slot=Component->GetMaterialIndex(TEXT("StreetLampGlass"));
            if(Slot!=INDEX_NONE) LampGlass=Component->CreateDynamicMaterialInstance(Slot);
        }
        if(!It->ActorHasTag("CitySkin")) continue;
        auto* Component=It->GetStaticMeshComponent();
        if(!CitySkin) CitySkin=UMaterialInstanceDynamic::Create(Component->GetMaterial(0),this);
        Component->SetMaterial(0,CitySkin);
    }
    if(CitySkin) CitySkin->SetScalarParameterValue(TEXT("NightWindows"),Night?1.f:0.f);
    if(LampGlass) LampGlass->SetScalarParameterValue(TEXT("Night"),Night?1.f:0.f);
    TArray<AActor*> Lamps;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("NightLamp"),Lamps);
    for(AActor* Lamp:Lamps)
        if(auto* Component=Lamp->FindComponentByClass<ULightComponent>()) Component->SetVisibility(Night);
    for(TActorIterator<APostProcessVolume> It(GetWorld());It;++It) {
        It->Settings.AutoExposureMinBrightness=Night?.65f:8.5f;
        It->Settings.AutoExposureMaxBrightness=Night?3.85f:13.5f;
    }
    TArray<AActor*> Moons;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("Moon"),Moons);
    for(AActor* Moon:Moons) Moon->SetActorHiddenInGame(!Night);
    for(TActorIterator<ADirectionalLight> It(GetWorld());It;++It) {
        auto* L=CastChecked<UDirectionalLightComponent>(It->GetLightComponent());
        L->SetAtmosphereSunLight(!Night);
        It->SetActorRotation(Night?FVector(191,-77,-329).Rotation():FRotator(-31,135,0));
        L->SetIntensity(Night?.18f:6500.f);
        L->SetSpecularScale(Night?.06f:.8f);
        L->SetLightColor(Night?FLinearColor(.40f,.48f,.68f):FLinearColor(1,.90f,.79f));
    }
    for(TActorIterator<ASkyLight> It(GetWorld());It;++It) It->GetLightComponent()->SetIntensity(Night?.22f:210.f);
}
void AAvenueWalker::ClearGameInput() {
    Forward=Side=0;
    EndSprint();
    StopJumping();
    if (auto* PC=Cast<APlayerController>(Controller)) PC->FlushPressedKeys();
    ConsumeMovementInputVector();
    if (GetCharacterMovement()->IsMovingOnGround()) GetCharacterMovement()->StopMovementImmediately();
}
void AAvenueWalker::OnAppActivationChanged(bool Active) {
    if (!Active) ClearGameInput();
}
void AAvenueWalker::ToggleMenu() {
    auto* PC=Cast<APlayerController>(Controller);
    auto* Viewport=GetWorld()->GetGameViewport();
    if (!PC || !Viewport) return;
    ClearGameInput();
    MenuOpen=!MenuOpen;
    PC->bShowMouseCursor=MenuOpen;
    if (MenuOpen) {
        SAssignNew(SettingsPanel, SAvenueSettings).Walker(this);
        Viewport->AddViewportWidgetContent(SettingsPanel.ToSharedRef(), 10);
        PC->SetInputMode(FInputModeUIOnly().SetWidgetToFocus(SettingsPanel).SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock));
    } else {
        SettingsPanel->CommitQuality();
        Viewport->RemoveViewportWidgetContent(SettingsPanel.ToSharedRef());
        SettingsPanel.Reset();
        PointerReleased=false;
        PC->SetInputMode(FInputModeGameOnly().SetConsumeCaptureMouseDown(false));
        GConfig->Flush(false,GGameUserSettingsIni);
    }
}
void AAvenueHUD::DrawHUD() {
    Super::DrawHUD();
    auto* P=Cast<AAvenueWalker>(GetOwningPawn());
    if(!P || P->MenuOpen || !P->ShowHints || !Canvas) return;
    if(!P->Driven && !P->IsInFreecam()) {
        if(!P->PointerReleased) {
            const float X=Canvas->ClipX*.5f,Y=Canvas->ClipY*.5f;
            DrawRect(FLinearColor(0,0,0,.7f),X-5,Y-1.5f,10,3);
            DrawRect(FLinearColor(0,0,0,.7f),X-1.5f,Y-5,3,10);
            DrawRect(FLinearColor::White,X-4,Y-.5f,8,1);
            DrawRect(FLinearColor::White,X-.5f,Y-4,1,8);
        }
        for(TActorIterator<AAvenueCoffee> It(GetWorld());It;++It)
            if(It->InReach(P->GetActorLocation()-FVector(0,0,86)))
                DrawText(It->Prompt(),FLinearColor::White,Canvas->ClipX*.50f-42,Canvas->ClipY*.60f);
    }
    const TCHAR* Controls=P->IsInFreecam() ? TEXT("WASD   Fly      E / Q   Up / down      F   Return to body      Esc   Flight speed / graphics")
        : P->Driven ? TEXT("WASD   Drive      Shift   Handbrake      ← / →   Signals      E   Exit at rest      T   Day / night      R   Reset      Esc   Graphics")
        : TEXT("WASD   Move      Space   Jump      Shift   Sprint      E   Interact      T   Day / night      J   Herald Sq      F   Freecam      R   Reset      Esc   Settings");
    DrawText(Controls,FLinearColor::White,22,Canvas->ClipY-32);
    if(P->Driven) DrawText(FString::Printf(TEXT("%s   %d mph"),P->Driven->IsReversing()?TEXT("R"):TEXT("D"),FMath::RoundToInt(FMath::Abs(P->Driven->Speed())*.0223694f)),FLinearColor::White,Canvas->ClipX-155,Canvas->ClipY-78,nullptr,1.6f);
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
    if(RoadStage==-1) {
        if(TestTime<2) return;
        FScreenshotRequest::RequestScreenshot(TEXT("FifthNight.png"),false,false);
        RoadStage=0;
        return;
    }
    if(RoadStage==0 && TestTime<2.25f) return;
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
        TestTime=1;
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
