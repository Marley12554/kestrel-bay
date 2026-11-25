#include "AvenueStreet.h"
#include "Sound/SoundWave.h"
#include "AvenueGameMode.h"
#include "Animation/AnimationAsset.h"
#include "TwoBoneIK.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/PoseableMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "EngineUtils.h"
#include "Animation/AnimSequence.h"
#include "Engine/SkeletalMesh.h"

void PoseAvenueDriver(const AActor& Vehicle, USkeletalMeshComponent& Driver, UPoseableMeshComponent& Seat, const TCHAR* Model)
{
    const FString Prefix=FString::Printf(TEXT("/Game/Manhattan/Citizens/%s/%s/SkeletalMeshes/%s"),Model,Model,Model);
    Driver.SetSkeletalMeshAsset(LoadObject<USkeletalMesh>(nullptr,*Prefix));
    Driver.PlayAnimation(LoadObject<UAnimSequence>(nullptr,*(Prefix+"Sit_Stand")),false);
    Driver.SetPosition(3,false);
    Driver.SetPlayRate(0);
    Driver.TickAnimation(0,false);
    Driver.RefreshBoneTransforms();
    Seat.SetSkinnedAssetAndUpdate(Driver.GetSkeletalMeshAsset());
    Seat.CopyPoseFromSkeletalComponent(&Driver);
    const FVector PedalDirection=Seat.GetComponentTransform().InverseTransformVectorNoScale(
        Vehicle.GetActorForwardVector()*.97f-Vehicle.GetActorUpVector()*.25f).GetSafeNormal();
    for (int SideIndex=0; SideIndex<2; ++SideIndex) {
        const FName Calf=SideIndex ? TEXT("calf_r") : TEXT("calf_l");
        const FName Foot=SideIndex ? TEXT("foot_r") : TEXT("foot_l");
        FTransform Shin=Seat.GetBoneTransformByName(Calf,EBoneSpaces::ComponentSpace);
        FTransform Shoe=Seat.GetBoneTransformByName(Foot,EBoneSpaces::ComponentSpace);
        const FVector Ankle=Shoe.GetLocation()-Shin.GetLocation();
        Shin.SetRotation(FQuat::FindBetweenNormals(Ankle.GetSafeNormal(),PedalDirection)*Shin.GetRotation());
        Seat.SetBoneTransformByName(Calf,Shin,EBoneSpaces::ComponentSpace);
        Shoe.SetLocation(Shin.GetLocation()+PedalDirection*Ankle.Size());
        Seat.SetBoneTransformByName(Foot,Shoe,EBoneSpaces::ComponentSpace);
    }
    Seat.RefreshBoneTransforms();
    Driver.SetComponentTickEnabled(false);
}

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

