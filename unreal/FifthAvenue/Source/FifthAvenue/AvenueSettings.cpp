#include "AvenueSettings.h"
#include "AvenueGameMode.h"
#include "InputCoreTypes.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Input/SSlider.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/Text/STextBlock.h"

void SAvenueSettings::Construct(const FArguments& Args)
{
    Walker = Args._Walker;
    PendingQuality = Walker->Quality;
    const float Min = AAvenueWalker::MinLookSensitivity;
    const float Range = AAvenueWalker::MaxLookSensitivity / Min;

    ChildSlot.HAlign(HAlign_Center).VAlign(VAlign_Center)
    [
        SNew(SBorder)
        .BorderImage(FCoreStyle::Get().GetBrush("WhiteBrush"))
        .BorderBackgroundColor(FLinearColor(.025f, .03f, .04f, .96f))
        .Padding(24)
        [
            SNew(SBox).WidthOverride(320)
            [
                SNew(SVerticalBox)
                + SVerticalBox::Slot().AutoHeight().Padding(0, 0, 0, 8)
                [
                    SNew(STextBlock).Text_Lambda([this] {
                        static const TCHAR* Labels[] = {TEXT("Low"), TEXT("Medium"), TEXT("High"), TEXT("Ultra")};
                        return FText::Format(NSLOCTEXT("FifthAvenue", "Quality", "Graphics quality   {0}"),
                            FText::FromString(Labels[PendingQuality]));
                    })
                ]
                + SVerticalBox::Slot().AutoHeight()
                [
                    SNew(SBox).HeightOverride(32)
                    [
                        SNew(SSlider)
                        .MinValue(0).MaxValue(3).StepSize(1).MouseUsesStep(true)
                        .RequiresControllerLock(false).PreventThrottling(true)
                        .Value_Lambda([this] { return static_cast<float>(PendingQuality); })
                        .OnMouseCaptureBegin_Lambda([this] { DraggingQuality = true; })
                        .OnValueChanged_Lambda([this](float Value) {
                            PendingQuality = FMath::Clamp(FMath::RoundToInt(Value), 0, 3);
                            if (!DraggingQuality) CommitQuality();
                        })
                        .OnMouseCaptureEnd_Lambda([this] { DraggingQuality = false; CommitQuality(); })
                    ]
                ]
                + SVerticalBox::Slot().AutoHeight().Padding(0, 20, 0, 8)
                [
                    SNew(STextBlock).Text_Lambda([this] {
                        const float Scale = Walker.IsValid() ? Walker->LookSensitivity : 1.f;
                        return FText::Format(NSLOCTEXT("FifthAvenue", "Sensitivity", "Mouse sensitivity   {0}%"),
                            FMath::RoundToInt(100.f * Scale));
                    })
                ]
                + SVerticalBox::Slot().AutoHeight()
                [
                    SNew(SBox).HeightOverride(32)
                    [
                        SNew(SSlider)
                        .Tag(TEXT("AvenueSensitivity")).RequiresControllerLock(false).PreventThrottling(true)
                        .Value_Lambda([this, Min, Range] {
                            const float Scale = Walker.IsValid() ? Walker->LookSensitivity : 1.f;
                            return FMath::Loge(Scale / Min) / FMath::Loge(Range);
                        })
                        .OnValueChanged_Lambda([this, Min, Range](float Position) {
                            if (Walker.IsValid()) Walker->SetLookSensitivity(Min * FMath::Pow(Range, Position));
                        })
                        .OnMouseCaptureEnd_Lambda([] { GConfig->Flush(false, GGameUserSettingsIni); })
                    ]
                ]
            ]
        ]
    ];
}

FReply SAvenueSettings::OnMouseButtonDown(const FGeometry& Geometry, const FPointerEvent& Event)
{
    return FReply::Handled().SetUserFocus(SharedThis(this), EFocusCause::Mouse);
}

FReply SAvenueSettings::OnPreviewKeyDown(const FGeometry& Geometry, const FKeyEvent& Event)
{
    if (Event.GetKey() == EKeys::Escape && Walker.IsValid())
    {
        if (!Event.IsRepeat()) Walker->ToggleMenu();
        return FReply::Handled();
    }
    return SCompoundWidget::OnPreviewKeyDown(Geometry, Event);
}

void SAvenueSettings::CommitQuality()
{
    if (Walker.IsValid() && Walker->Quality != PendingQuality) Walker->ChangeQuality(PendingQuality);
}
