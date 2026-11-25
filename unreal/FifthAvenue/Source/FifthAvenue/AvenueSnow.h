#pragma once
#include "Components/ActorComponent.h"
#include "AvenueSnow.generated.h"

class UMaterialInstanceDynamic;
class UTexture2D;

UCLASS()
class UAvenueSnow : public UActorComponent
{
    GENERATED_BODY()
public:
    void Initialize(UMaterialInstanceDynamic* Ground);
    float Coverage(FVector Foot) const;
    void Footprint(FVector Foot, FVector Heading, bool Left);
    void Tire(int Index, FVector Contact, bool Grounded);
    void Update(FVector Observer, float Delta);
private:
    static constexpr int TileSize=320, Slots=8;
    struct FTile { TArray<uint8> Pixels; FIntRect Dirty{0,0,0,0}; };
    TMap<FIntPoint,FTile> Tracks;
    TArray<uint8> Samples;
    FIntPoint FieldSize,DriftSize,RoadSize;
    TOptional<FIntPoint> First;
    bool UsedSlot[Slots*Slots]={};
    TOptional<FVector2D> LastTire[4];
    float UntilUpload=0;
    UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> Material;
    UPROPERTY() TObjectPtr<UTexture2D> Atlas;
    static FVector2D Street(FVector World);
    float Depth(FVector2D P) const;
    void Press(int X,int Y,uint8 Value);
    void Upload(FIntPoint Key,FIntRect Rect);
};
