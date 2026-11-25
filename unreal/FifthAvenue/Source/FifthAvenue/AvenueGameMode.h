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

UCLASS()
class AAvenueCar : public AActor
{
    GENERATED_BODY()
public:
    AAvenueCar();
    void Drive(float Delta, float Throttle, float Steer, bool Handbrake);
    void Signal(bool Left);
    void Silence();
    void ShowDriver(bool Visible);
    UFUNCTION(BlueprintCallable,Category="Sedan") void SetWheel(int Index,UStaticMesh* Wheel,FVector Center);
    float Speed() const { return FVector::DotProduct(VelocityXY, GetActorForwardVector()); }
private:
    UPROPERTY() TObjectPtr<UBoxComponent> Chassis;
    virtual void BeginPlay() override;
    UPROPERTY() TObjectPtr<class USkeletalMeshComponent> Driver;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Exterior;
    UPROPERTY() TArray<TObjectPtr<UAudioComponent>> AudioLayers;
    UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Wheels;
    UPROPERTY() TArray<FVector> Hubs;
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
    AAvenueWalker();
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
    virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
    bool MenuOpen = false;
    int Quality = 0;
    void ChangeQuality(int NewQuality);
    UPROPERTY() TObjectPtr<AAvenueCar> Driven;
private:
    UPROPERTY() TObjectPtr<UCameraComponent> Camera;
    float Forward = 0, Side = 0, StepDistance = 0;
    bool Sprint = false, Night = false;
    void DriveOrInteract();
    void ToggleDay();
    void ToggleMenu();
    void ToggleFlight();
    void LookAtHerald();
    void MoveForward(float Value);
    void MoveRight(float Value);
    void LookYaw(float Value);
    void LookPitch(float Value);
    void StartJump();
    void Step();
    void Benchmark(float Delta);
    bool Bench=false, Captured=false, DrivingBench=false, BlockBench=false;
    float BenchPeakSpeed=0;
    double BenchStart=0, LastFrame=0, NextBurst=0;
    TArray<double> BaselineTimes, StressTimes;
    UPROPERTY() TArray<TObjectPtr<class UPointLightComponent>> Flashes;
    void StartSprint() { Sprint=true; }
    void EndSprint() { Sprint=false; }
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
