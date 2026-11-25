#pragma once
#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/Character.h"
#include "GameFramework/HUD.h"
#include "AvenueGameMode.generated.h"

class UCameraComponent;
class UAudioComponent;
class USoundWave;
class UBoxComponent;
class UPoseableMeshComponent;
class AAvenueDoor;
class UAvenueSnow;
class AAvenueCoffee;
class SAvenueSettings;

UCLASS()
class AAvenueCar : public AActor
{
    GENERATED_BODY()
public:
    AAvenueCar();
    void Drive(float Delta, float Throttle, float Steer, bool Handbrake, UAvenueSnow& Surface, int Quality);
    void Signal(bool Left);
    void Silence();
    void ShowDriver(bool Visible);
    bool HasTireContact() const { return ContactCount > 0; }
    UFUNCTION(BlueprintCallable,Category="Sedan") void SetWheel(int Index,UStaticMesh* Wheel,FVector Center);
    float Speed() const { return FVector::DotProduct(VelocityXY, GetActorForwardVector()); }
    bool IsReversing() const { return Backing; }
#if !UE_BUILD_SHIPPING
    TWeakObjectPtr<AActor> LastDriveBlocker;
#endif
private:
    UPROPERTY() TObjectPtr<UBoxComponent> Chassis;
    virtual void BeginPlay() override;
    UPROPERTY() TObjectPtr<class USkeletalMeshComponent> Driver;
    UPROPERTY() TObjectPtr<UPoseableMeshComponent> SeatedDriver;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Exterior;
    UPROPERTY() TArray<TObjectPtr<UAudioComponent>> AudioLayers;
    UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Wheels;
    UPROPERTY() TArray<FVector> Hubs;
    void UpdateAudio(float Dt,float SpeedMps,float Slip,float Corner,bool Contact);
    void MoveOnTires(float Dt, float Throttle, float Steer, bool Handbrake);
    void ApplyAxleGrip(float Dt, float Axle, float WheelAngle, float Load, float Grip);
    void UpdateDriveSpeed(float Dt, float Throttle, bool Handbrake);
    void UpdateLamps(bool Braking);
    UPROPERTY() TArray<TObjectPtr<class USpotLightComponent>> Headlights;
    UPROPERTY() TArray<TObjectPtr<class UMaterialInstanceDynamic>> LensMaterials;
    UPROPERTY() TObjectPtr<class UTextRenderComponent> RearPlate;
    UPROPERTY() TObjectPtr<UAudioComponent> Wind;
    UPROPERTY() TObjectPtr<UAudioComponent> IndicatorClick;
    UPROPERTY() TArray<TObjectPtr<USoundWave>> ClickSounds;
    UPROPERTY() TObjectPtr<class UInstancedStaticMeshComponent> WheelPowder;
    void UpdateTireSurface(UAvenueSnow& Surface, float Dt, int Quality);
    float PowderClock[4]={}, TireCover[4]={}, ScuffPitch[2]={1.f,1.f};
    int32 NextPuff=0;
    bool Backing=false, SignalLit=false, SignalTurned=false, Occupied=false;
    float SignedSpeed=0, ShiftWait=0, SlipAngle=0, SteerHold=0, PreviousSteer=0;
    float PreviousSupport=0, SignalYaw=0;
    bool HadSupport=false;
    int32 ContactCount=0;
    bool StreetTires[4]={};
    float ScuffAge=0, ScuffDuration=0, ScuffGain=0;
    int ScuffVoice=0;
    float Spin=0;
    FVector VelocityXY = FVector::ZeroVector;
    float VerticalSpeed = 0, Steering = 0, YawRate = 0, SignalClock = 0;
    int SignalSide = 0;
};

