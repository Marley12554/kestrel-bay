#include "AvenueStreet.h"
#include "Sound/SoundWave.h"
#include "AvenueGameMode.h"
#include "Animation/AnimationAsset.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "GameFramework/CharacterMovementComponent.h"

AAvenueFixtures::AAvenueFixtures() {
    Fixtures=CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>("Fixtures");
    SetRootComponent(Fixtures);
    Fixtures->SetMobility(EComponentMobility::Static);
}
void AAvenueFixtures::Install(UStaticMesh* Shape,UMaterialInterface* TintMaterial,const TArray<FTransform>& Transforms,const TArray<FLinearColor>& Colors,bool Solid) {
    Fixtures->SetStaticMesh(Shape);
    Fixtures->SetCollisionProfileName(Solid?"BlockAll":"NoCollision");
    if(TintMaterial) {
        Fixtures->SetMaterial(0,TintMaterial);
        Fixtures->SetNumCustomDataFloats(3);
    }
    Fixtures->AddInstances(Transforms,false,true,false);
    if(TintMaterial && Transforms.Num()==Colors.Num()) {
        for(int32 I=0;I<Colors.Num();++I) {
            Fixtures->SetCustomDataValue(I,0,Colors[I].R,false);
            Fixtures->SetCustomDataValue(I,1,Colors[I].G,false);
            Fixtures->SetCustomDataValue(I,2,Colors[I].B,false);
        }
        Fixtures->MarkRenderStateDirty();
    }
}

AAvenueDoor::AAvenueDoor() {
    PrimaryActorTick.bCanEverTick=true;
    Leaf=CreateDefaultSubobject<UStaticMeshComponent>("Leaf");
    SetRootComponent(Leaf);
    Leaf->SetMobility(EComponentMobility::Movable);
    Leaf->SetCollisionProfileName("BlockAllDynamic");
}
void AAvenueDoor::BeginPlay() { Super::BeginPlay(); Initial=GetActorRotation(); }
void AAvenueDoor::Interact() { if(!Revolving) TargetAngle=TargetAngle==0?94:0; }
void AAvenueDoor::Tick(float Dt) {
    Super::Tick(Dt);
    if(Revolving) {
        const auto* P=Cast<AAvenueWalker>(UGameplayStatics::GetPlayerPawn(this,0));
        if(!P || P->Driven) return;
        FVector Offset=P->GetActorLocation()-GetActorLocation();
        if(Offset.Size2D()>148||FMath::Abs(Offset.Z)>180) return;
        const FVector Intent=P->GetCharacterMovement()->GetCurrentAcceleration().GetSafeNormal2D();
        if(Intent.IsNearlyZero()) return;
        FHitResult Touch;
        const FVector From=P->GetActorLocation();
        if(!Leaf->LineTraceComponent(Touch,From,From+Intent*60,FCollisionQueryParams(TEXT("PushBar"),true))) return;
        const float Tangent=FVector::CrossProduct(Offset.GetSafeNormal2D(),Intent).Z;
        TargetAngle+=Tangent*105*Dt;
    }
    Angle=FMath::FInterpConstantTo(Angle,TargetAngle,Dt,115);
    SetActorRotation(Initial+FRotator(0,Angle,0));
}

