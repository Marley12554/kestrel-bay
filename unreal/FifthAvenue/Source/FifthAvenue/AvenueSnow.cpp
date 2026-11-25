#include "AvenueSnow.h"
#include "Engine/Texture2D.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Misc/Compression.h"
#include "Misc/FileHelper.h"
#include "Serialization/MemoryReader.h"

namespace {
int Wrap(int N,int Size) { return (N%Size+Size)%Size; }
float ByteAt(const TArray<uint8>& Data,int Offset,FIntPoint Size,FVector2D UV,bool Repeat) {
    const int X=FMath::FloorToInt(UV.X), Y=FMath::FloorToInt(UV.Y);
    auto Sample=[&](int I,int J) {
        I=Repeat?Wrap(I,Size.X):FMath::Clamp(I,0,Size.X-1);
        J=Repeat?Wrap(J,Size.Y):FMath::Clamp(J,0,Size.Y-1);
        return float(Data[Offset+J*Size.X+I]);
    };
    return FMath::BiLerp(Sample(X,Y),Sample(X+1,Y),Sample(X,Y+1),Sample(X+1,Y+1),float(UV.X-X),float(UV.Y-Y));
}
}
FVector2D UAvenueSnow::Street(FVector Pos) {
    const FVector Delta=Pos*.01-FVector(-208.099,573.891,0);
    return {Delta.X*.873+Delta.Y*.488,-Delta.X*.488+Delta.Y*.873};
}
void UAvenueSnow::Initialize(UMaterialInstanceDynamic* Ground) {
    TArray<uint8> File;
    if (!FFileHelper::LoadFileToArray(File,*(FPaths::ProjectContentDir()/TEXT("StreetData/FifthGround.bin"))) || File.Num()<=24) {
        UE_LOG(LogTemp,Error,TEXT("Missing snow and street samples")); return;
    }
    FMemoryReader Read(File);
    Read<<FieldSize<<DriftSize<<RoadSize;
    if (FieldSize!=FIntPoint(1600,832) || DriftSize!=FIntPoint(512,512) || RoadSize!=FIntPoint(2700,3000)) {
        UE_LOG(LogTemp,Error,TEXT("Invalid street sample dimensions: %s %s %s"),*FieldSize.ToString(),*DriftSize.ToString(),*RoadSize.ToString()); return;
    }
    Samples.SetNumUninitialized(FieldSize.X*FieldSize.Y+DriftSize.X*DriftSize.Y+RoadSize.X*RoadSize.Y);
    if (!FCompression::UncompressMemory(NAME_Zlib,Samples.GetData(),Samples.Num(),File.GetData()+24,File.Num()-24)) {
        Samples.Reset(); UE_LOG(LogTemp,Error,TEXT("Unreadable snow field")); return;
    }
    Material=Ground;
    if (!Ground) return;
    TArray64<uint8> Zero;
    Zero.SetNumZeroed(Slots*TileSize*Slots*TileSize);
    Atlas=UTexture2D::CreateTransient(Slots*TileSize,Slots*TileSize,PF_G8,NAME_None,Zero);
    Atlas->SRGB=false; Atlas->Filter=TF_Bilinear;
    Atlas->UpdateResource();
    Material->SetTextureParameterValue(TEXT("Pressure"),Atlas);
}
float UAvenueSnow::Depth(FVector2D P) const {
    if (Samples.IsEmpty() || P.X< -240 || P.X>=160 || P.Y< -136 || P.Y>=72) return 0;
    const float Byte=ByteAt(Samples,0,FieldSize,(P+FVector2D(240,136))*4.-FVector2D(.5,.5),false);
    return FMath::Max(0.f,(Byte-1.f)*(.36f/254.f));
}
float UAvenueSnow::Coverage(FVector Foot) const {
    if (Samples.IsEmpty()) return 0;
    const FVector2D P=Street(Foot);
    if (P.X>=-240 && P.X<160 && P.Y>=-136 && P.Y<72) {
        const float Fresh=Depth(P);
        const FIntPoint Key(FMath::FloorToInt(P.X/8),FMath::FloorToInt(P.Y/8));
        const FTile* Tile=Tracks.Find(Key);
        float Remaining=Fresh;
        if(Tile) {
            const int X=Wrap(FMath::FloorToInt(P.X*40),TileSize),Y=Wrap(FMath::FloorToInt(P.Y*40),TileSize);
            Remaining-=FMath::Min(Fresh*.94f,Tile->Pixels[Y*TileSize+X]*(.36f/255.f));
        }
        return FMath::SmoothStep(.003f,.033f,Remaining);
    }
    const int Drifts=FieldSize.X*FieldSize.Y;
    const float Drift=ByteAt(Samples,Drifts,DriftSize,P*(DriftSize.X/64.)-FVector2D(.5,.5),true)/255.f;
    const int X=1350+FMath::FloorToInt(Foot.X*.01),Y=1500+FMath::FloorToInt(Foot.Y*.01);
    const bool Road=X>=0 && Y>=0 && X<RoadSize.X && Y<RoadSize.Y && Samples[Drifts+DriftSize.X*DriftSize.Y+Y*RoadSize.X+X];
    if (!Road) return FMath::SmoothStep(.17f,.47f,Drift);
    const double Lateral=FMath::Abs(P.X-81)<9?P.X:P.Y+45.8;
    const double Lane=(Lateral+.12*FMath::Sin(P.Y*.07+P.X*.09))/3.85;
    const double Wheel=FMath::Abs((Lane-FMath::FloorToDouble(Lane))*3.85-1.925);
    return FMath::SmoothStep(.57f,.83f,Drift-.27f*(1-FMath::SmoothStep(.14f,.53f,float(FMath::Abs(Wheel-.78)))));
}
void UAvenueSnow::Press(int X,int Y,uint8 Value) {
    if(!Value) return;
    const FIntPoint Key(FMath::FloorToInt(double(X)/TileSize),FMath::FloorToInt(double(Y)/TileSize));
    FTile& Tile=Tracks.FindOrAdd(Key);
    if(Tile.Pixels.IsEmpty()) Tile.Pixels.SetNumZeroed(TileSize*TileSize);
    const FIntPoint Local(Wrap(X,TileSize),Wrap(Y,TileSize));
    uint8& Pixel=Tile.Pixels[Local.Y*TileSize+Local.X];
    if (Pixel>=Value) return;
    Pixel=Value;
    const FIntRect Bounds(Local,Local+FIntPoint(1,1));
    if(Tile.Dirty.IsEmpty()) Tile.Dirty=Bounds; else Tile.Dirty.Union(Bounds);
}
void UAvenueSnow::Footprint(FVector Foot,FVector Heading,bool Left) {
    const FVector2D F=(Street(Foot+Heading*100)-Street(Foot)).GetSafeNormal();
    if (F.IsNearlyZero()) return;
    const FVector2D S(-F.Y,F.X), P=Street(Foot)+S*(Left?-.103:.103);
    if (Depth(P)<.003) return;
    for(int Y=FMath::FloorToInt(40*P.Y)-8;Y<=FMath::CeilToInt(40*P.Y)+8;++Y)
        for(int X=FMath::FloorToInt(40*P.X)-8;X<=FMath::CeilToInt(40*P.X)+8;++X) {
            const FVector2D D=FVector2D(X+.5,Y+.5)/40.-P;
            const double A=(D|S)*(Left?1:-1), B=D|F;
            const double Sole=FMath::Min3(FVector2D((A+.006)/.054,(B-.062)/.096).Size(),
                FVector2D(A/.043,(B+.095)/.057).Size(),FVector2D((A-.020)/.029,(B+.018)/.075).Size());
            Press(X,Y,FMath::RoundToInt(62*(1-FMath::SmoothStep(.66,1.13,Sole))));
        }
}
void UAvenueSnow::Tire(int Index,FVector Contact,bool Grounded) {
    if (!Grounded) { LastTire[Index].Reset(); return; }
    const FVector2D End=Street(Contact), Start=LastTire[Index].Get(End), Delta=End-Start;
    if (Delta.Size()<.035) { if(!LastTire[Index]) LastTire[Index]=End; return; }
    LastTire[Index]=End;
    if (Delta.Size()>4. || (Depth(End)<.002 && Depth(Start)<.002)) return;
    const FVector2D Forward=Delta.GetSafeNormal(), Side(-Forward.Y,Forward.X);
    for(double T=0;T<=Delta.Size()+.015;T+=.025) {
        const FVector2D Center=Start+Forward*T;
        for(int I=-5;I<=5;++I) {
            const FVector2D At=(Center+Side*(I*.024))*40;
            const int Tread=Wrap(FMath::FloorToInt((Center|Forward)*22)+FMath::Abs(I),5);
            Press(FMath::FloorToInt(At.X),FMath::FloorToInt(At.Y),FMath::Abs(I)==5?32:Tread==0?62:125);
        }
    }
}
void UAvenueSnow::Upload(FIntPoint Key,FIntRect Rect) {
    const FTile* Tile=Tracks.Find(Key);
    const int W=Rect.Width(),H=Rect.Height();
    uint8* Data=new uint8[W*H];
    for(int Y=0;Y<H;++Y) {
        if(Tile) FMemory::Memcpy(Data+Y*W,Tile->Pixels.GetData()+(Rect.Min.Y+Y)*TileSize+Rect.Min.X,W);
        else FMemory::Memzero(Data+Y*W,W);
    }
    auto* Region=new FUpdateTextureRegion2D(Wrap(Key.X,Slots)*TileSize+Rect.Min.X,Wrap(Key.Y,Slots)*TileSize+Rect.Min.Y,0,0,W,H);
    Atlas->UpdateTextureRegions(0,1,Region,W,1,Data,[](uint8* Bytes,const FUpdateTextureRegion2D* R){delete[] Bytes;delete R;});
}
void UAvenueSnow::Update(FVector Observer,float Delta) {
    if(!Atlas || !Material) return;
    UntilUpload-=Delta;
    if(UntilUpload>0) return;
    UntilUpload=.066f;
    const FVector2D P=Street(Observer);
    const FIntPoint Start(FMath::FloorToInt(P.X/8)-Slots/2,FMath::FloorToInt(P.Y/8)-Slots/2);
    for(int Y=Start.Y;Y<Start.Y+Slots;++Y) for(int X=Start.X;X<Start.X+Slots;++X) {
        const FIntPoint Key(X,Y);
        FTile* Tile=Tracks.Find(Key);
        const int Slot=Wrap(Y,Slots)*Slots+Wrap(X,Slots);
        if(First && (X<First->X || Y<First->Y || X>=First->X+Slots || Y>=First->Y+Slots)) {
            // The incoming and outgoing tiles usually both contain untouched snow.
            if(Tile || UsedSlot[Slot]) Upload(Key,{0,0,TileSize,TileSize});
        }
        else if (Tile && !Tile->Dirty.IsEmpty()) Upload(Key,Tile->Dirty);
        UsedSlot[Slot]=Tile!=nullptr;
        if(Tile) Tile->Dirty={0,0,0,0};
    }
    if (!First || First.GetValue()!=Start) Material->SetVectorParameterValue(TEXT("TrackOrigin"),FLinearColor(Start.X*8,Start.Y*8,0));
    First=Start;
}
