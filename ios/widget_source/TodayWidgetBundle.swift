// Replace the TodayWidgetBundle.swift that Xcode creates with this, so the
// extension ships only the Panchang widget (no Live Activity or Control).

import SwiftUI
import WidgetKit

@main
struct TodayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