AAvenueTraveller::AAvenueTraveller() {
    PrimaryActorTick.bCanEverTick=true;
    auto* Pivot=CreateDefaultSubobject<USceneComponent>("StreetPosition");
    SetRootComponent(Pivot);
    Person=CreateDefaultSubobject<USkeletalMeshComponent>("Pedestrian");
    Person->SetupAttachment(Pivot);
    Person->SetRelativeRotation(FRotator(0,-90,0));
    Person->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Person->bEnableUpdateRateOptimizations=true;
    Person->VisibilityBasedAnimTickOption=EVisibilityBasedAnimTickOption::OnlyTickPoseWhenRendered;
    Cab=CreateDefaultSubobject<UStaticMeshComponent>("TrafficVehicle");
    Cab->SetupAttachment(Pivot);
    Cab->SetRelativeRotation(FRotator(0,90,0));
    Cab->SetMobility(EComponentMobility::Movable);
    Cab->SetCollisionProfileName("BlockAllDynamic");
}
void AAvenueTraveller::BeginPlay() {
    Super::BeginPlay();
    if(Gait) { Person->PlayAnimation(Gait,true); Person->SetPlayRate(Pace/145.f); }
    GroundTimer=FMath::FRandRange(0,.23f);
}
void AAvenueTraveller::Tick(float Dt) {
    Super::Tick(Dt);
    if(Route.Num()<2) return;
    FVector Here=GetActorLocation();
    FVector To=Route[Next]-Here;
    if(To.Size2D()<FMath::Max(12.f,Pace*Dt)) { Next=(Next+1)%Route.Num(); To=Route[Next]-Here; }
    const auto* P=Cast<AAvenueWalker>(UGameplayStatics::GetPlayerPawn(this,0));
    if(Traffic && P && P->Driven) {
        const FVector Other=P->Driven->GetActorLocation()-Here;
        if(Other.SizeSquared2D()<FMath::Square(520.f) && FVector::DotProduct(Other.GetSafeNormal2D(),To.GetSafeNormal2D())>.5) return;
    }
    FVector Desired=Here+To.GetSafeNormal2D()*FMath::Min<double>(Pace*Dt,To.Size2D());
    GroundTimer-=Dt;
    if(GroundTimer<=0) {
        GroundTimer=.23;
        FHitResult Hit;
        if(GetWorld()->LineTraceSingleByChannel(Hit,Desired+FVector(0,0,120),Desired-FVector(0,0,180),ECC_Visibility,FCollisionQueryParams(TEXT("Pavement"),true,this)))
            Desired.Z=Hit.ImpactPoint.Z+2;
    }
    SetActorLocationAndRotation(Desired,FMath::RInterpTo(GetActorRotation(),To.GetSafeNormal2D().Rotation(),Dt,Traffic?3:7));
}

AAvenueCoffee::AAvenueCoffee() {
    PrimaryActorTick.bCanEverTick=true;
    Cup=CreateDefaultSubobject<UStaticMeshComponent>("Order");
    SetRootComponent(Cup);
    Cup->SetMobility(EComponentMobility::Movable);
    Cup->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Cup->SetCastShadow(false);
    Cup->SetVisibility(false);
}
void AAvenueCoffee::Use(USceneComponent* View) {
    if(Order==EOrder::Available) {
        Order=EOrder::Brewing;
        BrewTime=2.6;
        UGameplayStatics::PlaySoundAtLocation(this,LoadObject<USoundWave>(nullptr,TEXT("/Game/Manhattan/Audio/brew.brew")),GetActorLocation());
    } else if(Order==EOrder::Ready) {
        Order=EOrder::Carried;
        Cup->SetStaticMesh(HeldModel);
        AttachToComponent(View,FAttachmentTransformRules::SnapToTargetNotIncludingScale);
        SetActorRelativeLocation(FVector(47,18,-19));
        SetActorRelativeRotation(FRotator(-3,7,-5));
    }
}
FString AAvenueCoffee::Prompt() const {
    switch(Order) {
    case EOrder::Available:return TEXT("E   Order coffee");
    case EOrder::Brewing:return TEXT("Brewing coffee…");
    case EOrder::Ready:return TEXT("E   Take coffee");
    default:return FString();
    }
}
void AAvenueCoffee::Tick(float Delta) {
    Super::Tick(Delta);
    if(Order==EOrder::Brewing && (BrewTime-=Delta)<=0) { Order=EOrder::Ready; Cup->SetVisibility(true); }
    if(Order==EOrder::Carried) {
        auto* P=Cast<AAvenueWalker>(UGameplayStatics::GetPlayerPawn(this,0));
        Cup->SetVisibility(P && !P->Driven);
    }
}
