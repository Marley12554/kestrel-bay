#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AvenueStreet.generated.h"
class UHierarchicalInstancedStaticMeshComponent;
class USkeletalMeshComponent;
class UAnimationAsset;
class UBoxComponent;
class UPoseableMeshComponent;
class AAvenueWalker;
void PoseAvenueDriver(const AActor& Vehicle, USkeletalMeshComponent& Driver, UPoseableMeshComponent& Seat, const TCHAR* Model);

UCLASS()
class AAvenueFixtures : public AActor {
    GENERATED_BODY()
public:
    AAvenueFixtures();
    UPROPERTY(VisibleAnywhere) TObjectPtr<UHierarchicalInstancedStaticMeshComponent> Fixtures;
    UFUNCTION(BlueprintCallable,Category="Survey") void Install(UStaticMesh* Shape,UMaterialInterface* TintMaterial,
        const TArray<FTransform>& Transforms,const TArray<FLinearColor>& Colors,bool Solid);
};

UCLASS()
class AAvenueDoor : public AActor {
    GENERATED_BODY()
public:
    AAvenueDoor();
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Leaf;
    UPROPERTY(EditAnywhere) bool Revolving=false;
    void Interact(FVector Walker);
    FVector Guide(AAvenueWalker& Walker, FVector Velocity, float Dt);
    virtual void BeginPlay() override;
    virtual void Tick(float Dt) override;
private:
    FRotator Initial;
    float Angle=0, TargetAngle=0;
    UPROPERTY() TArray<TObjectPtr<UBoxComponent>> Panels;
    float AngularVelocity=0;
    uint64 LastPush=0;
};

UCLASS()
class AAvenueTraveller : public AActor {
    GENERATED_BODY()
public:
    AAvenueTraveller();
    UPROPERTY(VisibleAnywhere) TObjectPtr<USkeletalMeshComponent> Person;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Cab;
    UPROPERTY(EditAnywhere) TObjectPtr<UAnimationAsset> Gait;
    UPROPERTY(EditAnywhere) TObjectPtr<UAnimationAsset> Idle;
    UPROPERTY(EditAnywhere) TArray<FVector> Route;
    UPROPERTY(EditAnywhere) float Pace=140;
    UPROPERTY(EditAnywhere) bool Traffic=false;
    UPROPERTY(EditAnywhere) bool AvenueTraffic=false;
    UPROPERTY(EditAnywhere) TArray<FVector> StopLines;
    UPROPERTY(EditAnywhere) TArray<int32> CrossingGroups;
    UPROPERTY(EditAnywhere) TArray<TObjectPtr<UStaticMesh>> WheelModels;
    UPROPERTY(EditAnywhere) TArray<FVector> WheelCenters;
    FVector ReachFor(FVector CupBase, float Amount);
    virtual void BeginPlay() override;
    virtual void Tick(float Dt) override;
private:
    int32 Next=0;
    float GroundTimer=0, TravelSpeed=0, Reaction=0, WaitTime=0, Phase=0, Spacing=1, PassRight=0;
    bool Waiting=false;
    UPROPERTY() TObjectPtr<UBoxComponent> TrafficBody;
    bool PlayingIdle=false;
    float WheelAngle=0;
    UPROPERTY() TArray<TObjectPtr<UStaticMeshComponent>> Wheels;
    UPROPERTY() TObjectPtr<UPoseableMeshComponent> ServingPose;
};

UCLASS()
class AAvenueCoffee : public AActor {
    GENERATED_BODY()
public:
    AAvenueCoffee();
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Cup;
    UPROPERTY(EditAnywhere) TObjectPtr<UStaticMesh> HeldModel;
    UPROPERTY(EditAnywhere) TObjectPtr<AAvenueTraveller> Barista;
    UPROPERTY(EditAnywhere) FVector BrewStart;
    UPROPERTY(EditAnywhere) FTransform Grip;
    UPROPERTY(EditAnywhere) FVector CustomerSpot;
    bool InReach(FVector Feet) const;
    bool Indoors(FVector Position) const;
    void Use(USceneComponent* View);
    void ShowHeldCup(bool Visible);
    virtual void BeginPlay() override;
    FString Prompt() const;
    virtual void Tick(float Delta) override;
private:
    enum class EOrder { Available, Brewing, Ready, Carried };
    EOrder Order=EOrder::Available;
    float BrewTime=0, Reach=0, Pickup=0;
    FVector Counter;
    FTransform StartGrip;
    TWeakObjectPtr<USceneComponent> CarryView;
};