AAvenueDoor::AAvenueDoor()
{
    PrimaryActorTick.bCanEverTick=true;
    Leaf=CreateDefaultSubobject<UStaticMeshComponent>("Leaf");
    SetRootComponent(Leaf);
    Leaf->SetMobility(EComponentMobility::Movable);
    Leaf->SetCollisionProfileName("NoCollision");
}
void AAvenueDoor::BeginPlay()
{
    Super::BeginPlay();
    Initial=GetActorRotation();
    Leaf->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    // The source uses thin rectangular blockers, independent of the glass, bars and spindle.
    for (int I=0; I<(Revolving ? 4 : 1); ++I) {
        auto* Panel=NewObject<UBoxComponent>(this,*FString::Printf(TEXT("DoorPanel%d"),I));
        Panel->SetupAttachment(Leaf);
        const FRotator Turn(0,I*90,0);
        Panel->SetRelativeRotation(Turn);
        Panel->SetRelativeLocation(Turn.RotateVector(Revolving ? FVector(57.1,0,139) : FVector(66.5,0,166)));
        Panel->SetBoxExtent(Revolving ? FVector(57.1,1.8,125) : FVector(66.5,4,150));
        Panel->SetCollisionProfileName("BlockAllDynamic");
        Panel->CanCharacterStepUpOn=ECB_No;
        Panel->RegisterComponent();
        Panels.Add(Panel);
    }
}
void AAvenueDoor::Interact(FVector Walker)
{
    if (Revolving) return;
    if (!FMath::IsNearlyZero(TargetAngle)) TargetAngle=0;
    else TargetAngle=FRotationMatrix(Initial).GetUnitAxis(EAxis::Y).Dot(Walker-GetActorLocation())>=0 ? -93.4f : 93.4f;
    UGameplayStatics::PlaySoundAtLocation(this,LoadObject<USoundWave>(nullptr,TEXT("/Game/Manhattan/Audio/door_chime.door_chime")),GetActorLocation());
}
FVector AAvenueDoor::Guide(AAvenueWalker& Walker, FVector Velocity, float Dt)
{
    const FVector Center=Walker.GetActorLocation();
    const FRotator Opening=Initial+FRotator(0,FMath::RadiansToDegrees(.42f),0);
    const FVector Feet=Opening.UnrotateVector(Center-GetActorLocation()-FVector(0,0,86));
    if (FMath::Abs(Feet.X)>86 || FMath::Abs(Feet.Y)>162 || FMath::Abs(Feet.Z)>45) return Velocity;
    FVector Local=Opening.UnrotateVector(Velocity);
    if (FMath::Abs(Local.X)<FMath::Abs(Local.Y)*.75 && !(FMath::Abs(Feet.Y)>119 && Feet.Y*Local.Y>0)) {
        const float Side=FMath::Abs(Feet.X)>12 ? FMath::Sign(Feet.X) : -FMath::Sign(Local.Y);
        const float Lane=31+40*FMath::Exp(-Feet.Y*Feet.Y/3500);
        Local.X+=FMath::Clamp((Side*Lane-Feet.X)*.04,-1.,1.)*FMath::Abs(Local.Y);
        Velocity=Opening.RotateVector(Local.GetSafeNormal())*Velocity.Size();
    }
    const FVector Dir=Velocity.GetSafeNormal();
    const float Radius=Walker.GetCapsuleComponent()->GetScaledCapsuleRadius();
    for (auto& Wing:Panels) {
        FHitResult Hit;
        if (!Wing->SweepComponent(Hit,Center,Center+Dir*(Velocity.Size()*Dt+2.0),FQuat::Identity,
                FCollisionShape::MakeSphere(Radius),false)) continue;
        const FVector Tangent=Wing->GetRightVector();
        const float Pressure=FVector::DotProduct(Velocity,Tangent);
        if (FVector::DotProduct(Dir,Hit.Normal)>=-.001 || FMath::IsNearlyZero(Pressure)) continue;
        const float Lever=FMath::Max(32.,FVector::DotProduct(Center-GetActorLocation(),Wing->GetForwardVector()));
        AngularVelocity=FMath::Clamp(Pressure/Lever,-3.2f,3.2f);
        Angle+=FMath::RadiansToDegrees(AngularVelocity*Dt);
        LastPush=GFrameCounter;
        SetActorRotation(Initial+FRotator(0,Angle,0));
        break;
    }
    return Velocity;
}
void AAvenueDoor::Tick(float Dt)
{
    Super::Tick(Dt);
    if (!Revolving) {
        if (Angle==TargetAngle) return;
        Angle=FMath::FInterpConstantTo(Angle,TargetAngle,Dt,160.f);
    } else {
        if (AngularVelocity==0 || LastPush==GFrameCounter) return;
        auto* Walker=Cast<AAvenueWalker>(UGameplayStatics::GetPlayerPawn(this,0));
        // A following leaf cannot drive a stationary walker around the drum.
        if (Walker && FVector::DistSquared2D(GetActorLocation(),Walker->GetActorLocation())<FMath::Square(146.f)) {
            AngularVelocity=0;
            return;
        }
        const float Next=FMath::FInterpConstantTo(AngularVelocity,0.f,Dt,23.f);
        Angle+=FMath::RadiansToDegrees(.5f*(Next+AngularVelocity)*Dt);
        AngularVelocity=Next;
    }
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
    Cab->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    TrafficBody=CreateDefaultSubobject<UBoxComponent>("TrafficBody");
    TrafficBody->SetupAttachment(Pivot);
    TrafficBody->SetBoxExtent(FVector(222,94,40));
    TrafficBody->SetRelativeLocation(FVector(0,0,69));
    TrafficBody->SetCollisionProfileName("NoCollision");
}
void AAvenueTraveller::BeginPlay() {
    Super::BeginPlay();
    if (Traffic) {
        TrafficBody->SetCollisionProfileName("BlockAllDynamic");
        Person->SetRelativeLocation(FVector(29,-39,-10));
        Person->SetVisibility(false);
        auto* Seat=NewObject<UPoseableMeshComponent>(this,TEXT("TrafficDriver"));
        Seat->SetupAttachment(Person);
        Seat->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Seat->RegisterComponent();
        PoseAvenueDriver(*this,*Person,*Seat,AvenueTraffic ? TEXT("maya") : TEXT("sam"));
        for(int I=0;I<WheelModels.Num() && WheelCenters.IsValidIndex(I);++I) {
            auto* Wheel=NewObject<UStaticMeshComponent>(this);
            Wheel->SetupAttachment(Cab);
            Wheel->SetRelativeLocation(WheelCenters[I]);
            Wheel->SetStaticMesh(WheelModels[I]);
            Wheel->SetCollisionEnabled(ECollisionEnabled::NoCollision);
            Wheel->RegisterComponent();
            Wheels.Add(Wheel);
        }
    }
    Cab->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    FRandomStream Rng(GetTypeHash(GetActorLocation()));
    Phase=Rng.FRandRange(0,2*PI); Reaction=Rng.FRandRange(.05f,1.6f);
    if(Gait && !Traffic) {
        Person->PlayAnimation(Gait,true);
        Person->SetPosition(Rng.FRand()*Gait->GetPlayLength());
        if(Route.Num()>1) Person->SetPlayRate(Pace/145.f);
    }
    if (Route.Num()>=2) {
        Next=1;
        Waiting=CrossingGroups.IsValidIndex(0) && CrossingGroups[0]!=2 && FVector::Dist2D(GetActorLocation(),Route[0])<80;
        SetActorRotation((Route[Next]-GetActorLocation()).GetSafeNormal2D().Rotation());
    }
    GroundTimer=FMath::FRandRange(0,.23f);
}
void AAvenueTraveller::Tick(float Dt) {
    Super::Tick(Dt);
    if(Route.Num()<2) return;
    FVector Here=GetActorLocation();
    FVector To=Route[Next]-Here;
    if(To.Size2D()<FMath::Max(3.f,TravelSpeed*Dt)) {
        Waiting=CrossingGroups.IsValidIndex(Next) && CrossingGroups[Next]!=2;
        if(Waiting) { WaitTime=0; TravelSpeed=0; }
        Next=(Next+1)%Route.Num(); To=Route[Next]-Here;
    }
    const float Cycle=FMath::Fmod(GetWorld()->GetTimeSeconds(),46.f);
    const FVector Direction=To.GetSafeNormal2D(), Side(-Direction.Y,Direction.X,0);
    float Target=Pace*Spacing;
    if(Waiting) {
        const int Previous=(Next+Route.Num()-1)%Route.Num();
        const bool Across=CrossingGroups[Previous]==1;
        const bool Walk=Across ? (Cycle>=23 && Cycle<32) : Cycle<9;
        WaitTime=Walk?WaitTime+Dt:0;
        if(WaitTime>=Reaction) Waiting=false; else Target=0;
    }
    if(Traffic && !(AvenueTraffic?Cycle<17:(Cycle>=23 && Cycle<40))) {
        for(FVector Stop:StopLines) {
            const FVector Delta=Stop-Here;
            const float Gap=Delta|Direction;
            if(Gap>=-8 && Gap<2000 && FMath::Abs(Delta|Side)<115)
                Target=FMath::Min(Target,FMath::Sqrt(2.f*335.f*FMath::Max(0.f,Gap-10.f)));
        }
    }
    const auto* P=Cast<AAvenueWalker>(UGameplayStatics::GetPlayerPawn(this,0));
    if(Traffic && P && P->Driven) {
        const FVector Other=P->Driven->GetActorLocation()-Here;
        const float Gap=Other|Direction;
        if(Gap>0 && Gap<1800 && FMath::Abs(Other|Side)<180)
            Target=FMath::Min(Target,FMath::Sqrt(2.f*360.f*FMath::Max(0.f,Gap-510.f)));
    }
    if(!Traffic && P && P->Driven) {
        const FVector Travel=P->Driven->GetActorForwardVector()*FMath::Sign(P->Driven->Speed());
        const FVector FromCar=Here+Direction*140-P->Driven->GetActorLocation();
        const float Ahead=FromCar|Travel;
        if (Ahead>270 && Ahead<FMath::Min(2200.f,FMath::Abs(P->Driven->Speed())*1.6f+250.f)
            && FMath::Abs(FromCar|P->Driven->GetActorRightVector())<165) Target=0;
    }
    TravelSpeed=FMath::FInterpConstantTo(TravelSpeed,Target,Dt,Traffic?(Target>TravelSpeed?180.f:370.f):(Target>TravelSpeed?210.f:400.f));
    FVector Desired=Here+Direction*FMath::Min<double>(TravelSpeed*Dt,To.Size2D());
    if(!Traffic && TravelSpeed>15 && To.SizeSquared2D()>10000) Desired+=Side*(PassRight*Dt*85);
    GroundTimer-=Dt;
    if(GroundTimer<=0) {
        GroundTimer=.23;
        Spacing=1; PassRight=0;
        if(!Traffic && P && FVector::DistSquared2D(Here,P->Driven?P->Driven->GetActorLocation():P->GetActorLocation())<FMath::Square(14500.f)) {
            for(TActorIterator<AAvenueTraveller> It(GetWorld());It;++It) {
                if(*It==this || It->Traffic || It->Route.IsEmpty()) continue;
                const FVector Gap=It->GetActorLocation()-Here;
                const float Ahead=Gap|Direction;
                if(Ahead<=3 || Ahead>=145 || FMath::Abs(Gap|Side)>=45) continue;
                if((Direction|It->GetActorForwardVector())<.75 || It->Waiting) PassRight=FMath::Max(PassRight,1-Ahead/145.f);
                else if(To.SizeSquared2D()>14400) Spacing=FMath::Min(Spacing,FMath::Clamp((Ahead-38)/90,.16f,1.f));
            }
        }
        FHitResult Hit;
        if(GetWorld()->LineTraceSingleByChannel(Hit,Desired+FVector(0,0,120),Desired-FVector(0,0,180),ECC_Visibility,FCollisionQueryParams(TEXT("Pavement"),true,this)))
            Desired.Z=Hit.ImpactPoint.Z+2;
    }
    FRotator Facing=Direction.Rotation();
    if(!Traffic) {
        const bool Stopped=TravelSpeed<8;
        if(Stopped!=PlayingIdle && Idle) { Person->PlayAnimation(Stopped?Idle:Gait,true); Person->SetPosition(Phase*.17f); PlayingIdle=Stopped; }
        Person->SetPlayRate(Stopped?1.f:FMath::Clamp(TravelSpeed/145.f,.55f,1.55f));
        if(Waiting) Facing.Yaw+=17.f*FMath::Sin(Cycle*.52f+Phase);
    }
    const FRotator Turn=FMath::RInterpTo(GetActorRotation(),Facing,Dt,Traffic?3:Waiting?1:7);
    if(!Wheels.IsEmpty()) {
        const float Distance=FVector::Dist2D(Here,Desired);
        WheelAngle=FMath::Fmod(WheelAngle+FMath::RadiansToDegrees(Distance/33.5f),360.f);
        const float YawDelta=FMath::DegreesToRadians(FMath::FindDeltaAngleDegrees(GetActorRotation().Yaw,Turn.Yaw));
        const float Steer=Distance>.01f ? FMath::Clamp(FMath::RadiansToDegrees(FMath::Atan(287.f*YawDelta/Distance)),-31.f,31.f) : 0.f;
        for(int I=0;I<Wheels.Num();++I) Wheels[I]->SetRelativeRotation(FRotator(0,I<2 ? Steer : 0,-WheelAngle));
    }
    SetActorLocationAndRotation(Desired,Turn);
}