UCLASS()
class AAvenueWalker : public ACharacter
{
    GENERATED_BODY()
public:
    AAvenueWalker(const FObjectInitializer& ObjectInitializer);
    virtual void EndPlay(const EEndPlayReason::Type Reason) override;
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
    virtual void Landed(const FHitResult& Hit) override;
    virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
    bool MenuOpen = false;
    int Quality = 0;
    static constexpr float MinLookSensitivity = .0625f;
    static constexpr float MaxLookSensitivity = 4.f;
    float LookSensitivity=1;
    void ToggleMenu();
    void QueueWalkInput();
    FVector GuideThroughDoor(FVector Direction, float Dt);
    bool IsNight() const { return Night; }
    bool IsInFreecam() const { return Freecam; }
    float FlightMph=95.f;
    bool ShowHints=true;
    bool PointerReleased=false;
    void ResetPrototype();
    void SetLookSensitivity(float Value);
    void ChangeQuality(int NewQuality);
    UPROPERTY() TObjectPtr<AAvenueCar> Driven;
private:
    UPROPERTY() TObjectPtr<UCameraComponent> Camera;
    float Forward = 0, Side = 0, StepDistance = 0, OrbitHold = 0;
    bool Sprint = false, Night = false;
    void DriveOrInteract();
    void ToggleDay();
    void ClearGameInput();
    void OnAppActivationChanged(bool Active);
    UPROPERTY() TArray<TObjectPtr<AAvenueDoor>> EntryDoors;
    UPROPERTY() TObjectPtr<AAvenueCoffee> Reserve;
    UPROPERTY() TObjectPtr<AAvenueCar> Parked;
    UPROPERTY() TObjectPtr<UAvenueSnow> Snow;
    UPROPERTY() TObjectPtr<UAudioComponent> OutdoorBed;
    UPROPERTY() TObjectPtr<UAudioComponent> IndoorBed;
    UPROPERTY() TObjectPtr<class UMaterialInstanceDynamic> LampGlass;
    UPROPERTY() TObjectPtr<AActor> SnowCloud;
    UPROPERTY() TObjectPtr<class UMaterialInstanceDynamic> Flakes;
    bool LeftFoot=false;
    int LastStep=INDEX_NONE;
    float RoomMix=0;
    bool Freecam=false;
    int32 MotionLevel=2;
    float WalkPhase=.5f, GaitAmount=0, RunMix=0, LensMix=0;
    FRotator BodyLook=FRotator::ZeroRotator;
    TSharedPtr<SAvenueSettings> SettingsPanel;
    UPROPERTY() TArray<TObjectPtr<USoundWave>> ConcreteSteps;
    UPROPERTY() TArray<TObjectPtr<USoundWave>> SnowSteps;
    void ToggleFlight();
    void Fly(float Delta);
    void UpdateStride(float Delta);
    void ToggleHints() { ShowHints=!ShowHints; }
    void CycleMotion();
    void ReleasePointer();
    void CapturePointer();
    void LookAtHerald();
    UPROPERTY() TObjectPtr<class UMaterialInstanceDynamic> CitySkin;
    TOptional<FTransform> HeraldReturn;
    FRotator ReturnLook=FRotator::ZeroRotator;
    void MoveForward(float Value);
    void MoveRight(float Value);
    void LookYaw(float Value);
    void LookPitch(float Value);
    void StartJump();
    void Step();
    void Benchmark(float Delta);
    void CheckStreet(float Delta);
    bool RoadTest=false;
    int RoadStage=-1;
    float TestTime=0;
    FVector TestStart=FVector::ZeroVector;
    bool Bench=false, Captured=false, DrivingBench=false, BlockBench=false;
    float BenchPeakSpeed=0;
    double BenchStart=0, LastFrame=0, NextBurst=0;
    TArray<double> BaselineTimes, StressTimes;
    UPROPERTY() TArray<TObjectPtr<class UPointLightComponent>> Flashes;
    void StartSprint();
    void EndSprint();
    void LeftSignal() { if(Driven) Driven->Signal(true); }
    void RightSignal() { if(Driven) Driven->Signal(false); }
};

UCLASS()
class AAvenueHUD : public AHUD
{
    GENERATED_BODY()
public:
    virtual void DrawHUD() override;
};

UCLASS()
class AAvenueGameMode : public AGameModeBase
{
    GENERATED_BODY()
public:
    AAvenueGameMode();
    UFUNCTION(BlueprintCallable, Category="Survey")
    static AActor* PlaceSurveyActor(UWorld* TargetWorld, TSubclassOf<AActor> ActorType, FTransform Placement);
};
