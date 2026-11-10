import SwiftUI
import UIKit

// MARK: - Background

/// The app's base layer: a near-black (or near-white) field with two soft
/// brand glows bled into the corners. In dark mode this is what stops the
/// screen reading as a flat default background.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            Brand.background

            GeometryReader { geo in
                let size = max(geo.size.width, geo.size.height)

                RadialGradient(
                    colors: [Brand.blue.opacity(isDark ? 0.22 : 0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size * 0.85
                )

                RadialGradient(
                    colors: [Brand.magenta.opacity(isDark ? 0.16 : 0.07), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: size * 0.8
                )
            }
            // Additive blending only reads correctly against near-black; on the
            // light field it would clip straight to white.
            .blendMode(isDark ? .plusLighter : .normal)
        }
        .ignoresSafeArea()
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
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Brand.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.07), radius: 16, x: 0, y: 7)
    }
}

extension View {
    func brandCard(
        padding: CGFloat = Brand.Space.card,
        radius: CGFloat = Brand.Radius.card,
        raised: Bool = false
    ) -> some View {
        modifier(BrandCardModifier(padding: padding, radius: radius, raised: raised))
    }

    /// Small uppercase label with the tracking the brand uses for eyebrows.
    func brandEyebrow() -> some View {
        self
            .font(Brand.eyebrow)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(Brand.textSecondary)
    }
}

// MARK: - Buttons

/// The primary call to action. This is one of the three places the full
/// gradient appears — keeping it rare is what makes it read as a signature.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GradientBody(configuration: configuration)
    }

    // `@Environment` is only installed on a View, never on the style itself,
    // so the label is wrapped in one to read `isEnabled` correctly. The name
    // avoids `Body`, which ButtonStyle already declares as an associated type.
    private struct GradientBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Brand.display(17, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                        .fill(Brand.gradient)
                )
                .opacity(isEnabled ? 1 : 0.35)
                .saturation(isEnabled ? 1 : 0.2)
                .shadow(color: Brand.violet.opacity(isEnabled ? 0.35 : 0), radius: 16, y: 8)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// Secondary action: same shape, no gradient.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SoftBody(configuration: configuration)
    }

    private struct SoftBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Brand.display(16, .medium))
                .foregroundStyle(Brand.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                        .fill(Brand.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

// MARK: - Progress

/// The hero ring on the home screen. Healthy spending sweeps the brand
/// gradient; once the budget is close or blown it switches to a solid status
/// colour so the warning can't be mistaken for decoration.
struct BudgetRing<Center: View>: View {
    let percentage: Double
    var lineWidth: CGFloat = 14
    @ViewBuilder var center: Center

    private var clamped: Double { min(max(percentage, 0), 1) }

    private var isOver: Bool { percentage > 1 }
    private var isNearLimit: Bool { percentage >= 0.8 && percentage <= 1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(clamped, percentage > 0 ? 0.012 : 0))
                .stroke(ringStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.45), value: clamped)

            center
        }
    }

    private var ringStyle: AnyShapeStyle {
        if isOver { return AnyShapeStyle(Brand.danger) }
        if isNearLimit { return AnyShapeStyle(Brand.warning) }
        return AnyShapeStyle(Brand.ringGradient)
    }
}

/// Slim bar used inside group rows.
struct BrandProgressBar: View {
    let percentage: Double
    var tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.track)
                Capsule()
                    .fill(tint)
                    .frame(width: width(in: geo.size.width))
            }
        }
        .frame(height: height)
    }

    /// Keeps a sliver visible for small amounts so the bar never reads as empty.
    private func width(in available: CGFloat) -> CGFloat {
        let clamped = min(max(percentage, 0), 1)
        guard clamped > 0 else { return 0 }
        return max(available * clamped, 4)
    }
}

// MARK: - Brand marks

/// The wordmark, in the logo's letter-spaced caps with the gradient applied.
struct MoneticWordmark: View {
    var size: CGFloat = 15

    var body: some View {
        Text("MONETIC")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .tracking(size * 0.32)
            .foregroundStyle(Brand.gradient)
            .accessibilityLabel("Monetic")
    }
}

/// Uses the real logo asset when one has been added to the asset catalogue,
/// and falls back to a gradient tile so the app never ships a broken image.
struct BrandLogoMark: View {
    var size: CGFloat = 76

    private var hasAsset: Bool { UIImage(named: "BrandLogo") != nil }

    var body: some View {
        Group {
            if hasAsset {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Brand.gradientDiagonal)
                    .overlay(
                        Text("M")
                            .font(.system(size: size * 0.52, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Brand.violet.opacity(0.4), radius: size * 0.22, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

// MARK: - Category tile
/// Emoji (or legacy SF Symbol) on a tinted tile in the group's brand hue.
struct CategoryTile: View {
    let icon: String
    let colorKey: String
    var size: CGFloat = 44

    private var hue: Color { CategoryPalette.color(for: colorKey) }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(hue.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(hue.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Group {
                    if icon.isEmojiIcon {
                        Text(icon).font(.system(size: size * 0.5))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: size * 0.42, weight: .medium))
                            .foregroundStyle(hue)
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
                .font(Brand.display(19, .bold))
                .foregroundStyle(Brand.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Field

/// The bordered input used across the sheets, replacing stock `Form` rows.
struct BrandField<Content: View>: View {
    let label: String
    var footnote: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).brandEyebrow()

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                        .fill(Brand.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                )

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
        }
    }
}

// MARK: - Segmented control

/// Two-or-more option picker with the brand gradient on the selection.
/// Used anywhere the stock `.segmented` picker would otherwise show up.
struct BrandSegmented: View {
    let options: [(tag: String, label: String)]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.tag) { option in
                let isSelected = selection == option.tag

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = option.tag
                    }
                } label: {
                    Text(option.label)
                        .font(Brand.display(14, .semibold))
                        .foregroundStyle(isSelected ? Color.white : Brand.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Brand.gradientDiagonal)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Brand.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Amount entry

/// The large currency field used by the add/edit expense sheets.
struct AmountEntryCard: View {
    @Binding var amount: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amount").brandEyebrow()

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Currency.symbol)
                    .font(Brand.number(26, .medium))
                    .foregroundStyle(Brand.textSecondary)

                TextField("0.00", text: $amount)
                    .accessibilityIdentifier("amountField")
                    .font(Brand.number(40))
                    .foregroundStyle(Brand.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused(focus)
                    .onChange(of: amount) { _, newValue in
                        amount = AmountInput.sanitize(newValue)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
