import SwiftUI

/// Small UI fallbacks for the Mac Catalyst 16 / macOS 13 community build.
extension View {
    func towerOnChange<Value: Equatable>(of value: Value, initial: Bool = false,
                                         _ action: @escaping (Value, Value) -> Void) -> some View {
        modifier(TowerChangeModifier(value: value, initial: initial, action: action))
    }

    func towerOnChange<Value: Equatable>(of value: Value, initial: Bool = false,
                                         _ action: @escaping () -> Void) -> some View {
        towerOnChange(of: value, initial: initial) { _, _ in action() }
    }

    // Mac Catalyst does not provide the iPhone Taptic Engine. Keep trigger dependencies
    // at the call sites without linking SwiftUI's iOS 17 SensoryFeedback API.
    func towerSensoryFeedback<Value: Equatable>(_ feedback: TowerFeedback, trigger: Value,
                                                condition: @escaping (Value, Value) -> Bool = { _, _ in true }) -> some View {
        self
    }

    func towerScopedAnimation<Content: View>(_ animation: Animation?,
                                             @ViewBuilder body: (Self) -> Content) -> some View {
        body(self).animation(animation)
    }
}

enum TowerFeedback { case success, selection }

private struct TowerChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                if initial { action(value, value) }
            }
            .onChange(of: value) { [oldValue = value] newValue in
                action(oldValue, newValue)
            }
    }
}

extension ContentTransition {
    static func towerNumericText(value: Double) -> ContentTransition { .opacity }
}

struct TowerEmptyState: View {
    private let label: AnyView
    private let detail: AnyView
    private let actions: AnyView

    init(_ title: LocalizedStringKey, systemImage: String, description: Text? = nil) {
        label = AnyView(Label(title, systemImage: systemImage))
        detail = AnyView(description)
        actions = AnyView(EmptyView())
    }

    init<Label: View, Description: View>(@ViewBuilder label: () -> Label,
                                        @ViewBuilder description: () -> Description) {
        self.label = AnyView(label())
        detail = AnyView(description())
        actions = AnyView(EmptyView())
    }

    init<Label: View, Description: View, Actions: View>(@ViewBuilder label: () -> Label,
                                                       @ViewBuilder description: () -> Description,
                                                       @ViewBuilder actions: () -> Actions) {
        self.label = AnyView(label())
        detail = AnyView(description())
        self.actions = AnyView(actions())
    }

    static func search(text: String) -> some View {
        TowerEmptyState("没有搜索结果", systemImage: "magnifyingglass", description: Text(verbatim: text))
    }

    var body: some View {
        VStack(spacing: 12) {
            label.font(.title3.weight(.semibold))
            detail.font(.subheadline).foregroundStyle(.secondary)
            actions
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum TowerAnimationCompletionCriteria { case removed }

/// Original call sites carry generation tokens, so delayed completions cannot
/// finish a newer drag. Ventura lacks SwiftUI's animation-completion transaction.
@MainActor
func towerWithAnimation<Result>(_ animation: Animation? = .default,
                                 completionCriteria: TowerAnimationCompletionCriteria,
                                 _ body: () throws -> Result,
                                 completion: @escaping () -> Void) rethrows -> Result {
    if #available(iOS 17.0, macCatalyst 17.0, *) {
        return try withAnimation(animation, completionCriteria: .removed, body, completion: completion)
    }
    let result = try withAnimation(animation, body)
    DispatchQueue.main.asyncAfter(deadline: .now() + (animation == nil ? 0 : 0.8), execute: completion)
    return result
}


enum TowerBuild {
    static var supportsCloudSync: Bool {
        #if TOWER_COMMUNITY_BUILD
        false
        #else
        true
        #endif
    }
}
