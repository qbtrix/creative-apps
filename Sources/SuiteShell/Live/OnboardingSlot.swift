// OnboardingSlot.swift: the `onboarding` member of SuiteServices.live. Live
// (onboarding OB-12): SuiteOnboarding, the tour's pages, when it shows
// (onboardingDoneVersion below the current version) and the home order a
// focus gives. Pure, so it needs nothing from the slot context.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let onboardingIsLive = true

func onboardingSlot(_ c: SlotContext) -> any OnboardingFlowing {
    SuiteOnboarding()
}
