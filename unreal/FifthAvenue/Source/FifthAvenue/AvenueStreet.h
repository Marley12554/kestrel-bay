#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AvenueStreet.generated.h"
class UHierarchicalInstancedStaticMeshComponent;
class USkeletalMeshComponent;
class UAnimationAsset;

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
    void Interact();
    virtual void BeginPlay() override;
    virtual void Tick(float Dt) override;
private:
    FRotator Initial;
    float Angle=0, TargetAngle=0;
};

UCLASS()
class AAvenueTraveller : public AActor {
    GENERATED_BODY()
public:
    AAvenueTraveller();
    UPROPERTY(VisibleAnywhere) TObjectPtr<USkeletalMeshComponent> Person;
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Cab;
    UPROPERTY(EditAnywhere) TObjectPtr<UAnimationAsset> Gait;
    UPROPERTY(EditAnywhere) TArray<FVector> Route;
    UPROPERTY(EditAnywhere) float Pace=140;
    UPROPERTY(EditAnywhere) bool Traffic=false;
    virtual void BeginPlay() override;
    virtual void Tick(float Dt) override;
private:
    int32 Next=0;
    float GroundTimer=0;
};

UCLASS()
class AAvenueCoffee : public AActor {
    GENERATED_BODY()
public:
    AAvenueCoffee();
    UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Cup;
    UPROPERTY(EditAnywhere) TObjectPtr<UStaticMesh> HeldModel;
    void Use(USceneComponent* View);
    FString Prompt() const;
    virtual void Tick(float Delta) override;
private:
    enum class EOrder { Available, Brewing, Ready, Carried };
    EOrder Order=EOrder::Available;
    float BrewTime=0;
};
