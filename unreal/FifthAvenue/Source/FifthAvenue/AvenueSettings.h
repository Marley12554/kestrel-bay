#pragma once

#include "Widgets/SCompoundWidget.h"

class AAvenueWalker;

class SAvenueSettings : public SCompoundWidget
{
public:
    SLATE_BEGIN_ARGS(SAvenueSettings) {}
        SLATE_ARGUMENT(TWeakObjectPtr<AAvenueWalker>, Walker)
    SLATE_END_ARGS()

    void Construct(const FArguments& Args);
    virtual bool SupportsKeyboardFocus() const override { return true; }
    virtual FReply OnMouseButtonDown(const FGeometry& Geometry, const FPointerEvent& Event) override;
    virtual FReply OnPreviewKeyDown(const FGeometry& Geometry, const FKeyEvent& Event) override;
    void CommitQuality();

private:
    TWeakObjectPtr<AAvenueWalker> Walker;
    int32 PendingQuality = 0;
    bool DraggingQuality = false;
};
