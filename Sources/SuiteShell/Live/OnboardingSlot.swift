// OnboardingSlot.swift: the `onboarding` member of SuiteServices.live. Pure,
// so until the onboarding feature connects it the slot holds the reference fake.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let onboardingIsLive = false

func onboardingSlot(_ c: SlotContext) -> any OnboardingFlowing {
    FakeOnboarding()
}
