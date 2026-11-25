#pragma once

#include "GameFramework/CharacterMovementComponent.h"
#include "AvenueWalkMovement.generated.h"

UCLASS()
class UAvenueWalkMovement : public UCharacterMovementComponent
{
    GENERATED_BODY()

    virtual FVector ConsumeInputVector() override;
    virtual void CalcVelocity(float DeltaTime, float Friction, bool Fluid, float BrakingDeceleration) override;
};
