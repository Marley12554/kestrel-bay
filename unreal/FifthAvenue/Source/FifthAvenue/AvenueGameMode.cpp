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
#include "Engine/StaticMesh.h"
#include "EngineUtils.h"
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
    Chassis->SetBoxExtent(FVector(226,98,57));
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
    const TCHAR* Names[]={TEXT("tesla_forward"),TEXT("tesla_reverse"),TEXT("sedan_road"),TEXT("tire_scuff")};
    for(const TCHAR* Name:Names) {
        auto* Audio=CreateDefaultSubobject<UAudioComponent>(Name);
        Audio->SetupAttachment(Chassis);
        Audio->bAutoActivate=false;
        AudioLayers.Add(Audio);
    }
}
void AAvenueCar::BeginPlay() {
    Super::BeginPlay();
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
}
void AAvenueCar::Drive(float Delta,float Throttle,float InputSteer,bool Handbrake) {
    const float Dt=FMath::Min(Delta,.05f);
    if (!Exterior->GetStaticMesh()) {
        Exterior->SetStaticMesh(LoadObject<UStaticMesh>(nullptr,TEXT("/Game/Manhattan/Street/Sedan/StaticMeshes/Sedan.Sedan")));
    }
    const FVector Up=FVector::UpVector;
    const FVector Facing=GetActorForwardVector().GetSafeNormal2D();
    FHitResult Floor;
    const FVector Center=GetActorLocation();
    const bool HasFloor=FloorAt(GetWorld(),Center+Up*30,Center-Up*100,Floor,this);
    const bool Grounded=HasFloor && Center.Z-Floor.ImpactPoint.Z<76 && VerticalSpeed<220;
    const float Longitudinal=FVector::DotProduct(VelocityXY,Facing);
    const float Lateral=FVector::DotProduct(VelocityXY,GetActorRightVector());
    if(Grounded) {
        const bool Braking=Throttle*Longitudinal < -15;
        const float Accel=Braking?1400.f:(Throttle<0?370.f:680.f);
        VelocityXY+=Facing*Throttle*Accel*Dt;
        const float Drag=55+.000022f*VelocityXY.SizeSquared()+(Handbrake?460:0);
        VelocityXY=FMath::VInterpConstantTo(VelocityXY,FVector::ZeroVector,Dt,Drag);
        VelocityXY-=GetActorRightVector()*Lateral*(1-FMath::Exp(-(Handbrake?1.15f:7.5f)*Dt));
        VelocityXY=VelocityXY.GetClampedToMaxSize(Longitudinal<0 && !Braking?550:5811);
        Steering=FMath::FInterpTo(Steering,InputSteer,Dt,7);
        const float Desired=Steering*FMath::Clamp(Longitudinal/450.f,-1.f,1.f)*(Handbrake?113:62);
        YawRate=FMath::FInterpConstantTo(YawRate,Desired,Dt,Handbrake?165:235);
        AddActorWorldRotation(FRotator(0,YawRate*Dt,0));
        VerticalSpeed=FMath::Clamp(-FVector::DotProduct(Floor.ImpactNormal,VelocityXY)/FMath::Max(.25f,Floor.ImpactNormal.Z),-2200,2200);
    } else VerticalSpeed-=980*Dt;
    FHitResult Block;
    FVector Travel=VelocityXY*Dt+Up*(VerticalSpeed*Dt);
    if(Grounded) Travel.Z+=FMath::Clamp(Floor.ImpactPoint.Z+62-Center.Z,-6.f,9.f);
    AddActorWorldOffset(Travel,true,&Block);
    if(Block.bBlockingHit) {
        if(Block.Normal.Z<.5f) VelocityXY=FVector::VectorPlaneProject(VelocityXY,Block.Normal)*.67;
        else VerticalSpeed=FMath::Max(0.f,VerticalSpeed);
    }
    if(Grounded) {
        const FRotator Grade=FRotationMatrix::MakeFromXZ(GetActorForwardVector().GetSafeNormal2D(),Floor.ImpactNormal).Rotator();
        SetActorRotation(FMath::RInterpTo(GetActorRotation(),Grade,Dt,6));
    }
    Spin=FMath::Fmod(Spin+FMath::RadiansToDegrees(Longitudinal*Dt/33.5f),360.f);
    for(int i=0;i<Wheels.Num();++i) {
        FHitResult Road;
        const FVector Hub=Exterior->GetComponentTransform().TransformPosition(Hubs[i]);
        const bool Contact=FloorAt(GetWorld(),Hub+Up*18,Hub-Up*47,Road,this);
        const float TravelZ=Contact?FMath::Clamp<float>(Road.ImpactPoint.Z+34-Hub.Z,-8,7):-8;
        Wheels[i]->SetRelativeLocation(Hubs[i]+Up*TravelZ);
        Wheels[i]->SetRelativeRotation(FRotator(0,i<2?Steering*23.f:0.f,-Spin));
    }
    const float Speed01=FMath::Clamp(VelocityXY.Size()/2500.f,0.f,1.f);
    const float Gain[]={Longitudinal>=0?FMath::Clamp(1-Speed01*2,0.f,1.f)*FMath::Clamp(Speed01*24,0.f,1.f):0,
        Longitudinal<-12?.68f:0.f,Grounded?Speed01*.85f:Speed01*.12f,
        Grounded?FMath::Clamp((FMath::Abs(Lateral)-120)/650.f,0.f,1.f)*.7f:0.f};
    for(int i=0;i<AudioLayers.Num();++i) {
        UAudioComponent* Audio=AudioLayers[i];
        if(!Audio->Sound) {
            if(auto* Wave=Recording(Audio->GetName())) { Wave->bLooping=true; Audio->SetSound(Wave); }
        }
        Audio->SetVolumeMultiplier(FMath::Max(.0001f,Gain[i]));
        Audio->SetPitchMultiplier(i==1?.82f+FMath::Min(FMath::Abs(Longitudinal)/550.f,1.f)*.8f:.83f+Speed01*.48f);
        if(Gain[i]>.001f && !Audio->IsPlaying()) Audio->Play();
    }
    if(SignalSide && (SignalClock-=Dt)<=0) {
        UGameplayStatics::PlaySound2D(this,Recording("turn_signal"),.8f);
        SignalClock=.69f;
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
    auto* Movement=GetCharacterMovement();
    Movement->MaxAcceleration=5400;
    Movement->BrakingDecelerationWalking=5000;
    Movement->GroundFriction=12;
    Movement->AirControl=.62f;
    Movement->JumpZVelocity=465;
}
void AAvenueWalker::BeginPlay() {
    Super::BeginPlay();
    auto* Settings=GEngine->GetGameUserSettings();
    if(!GConfig->GetInt(TEXT("FifthAvenue"),TEXT("Quality"),Quality,GGameUserSettingsIni)) Quality=0;
    if(Settings) ChangeQuality(Quality);
    Bench=FParse::Param(FCommandLine::Get(),TEXT("AvenueBench"));
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
void AAvenueWalker::ChangeQuality(int NewQuality) {
    Quality=FMath::Clamp(NewQuality,0,3);
    if(auto* S=GEngine->GetGameUserSettings()) {
        S->SetOverallScalabilityLevel(Quality);
        S->SetShadowQuality(FMath::Max(1,Quality));
        S->SetTextureQuality(FMath::Max(2,Quality));
        S->SetResolutionScaleValueEx(72.f+Quality*(28.f/3.f));
        S->ApplyNonResolutionSettings();
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
void AAvenueWalker::LookYaw(float V) { if(!MenuOpen) AddControllerYawInput(V); }
void AAvenueWalker::LookPitch(float V) { if(!MenuOpen) AddControllerPitchInput(V); }
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
    if(Bench) Benchmark(Dt);
    if(MenuOpen) return;
    if(Driven) {
        Driven->Drive(Dt,Forward,Side,Sprint);
        const FVector Target=Driven->GetActorLocation()+FVector(0,0,85);
        const FVector Desired=Target-GetControlRotation().Vector()*540+FVector(0,0,100);
        FHitResult Wall;
        const bool Hit=FloorAt(GetWorld(),Target,Desired,Wall,Driven);
        Camera->SetWorldLocation(Hit?Wall.ImpactPoint+Wall.ImpactNormal*12:Desired);
        Camera->SetWorldRotation((Target-Camera->GetComponentLocation()).Rotation());
    } else {
        GetCharacterMovement()->MaxWalkSpeed=Sprint?620:225;
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
        Controller->SetControlRotation(Driven->GetActorRotation());
        break;
    }
}
void AAvenueWalker::ToggleFlight() {
    if(!Driven) GetCharacterMovement()->SetMovementMode(GetCharacterMovement()->IsFlying()?MOVE_Walking:MOVE_Flying);
}
void AAvenueWalker::LookAtHerald() {
    if(Driven) return;
    const FVector P(-39100,34100,0);
    FHitResult Floor;
    if(FloorAt(GetWorld(),P+FVector(0,0,4000),P-FVector(0,0,2000),Floor,this))
        SetActorLocation(Floor.ImpactPoint+FVector(0,0,95));
    Controller->SetControlRotation(FRotator(12,-49,0));
}
void AAvenueWalker::ToggleDay() {
    Night=!Night;
    TArray<AActor*> Moons;
    UGameplayStatics::GetAllActorsWithTag(this,TEXT("Moon"),Moons);
    for(AActor* Moon:Moons) Moon->SetActorHiddenInGame(!Night);
    for(TActorIterator<ADirectionalLight> It(GetWorld());It;++It) {
        auto* L=CastChecked<UDirectionalLightComponent>(It->GetLightComponent());
        L->SetIntensity(Night?.18f:6500.f);
        L->SetLightColor(Night?FLinearColor(.40f,.48f,.68f):FLinearColor(1,.90f,.79f));
    }
    for(TActorIterator<ASkyLight> It(GetWorld());It;++It) It->GetLightComponent()->SetIntensity(Night?.08f:.85f);
}
void AAvenueWalker::ToggleMenu() {
    MenuOpen=!MenuOpen;
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
        DrawRect(FLinearColor(.02,.025,.03,.96),X-24,Y-65,368,145);
        DrawText(TEXT("Graphics quality"),FLinearColor::White,X,Y-45);
        DrawRect(FLinearColor(.25,.27,.3),X,Y,320,8);
        DrawRect(FLinearColor(.8,.84,.92),X+P->Quality*104,Y-6,10,20);
        DrawText(TEXT("Low                   Medium                 High                  Ultra"),FLinearColor::White,X,Y+22);
        float MX,MY;
        if(PlayerOwner->IsInputKeyDown(EKeys::LeftMouseButton)&&PlayerOwner->GetMousePosition(MX,MY)&&FMath::Abs(MY-Y)<24&&MX>=X-4&&MX<=X+324) {
            int Level=FMath::Clamp(FMath::RoundToInt((MX-X)*3/320),0,3);
            if(Level!=P->Quality) P->ChangeQuality(Level);
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
