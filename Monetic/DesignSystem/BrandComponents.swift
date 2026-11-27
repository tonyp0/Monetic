import SwiftUI
import UIKit

// MARK: - Background

/// The app's base layer: flat warm paper (or warm ink in dark mode).
struct BrandBackground: View {
    var body: some View {
        Brand.background.ignoresSafeArea()
    }
}

// MARK: - Cards

private struct BrandCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat
    var radius: CGFloat
    var raised: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(raised ? Brand.surfaceRaised : Brand.surface)
            )
            // Depth comes from colour steps; a hairline only where they're too close (dark).
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                }
            }
    }
}

extension View {
    func brandCard(
        padding: CGFloat = Brand.Space.l,
        radius: CGFloat = Brand.Radius.large,
        raised: Bool = false
    ) -> some View {
        modifier(BrandCardModifier(padding: padding, radius: radius, raised: raised))
    }

    /// A sentence-case label in `.subheadline` / `textSecondary`.
    @available(*, deprecated, message: "Drop the label if context makes it obvious; otherwise use .font(.subheadline) in textSecondary")
    func brandEyebrow() -> some View {
        brandLabel()
    }

    /// The one label style: sentence case, `.subheadline`, `textSecondary`.
    func brandLabel() -> some View {
        self
            .font(.subheadline)
            .foregroundStyle(Brand.textSecondary)
    }

    /// Screens that need swipe-to-delete or drag-to-reorder are a `List`;
    /// this strips the stock row chrome so they don't look like one.
    func brandListRow(vertical: CGFloat = 0) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: vertical,
                leading: Brand.Space.gutter,
                bottom: vertical,
                trailing: Brand.Space.gutter
            ))
    }
}

// MARK: - Buttons

/// The primary call to action: solid accent, one per screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration)
    }

    // `@Environment` is only installed on a View, never on the style itself,
    // so the label is wrapped in one to read `isEnabled` correctly. The name
    // avoids `Body`, which ButtonStyle already declares as an associated type.
    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(isEnabled ? Brand.onAccent : Brand.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                        .fill(isEnabled ? Brand.accent : Brand.track)
                )
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

@available(*, deprecated, renamed: "PrimaryButtonStyle")
typealias GradientButtonStyle = PrimaryButtonStyle

/// Destructive action at the foot of a screen ("Delete Trip"): same shape,
/// tinted with the danger colour instead of filled.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Brand.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                    .fill(Brand.danger.opacity(0.10))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet secondary action: amber text on a faint amber wash.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SoftBody(configuration: configuration)
    }

    private struct SoftBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(Brand.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                        .fill(Brand.accent.opacity(0.14))
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

// MARK: - Progress

/// The budget's progress: one horizontal bar, either a single fraction
/// coloured by status or split into coloured segments (one per group).
/// When spending passes the budget the bar fills in `danger`; the caller
/// shows how far over in words.
struct BudgetBar: View {
    struct Segment {
        let color: Color
        let amount: Double
    }

    /// How much of the budget is used; above 1 means over budget.
    let fraction: Double
    private let segments: [Segment]
    private let tint: Color?
    var height: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A single fraction of the budget (0.62 = 62% used).
    init(fraction: Double, height: CGFloat = 10) {
        self.init(fraction: fraction, tint: nil, height: height)
    }

    /// Spending split by group: each segment's `amount` is measured against `total`.
    init(segments: [Segment], total: Double, height: CGFloat = 10) {
        let spent = segments.reduce(0) { $0 + max($1.amount, 0) }
        self.fraction = total > 0 ? spent / total : (spent > 0 ? 2 : 0)
        self.segments = total > 0 ? segments.filter { $0.amount > 0 } : []
        self.tint = nil
        self.height = height
    }

    /// For `BrandProgressBar`: a single fraction in a caller-chosen colour.
    fileprivate init(fraction: Double, tint: Color?, height: CGFloat) {
        self.fraction = fraction
        self.segments = []
        self.tint = tint
        self.height = height
    }

    var isOver: Bool { fraction > 1 }

    private var statusColor: Color {
        if let tint { return tint }
        if isOver { return Brand.danger }
        return fraction >= 0.8 ? Brand.warning : Brand.positive
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.track)
                fills(width: geo.size.width)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .animation(reduceMotion ? nil : .smooth, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Budget")
        .accessibilityValue("\(Int((fraction * 100).rounded()))% of budget used")
    }

    @ViewBuilder
    private func fills(width: CGFloat) -> some View {
        if segments.isEmpty || isOver {
            Capsule()
                .fill(statusColor)
                .frame(width: fillWidth(min(max(fraction, 0), 1), in: width))
        } else {
            // Each group's share of the budget, separated by 2pt gaps.
            let gap: CGFloat = 2
            let total = segments.reduce(0) { $0 + $1.amount } / fraction
            let usable = max(width - gap * CGFloat(segments.count - 1), 0)
            HStack(spacing: gap) {
                ForEach(segments.indices, id: \.self) { index in
                    Rectangle()
                        .fill(segments[index].color)
                        .frame(width: usable * segments[index].amount / total)
                }
            }
        }
    }

    /// Keeps a sliver visible for small amounts so the bar never reads as empty.
    private func fillWidth(_ clamped: Double, in available: CGFloat) -> CGFloat {
        guard clamped > 0 else { return 0 }
        return max(available * clamped, min(height, 4))
    }
}

/// Slim single-colour bar used inside rows, where the amount is already shown
/// as text beside it.
struct BrandProgressBar: View {
    let percentage: Double
    var tint: Color
    var height: CGFloat = 6

    var body: some View {
        BudgetBar(fraction: percentage, tint: tint, height: height)
            .accessibilityHidden(true)
    }
}

/// Trip savings' signature: a solid arc on a track ring with content in the
/// middle. Only trip savings should use it; the budget is a `BudgetBar`.
struct ProgressRing<Center: View>: View {
    /// `.goal` (saving toward a target) turns `positive` once it's reached.
    /// `.budget` warns near and past the limit; it only exists until the home
    /// screen moves to `BudgetBar`.
    enum Tone { case goal, budget }

    let percentage: Double
    var lineWidth: CGFloat = 12
    var tone: Tone = .goal
    @ViewBuilder var center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(percentage, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(clamped, percentage > 0 ? 0.012 : 0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .smooth, value: clamped)

            center
        }
    }

    private var color: Color {
        switch tone {
        case .goal:
            return percentage >= 1 ? Brand.positive : Brand.accent
        case .budget:
            if percentage > 1 { return Brand.danger }
            return percentage >= 0.8 ? Brand.warning : Brand.accent
        }
    }
}