FVector AAvenueTraveller::ReachFor(FVector CupBase, float Amount)
{
    if (Amount<=0.f) {
        if (ServingPose) { ServingPose->SetVisibility(false); Person->SetVisibility(true); Person->VisibilityBasedAnimTickOption=EVisibilityBasedAnimTickOption::OnlyTickPoseWhenRendered; }
        return CupBase;
    }
    if (!ServingPose) {
        ServingPose=NewObject<UPoseableMeshComponent>(this,TEXT("ServingArm"));
        ServingPose->SetupAttachment(Person);
        ServingPose->SetCollisionEnabled(ECollisionEnabled::NoCollision);
        ServingPose->SetSkinnedAssetAndUpdate(Person->GetSkeletalMeshAsset());
        ServingPose->RegisterComponent();
    }
    Person->VisibilityBasedAnimTickOption=EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
    Person->SetVisibility(false);
    ServingPose->SetVisibility(true);
    ServingPose->CopyPoseFromSkeletalComponent(Person);
    const FVector Forward=GetActorForwardVector(), Right=GetActorRightVector();
    ServingPose->SetWorldLocation(Person->GetComponentLocation()+Forward*(14.f*Amount));
    FTransform Spine=ServingPose->GetBoneTransformByName(TEXT("spine_01"),EBoneSpaces::WorldSpace);
    Spine.SetRotation(FQuat(Right,FMath::DegreesToRadians(22.f*Amount))*Spine.GetRotation());
    ServingPose->SetBoneTransformByName(TEXT("spine_01"),Spine,EBoneSpaces::WorldSpace);
    FTransform Upper=ServingPose->GetBoneTransformByName(TEXT("upperarm_r"),EBoneSpaces::WorldSpace);
    FTransform Elbow=ServingPose->GetBoneTransformByName(TEXT("lowerarm_r"),EBoneSpaces::WorldSpace);
    FTransform Wrist=ServingPose->GetBoneTransformByName(TEXT("hand_r"),EBoneSpaces::WorldSpace);
    const FVector FromWrist=Forward*7.f-Right*3.f-FVector(0,0,7);
    const FVector Target=FMath::Lerp(Wrist.GetLocation(),CupBase-FromWrist,Amount);
    const FVector Bend=Elbow.GetLocation()+Right*24.f-FVector(0,0,15);
    AnimationCore::SolveTwoBoneIK(Upper,Elbow,Wrist,Bend,Target,false,1.,1.);
    ServingPose->SetBoneTransformByName(TEXT("upperarm_r"),Upper,EBoneSpaces::WorldSpace);
    ServingPose->SetBoneTransformByName(TEXT("lowerarm_r"),Elbow,EBoneSpaces::WorldSpace);
    ServingPose->SetBoneTransformByName(TEXT("hand_r"),Wrist,EBoneSpaces::WorldSpace);
    ServingPose->RefreshBoneTransforms();
    return Wrist.GetLocation()+FromWrist;
}
AAvenueCoffee::AAvenueCoffee() {
    PrimaryActorTick.bCanEverTick=true;
    Cup=CreateDefaultSubobject<UStaticMeshComponent>("Order");
    SetRootComponent(Cup);
    Cup->SetMobility(EComponentMobility::Movable);
    Cup->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Cup->SetVisibility(false);
}
void AAvenueCoffee::BeginPlay() { Super::BeginPlay(); Counter=GetActorLocation(); }
bool AAvenueCoffee::InReach(FVector Feet) const {
    if (Order==EOrder::Carried || !Barista) return false;
    const FVector Forward=Barista->GetActorForwardVector().GetSafeNormal2D();
    return FVector::DistSquared(Feet,CustomerSpot)<210.f*210.f && FVector::DotProduct(Feet-Counter,Forward)>14.f;
}
bool AAvenueCoffee::Indoors(FVector Position) const {
    if(!Barista) return false;
    const FVector D=Position-CustomerSpot, X=Barista->GetActorForwardVector(), Z(-X.Y,X.X,0);
    const float Across=(D|X)+610, Depth=(D|Z)-900;
    return Across>0 && Across<2325 && Depth> -1800 && Depth<18 && D.Z> -45 && D.Z<485;
}
void AAvenueCoffee::Use(USceneComponent* View) {
    if (Order==EOrder::Available) {
        Order=EOrder::Brewing;
        BrewTime=2.6f;
        UGameplayStatics::PlaySoundAtLocation(this,LoadObject<USoundWave>(nullptr,TEXT("/Game/Manhattan/Audio/brew.brew")),BrewStart);
    } else if (Order==EOrder::Ready && View) {
        StartGrip=GetActorTransform().GetRelativeTransform(View->GetComponentTransform());
        CarryView=View;
        Order=EOrder::Carried;
        Pickup=0;
        Cup->SetCastShadow(false);
        AttachToComponent(View,FAttachmentTransformRules::KeepWorldTransform);
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
void AAvenueCoffee::ShowHeldCup(bool Visible) {
    if(Order==EOrder::Carried) Cup->SetVisibility(Visible);
}
void AAvenueCoffee::Tick(float Dt) {
    Super::Tick(Dt);
    if (Order==EOrder::Brewing) {
        BrewTime=FMath::Max(0.f,BrewTime-Dt);
        if (BrewTime<=1.08f && Barista) {
            // Reach the cup at the work side before lifting it. Keep it in the real
            // rig's hand all the way to the customer, within this character's reach.
            Reach=FMath::SmoothStep(0.f,1.f,(1.08f-BrewTime)/.38f);
            const float Travel=FMath::SmoothStep(0.f,1.f,1.f-BrewTime/.70f);
            const FVector Goal=FMath::Lerp(BrewStart,Counter,Travel)+FVector(0,0,11*FMath::Sin(PI*Travel));
            const FVector Held=Barista->ReachFor(Goal,Reach);
            SetActorLocation(BrewTime>.7f ? BrewStart : Held);
            Cup->SetVisibility(true);
        }
        if (BrewTime==0) Order=EOrder::Ready;
    } else if (Order==EOrder::Carried) {
        if (Reach>0 && Barista) {
            Reach=FMath::Max(0.f,Reach-2.f*Dt);
            Barista->ReachFor(Counter,Reach);
        }
        if (Pickup<1 && CarryView.IsValid()) {
            Pickup=FMath::Min(1.f,Pickup+Dt/.26f);
            FTransform Pose;
            Pose.Blend(StartGrip,Grip,FMath::SmoothStep(0.f,1.f,Pickup));
            SetActorRelativeTransform(Pose);
            if (Pickup==1) Cup->SetStaticMesh(HeldModel);
        }
    }
}
