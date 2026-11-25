#include "AvenueWalkMovement.h"
#include "AvenueGameMode.h"

FVector UAvenueWalkMovement::ConsumeInputVector()
{
    // The controller has processed both mouse axes for this frame by the time
    // character movement consumes WASD. Turning and strafing use the same view.
    if (auto* Walker = Cast<AAvenueWalker>(PawnOwner))
        Walker->QueueWalkInput();
    return Super::ConsumeInputVector();
}

void UAvenueWalkMovement::CalcVelocity(float DeltaTime, float Friction, bool Fluid, float BrakingDeceleration)
{
    if (IsMovingOnGround() && CharacterOwner && CharacterOwner->IsLocallyControlled()
        && !HasAnimRootMotion() && !CurrentRootMotion.HasOverrideVelocity())
    {
        // A planted player can stop or redirect on the next movement step.
        // PhysWalking still sweeps the capsule, follows slopes and handles stairs.
        Velocity = Acceleration.GetSafeNormal2D() * (GetMaxSpeed() * GetAnalogInputModifier());
        return;
    }
    Super::CalcVelocity(DeltaTime, Friction, Fluid, BrakingDeceleration);
}
