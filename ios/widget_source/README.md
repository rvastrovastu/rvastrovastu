# Today's Panchang widget: one-time iOS setup

Android needs nothing more; the widget ships with the app. iOS widgets are
an app extension that has to be added once in Xcode.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File > New > Target > **Widget Extension**. Product name: `TodayWidget`.
   Untick "Include Live Activity", "Include Control" and "Include
   Configuration App Intent". Click Finish, then **Don't Activate** when
   asked about the scheme.
3. Replace the contents of the generated `TodayWidget/TodayWidget.swift`
   with `ios/widget_source/TodayWidget.swift`, and
   `TodayWidget/TodayWidgetBundle.swift` with
   `ios/widget_source/TodayWidgetBundle.swift`. Delete any generated
   `TodayWidgetLiveActivity.swift` or `TodayWidgetControl.swift`.
4. App Group (needs the paid developer account):
   - Select the **Runner** target > Signing & Capabilities > + Capability >
     App Groups > + > `group.com.rvastrovastu.rvAstroVastu`.
   - Select the **TodayWidget** target and add the same App Group.
5. TodayWidget target > General > Minimum Deployments: iOS 15.0 or later
   (the app's own minimum if higher).
6. If the build fails with a "Cycle inside Runner" error about "Thin
   Binary": Runner target > Build Phases, drag **Embed Foundation
   Extensions** above **Thin Binary**.
7. Run the app once, then long-press the home screen > + > RV Astro Vastu >
   Today's Panchang.

The app refreshes the widget every time it opens or comes back to the
foreground, writing a week ahead.
