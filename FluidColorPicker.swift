//
//  FluidColorPicker.swift
//
//  Created by ih8coconuts on 6/7/26.
//

import SwiftUI

/// A premium glass-style horizontal color picker with a fluid animated selection pill.
///
/// `FluidColorPicker` displays a full-spectrum color bar with a draggable selector.
/// The selector expands into a floating glass pill while dragging, then collapses
/// back into the bar when released.
///
/// Example:
///
/// ```swift
/// @State private var selectedColor: Color = .white
///
/// FluidColorPicker(
///     Text("Pick a color")
///         .font(.caption)
///         .foregroundStyle(.secondary),
///     selection: $selectedColor
/// )
/// .padding(.horizontal)
/// ```
///
/// - Important: The floating selector is drawn outside the color bar using a background
///   glass effect. Avoid placing this picker inside clipped containers if you want the
///   floating pill to remain visible.
public struct FluidColorPicker: View {
    
    // MARK: - Public Configuration
    
    private let label: Text?
    @Binding private var selection: Color
    
    private let pillSize: CGFloat
    private let colorBarHeight: CGFloat
    private let glassSpacing: CGFloat?
    private let pillExtraSpacing: CGFloat
    
    // MARK: - Private Constants
    
    private let whiteZonePercent: CGFloat = 0.03
    
    private var resolvedGlassSpacing: CGFloat {
        glassSpacing ?? ((pillSize * 0.2) + 4)
    }
    
    // MARK: - State
    
    @State private var isDragging = false
    @State private var offsetY: CGFloat = 0
    @State private var locationX: CGFloat = 0
    @State private var animatedPillSize: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    
    // MARK: - Init
    
    /// Creates a fluid glass color picker.
    ///
    /// - Parameters:
    ///   - label: Optional text displayed above the picker.
    ///   - selection: The selected color.
    ///   - pillSize: The size of the floating selector pill.
    ///   - colorBarHeight: The height of the horizontal color bar.
    ///   - glassSpacing: Optional custom spacing used by `GlassEffectContainer`.
    ///   - pillExtraSpacing: Additional spacing between the color bar and the floating pill.
    public init(
        _ label: Text? = nil,
        selection: Binding<Color>,
        pillSize: CGFloat = 30,
        colorBarHeight: CGFloat = 22,
        glassSpacing: CGFloat? = nil,
        pillExtraSpacing: CGFloat = 4
    ) {
        self.label = label
        self._selection = selection
        self.pillSize = pillSize
        self.colorBarHeight = colorBarHeight
        self.glassSpacing = glassSpacing
        self.pillExtraSpacing = pillExtraSpacing
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                label
            }
            
            GeometryReader { geo in
                let width = geo.size.width
                
                GlassEffectContainer(spacing: resolvedGlassSpacing) {
                    colorBar(width: width)
                }
                .onAppear {
                    initializeLocationIfNeeded(width: width)
                }
            }
            .frame(height: colorBarHeight)
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
}

// MARK: - View Builders

private extension FluidColorPicker {
    
    func colorBar(width: CGFloat) -> some View {
        ZStack {
            spectrumBar
                .frame(height: colorBarHeight)
                .contentShape(Rectangle())
                .overlay {
                    restingIndicator(width: width)
                }
                .clipShape(Capsule())
                .glassEffect(.regular, in: .capsule)
                .background {
                    floatingPill(width: width)
                }
                .gesture(dragGesture(width: width))
        }
    }
    
    var spectrumBar: some View {
        ZStack(alignment: .center) {
            LinearGradient(
                colors: spectrumColors,
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(Capsule())
        }
    }
    
    var spectrumColors: [Color] {
        [Color.white] + stride(from: 0.0, through: 1.0, by: 0.05).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }
    }
    
    func restingIndicator(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .frame(width: 2, height: colorBarHeight - 5)
            .glassEffect(.regular.tint(.black), in: RoundedRectangle(cornerRadius: 4))
            .scaleEffect(isDragging ? 0.7 : 1, anchor: .center)
            .blur(radius: isDragging ? 5 : 0)
            .opacity(isDragging ? 0 : 1)
            .offset(x: locationX - width / 2)
            .animation(.spring, value: isDragging)
    }
    
    func floatingPill(width: CGFloat) -> some View {
        Circle()
            .frame(width: animatedPillSize, height: animatedPillSize)
            .glassEffect(.regular.tint(selection), in: Circle())
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .offset(y: offsetY)
            .offset(x: locationX - width / 2)
    }
}

// MARK: - Interaction

private extension FluidColorPicker {
    
    func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                updateSelection(from: value.location.x, width: width)
                
                if !isDragging {
                    isDragging = true
                    animatePill()
                }
            }
            .onEnded { _ in
                isDragging = false
                animatePill()
            }
    }
    
    func updateSelection(from location: CGFloat, width: CGFloat) {
        let x = max(0, min(width, location))
        locationX = x
        
        let percent = x / width
        selection = color(for: percent)
    }
    
    func color(for percent: CGFloat) -> Color {
        if percent < whiteZonePercent {
            return .white
        }
        
        let hue = max(
            0,
            min(
                1,
                (percent - whiteZonePercent) / (1 - whiteZonePercent)
            )
        )
        
        return Color(hue: hue, saturation: 1, brightness: 1)
    }
    
    func initializeLocationIfNeeded(width: CGFloat) {
        guard locationX == 0 else { return }
        locationX = width * whiteZonePercent
    }
}

// MARK: - Animation

private extension FluidColorPicker {
    
    /// Manually animates the floating pill.
    ///
    /// This avoids animation interruptions caused by `GlassEffectContainer`
    /// when the picker is dragged while the glass selector is expanding or collapsing.
    func animatePill() {
        animationTask?.cancel()
        
        let startOffsetY = offsetY
        let startPillSize = animatedPillSize
        
        let targetOffsetY = isDragging
            ? -((colorBarHeight / 2) + (pillSize / 2)) - pillExtraSpacing
            : 0
        
        let targetPillSize = isDragging ? pillSize : 0

        let duration: Double = 0.30
        let frameRate: Double = 60
        let steps = Int(duration * frameRate)
        
        animationTask = Task {
            for step in 0...steps {
                if Task.isCancelled { return }
                
                let progress = Double(step) / Double(steps)
                let eased = Self.easeOutCubic(progress)
                
                let newOffsetY = startOffsetY + (targetOffsetY - startOffsetY) * CGFloat(eased)
                let newPillSize = startPillSize + (targetPillSize - startPillSize) * CGFloat(eased)
                
                await MainActor.run {
                    offsetY = newOffsetY
                    animatedPillSize = newPillSize
                }
                
                try? await Task.sleep(
                    for: .milliseconds(Int(1000 / frameRate))
                )
            }
            
            await MainActor.run {
                offsetY = targetOffsetY
                animatedPillSize = targetPillSize
            }
        }
    }
    
    static func easeOutCubic(_ progress: Double) -> Double {
        1 - pow(1 - progress, 3)
    }
}

#Preview("Fluid Color Picker") {
    @Previewable @State var selectedColor: Color = .white
    
    ZStack {
        LinearGradient(
            colors: [
                .black,
                Color(hex: "111111"),
                Color(hex: "181618")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 32) {
            Circle()
                .fill(selectedColor)
                .frame(width: 90, height: 90)
                .shadow(color: selectedColor.opacity(0.8), radius: 30)
            
            FluidColorPicker(
                Text("Ambient Color")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7)),
                selection: $selectedColor
            )
            .padding(.horizontal, 28)
        }
    }
}