@available(*, deprecated, renamed: "ProgressRing")
typealias BudgetRing<Center: View> = ProgressRing<Center>

// MARK: - Status chip

/// A small sentence-case capsule: the status colour on a faint tint of itself.
/// An `accent` chip writes its text in `accentText`, since amber text is too pale.
struct StatusChip: View {
    let title: String
    /// `positive`, `warning`, `danger` or `accent`.
    var color: Color = Brand.accent

    /// The chip's text colour.
    var textColor: Color { color == Brand.accent ? Brand.accentText : color }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Brand marks

/// The app's name in plain ink. The gradient belongs to the logo mark only.
struct MoneticWordmark: View {
    var body: some View {
        Text("Monetic")
            .font(.headline)
            .foregroundStyle(Brand.textPrimary)
    }
}

/// The flat amber-and-ink logo mark (vector, with a dark-mode variant).
/// Generated by `scripts/make-brand.swift`; the asset symbol makes a missing image a build error.
struct BrandLogoMark: View {
    var size: CGFloat = 76

    var body: some View {
        Image(.brandLogo)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Category tile
/// Emoji (or legacy SF Symbol) on the group's tint. 36pt in rows, 56pt in headers.
struct CategoryTile: View {
    let icon: String
    let colorKey: String
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
            .fill(CategoryPalette.tint(for: colorKey))
            .overlay(
                Group {
                    if icon.isEmojiIcon {
                        Text(icon).font(.system(size: size * 0.5))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(CategoryPalette.color(for: colorKey))
                    }
                }
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Section header

struct BrandSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Field

/// A labelled input on a sunken well, used across the sheets instead of `Form` rows.
struct BrandField<Content: View>: View {
    let label: String
    var footnote: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).brandLabel()

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                        .fill(Brand.surfaceSunken)
                )

            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(Brand.textSecondary)
            }
        }
    }
}

// MARK: - Segmented control

/// Two-or-more option picker drawn like the native segmented control: a
/// raised pill for the selection on a sunken track.
struct BrandSegmented<Tag: Hashable>: View {
    let options: [(tag: Tag, label: String)]
    @Binding var selection: Tag
    /// Optional SF Symbol shown before each label.
    var icon: (Tag) -> String? = { _ in nil }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.tag) { option in
                let isSelected = selection == option.tag

                Button {
                    withAnimation(reduceMotion ? nil : .snappy) {
                        selection = option.tag
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let symbol = icon(option.tag) {
                            Image(systemName: symbol).imageScale(.small)
                        }
                        Text(option.label)
                    }
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Brand.textPrimary : Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Brand.Radius.small - 3, style: .continuous)
                                .fill(colorScheme == .dark ? Brand.surfaceRaised : Brand.surface)
                                .matchedGeometryEffect(id: "selection", in: indicator)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                .fill(Brand.surfaceSunken)
        )
    }
}

// MARK: - Amount entry

/// The large currency field used by the entry sheets: the hero amount on a
/// sunken well, with an optional label when the screen needs one.
struct AmountEntryCard: View {
    @Binding var amount: String
    var focus: FocusState<Bool>.Binding
    var label: String? = nil
    /// The currency the amount is in: the selected one unless the caller
    /// knows better (a per diem estimate is always USD).
    var currencyCode: String = Currency.code

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let label {
                Text(label).brandLabel()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Currency.symbol(for: currencyCode))
                    .font(.title2)
                    .foregroundStyle(Brand.textSecondary)

                TextField(AmountInput.text(cents: 0, code: currencyCode), text: $amount)
                    .accessibilityIdentifier("amountField")
                    .font(Brand.hero)
                    .moneyStyle()
                    .foregroundStyle(Brand.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused(focus)
                    .onChange(of: amount) { _, newValue in
                        amount = AmountInput.sanitize(newValue, code: currencyCode)
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                    .fill(Brand.surfaceSunken)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tag

/// A small tinted capsule label ("Edited by you"). Same look as `StatusChip`.
struct BrandTag: View {
    let text: String
    var tint: Color = Brand.accent

    var body: some View {
        StatusChip(title: text, color: tint)
    }
}

// MARK: - Stepper

/// A whole-number stepper in brand chrome, replacing the stock `Stepper`.
/// VoiceOver reads it as one adjustable control.
struct BrandStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Optional unit for the spoken value, e.g. ("traveler", "travelers").
    var unit: (singular: String, plural: String)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(Brand.textPrimary)

            Spacer(minLength: 8)

            stepButton(systemImage: "minus", enabled: value > range.lowerBound) {
                value = max(value - 1, range.lowerBound)
            }

            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.textPrimary)
                .moneyStyle()
                .frame(minWidth: 28)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: value)

            stepButton(systemImage: "plus", enabled: value < range.upperBound) {
                value = min(value + 1, range.upperBound)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spokenValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private var spokenValue: String {
        guard let unit else { return "\(value)" }
        return "\(value) \(value == 1 ? unit.singular : unit.plural)"
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Brand.accentText : Brand.textTertiary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(enabled ? Brand.accent.opacity(0.14) : Brand.track))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Empty state

/// Icon, headline, one line of explanation and a primary button, on a card.
struct BrandEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    var actionIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: Brand.Radius.small, style: .continuous)
                .fill(Brand.accent.opacity(0.12))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Brand.accentText)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(Brand.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)

            Button(actionTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(actionIdentifier ?? "")
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .brandCard(padding: Brand.Space.xl)
    }
}

// MARK: - Toolbar

/// A toolbar button drawn as plain text or a symbol, as native iOS did before
/// iOS 26 gave every item a shared glass capsule.
struct PlainToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder var content: Content

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: placement) { content }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) { content }
        }
    }
}

// MARK: - Tab bar

/// Brand colours for the root tab bar and navigation bars. UIKit appearance is
/// the only way to colour unselected items, so this is applied once before the
/// bars are built.
enum BrandTabBar {
    static func applyAppearance() {
        let selected = UIColor(Brand.accent)
        let unselected = UIColor(Brand.textTertiary)
        let titleFont = UIFont.systemFont(ofSize: 10, weight: .semibold)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = unselected
        item.normal.titleTextAttributes = [.foregroundColor: unselected, .font: titleFont]
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected, .font: titleFont]

        let appearance = UITabBarAppearance()
        if #available(iOS 26, *) {
            // The system's glass bar already floats over content; painting it
            // opaque would fight that, so only the item colours are branded.
            appearance.configureWithDefaultBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Brand.surface)
            appearance.shadowColor = UIColor(Brand.hairline)
        }
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = unselected

        // Toolbar items are plain text (PlainToolbarItem), so the bar needs a
        // solid background or scrolled content shows through behind them.
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Brand.background)
        bar.shadowColor = UIColor(Brand.hairline)
        let atTop = bar.copy()
        atTop.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = atTop
    }
}
