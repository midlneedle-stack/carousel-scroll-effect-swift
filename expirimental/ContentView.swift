import SwiftUI

struct ContentView: View {
    private let posters = [
        "Instagram post - 54",
        "Instagram post - 55",
        "Instagram post - 56",
        "Instagram post - 58",
        "Instagram post - 663",
        "Instagram post - 664",
        "Instagram post - 665",
        "Instagram post - 666"
    ]
    
    private let stackCount = 12
    private let initialStackIndex = 6
    private let visibleCardWidthRatio: CGFloat = 0.58
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int
    @State private var dragStartTime: Date?
    @State private var isDragging = false
    @State private var accumulatedVelocity: CGFloat = 0  // накопленная скорость
    @State private var isAnimating = false  // флаг активной анимации
    
    // Debug parameters
    @State private var showDebug = false
    @State private var debugSpacing: CGFloat = 0.55
    @State private var debugMaxAngle: Double = 80
    @State private var debugVelocityMultiplier: CGFloat = 1.2
    @State private var debugAnimDuration: Double = 0.5
    
    init() {
        let initialID = initialStackIndex * posters.count
        _currentIndex = State(initialValue: initialID)
    }
    
    private var items: [String] {
        (0..<stackCount).flatMap { _ in posters }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let totalWidth  = proxy.size.width
            let cardWidth   = totalWidth * visibleCardWidthRatio
            let cardHeight  = cardWidth
            
            GeometryReader { geoProxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Debug button at top (invisible)
                        Button(action: {
                            withAnimation {
                                showDebug.toggle()
                            }
                        }) {
                            Rectangle()
                                .fill(Color.black.opacity(0.001))
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }

                        Spacer()

                        // Carousel - centered
                        ZStack {
                            ForEach(items.indices, id: \.self) { index in
                                let distance = clampedDistance(for: index, cardWidth: cardWidth)

                                PosterCard(imageName: items[index], size: cardWidth)
                                    .scaleEffect(scale(for: distance))
                                    .rotation3DEffect(
                                        .degrees(rotation(for: distance)),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: .center,
                                        perspective: 0.7
                                    )
                                    .offset(x: xOffset(for: distance, cardWidth: cardWidth))
                                    .zIndex(zIndex(for: distance))
                                    .opacity(opacity(for: distance))
                            }
                        }
                        .frame(height: cardHeight * 1.2)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragStartTime == nil {
                                        dragStartTime = value.time
                                        // НЕ сбрасываем accumulatedVelocity если анимация идет
                                        if !isAnimating {
                                            accumulatedVelocity = 0
                                        }
                                    }
                                    if !isDragging { isDragging = true }

                                    // Плавное начало драга
                                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 1.0)) {
                                        dragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let cardWidth = proxy.size.width * visibleCardWidthRatio
                                    handleDragEnd(value, cardWidth: cardWidth)
                                    dragStartTime = nil
                                    isDragging = false
                                }
                        )

                        Spacer()

                        // iPod-style scroll wheel at bottom
                        iPodScrollWheel(onScroll: { direction in
                            scrollCard(direction: direction)
                        })
                        .frame(width: 180, height: 180)
                        .padding(.bottom, geoProxy.safeAreaInsets.bottom + 20)
                    }
                }
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showDebug) {
                DebugMenu(
                    spacing: $debugSpacing,
                    maxAngle: $debugMaxAngle,
                    velocityMultiplier: $debugVelocityMultiplier,
                    animDuration: $debugAnimDuration
                )
            }
        }
        .onChange(of: currentIndex) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                recenterIndexIfNeeded()
            }
        }
    }
    
    // MARK: - Scroll handling

    private func scrollCard(direction: ScrollDirection) {
        let step = direction == .forward ? 1 : -1
        let newIndex = (currentIndex + step).clamped(to: 0...(items.count - 1))

        withAnimation(.timingCurve(0.12, 0.9, 0.2, 1.0, duration: 0.35)) {
            currentIndex = newIndex
        }
    }

    // MARK: - Drag handling

    private func handleDragEnd(_ value: DragGesture.Value, cardWidth: CGFloat) {
        let translation = value.translation.width
        
        let duration: TimeInterval
        if let start = dragStartTime {
            duration = max(value.time.timeIntervalSince(start), 0.01)
        } else {
            duration = 0.1
        }
        
        // Реальная скорость жеста
        let velocityCardsPerSec = (translation / cardWidth) / duration
        
        // Добавляем к накопленной скорости (если свайпнули во время анимации)
        let totalVelocity = velocityCardsPerSec + accumulatedVelocity
        
        let dragComponent = translation / cardWidth

        // Новая формула: динамическая скорость
        let velocityComponent = totalVelocity * debugVelocityMultiplier

        var rawStep = dragComponent + velocityComponent

        // Ограничиваем максимум, но даем больше свободы
        rawStep = max(min(rawStep, 30), -30)

        var step = Int(round(rawStep))

        // Минимальный порог для движения
        if abs(rawStep) < 0.3 {
            step = 0
        }
        
        let newIndex = (currentIndex - step)
            .clamped(to: 0...(items.count - 1))
        
        // Длительность: базовая + пропорционально количеству карточек
        let cardsTraveled = abs(step)
        let extraDuration = min(Double(cardsTraveled) * 0.25, 3.0)
        let durationAnim = debugAnimDuration + extraDuration
        
        // Сохраняем остаточную скорость на случай нового свайпа во время анимации
        accumulatedVelocity = totalVelocity * 0.3

        // Устанавливаем флаг анимации
        isAnimating = true

        // Сбрасываем dragOffset БЕЗ анимации
        dragOffset = 0

        withAnimation(.timingCurve(0.12, 0.9, 0.2, 1.0, duration: durationAnim)) {
            currentIndex = newIndex
        }

        // Сбрасываем накопленную скорость и флаг анимации через время анимации
        DispatchQueue.main.asyncAfter(deadline: .now() + durationAnim) {
            accumulatedVelocity = 0
            isAnimating = false
        }
    }
    
    // MARK: - Geometry / Effects
    
    private func clampedDistance(for index: Int, cardWidth: CGFloat) -> CGFloat {
        let dragProgress = dragOffset / cardWidth
        let raw = CGFloat(index - currentIndex) + dragProgress
        return min(max(raw, -2.5), 2.5)
    }

    private func xOffset(for distance: CGFloat, cardWidth: CGFloat) -> CGFloat {
        let spacing: CGFloat = cardWidth * debugSpacing
        // Ограничиваем offset для дальних карточек
        let clampedDist = min(max(distance, -1.5), 1.5)
        return clampedDist * spacing
    }
    
    private func scale(for distance: CGFloat) -> CGFloat {
        let d = min(abs(distance), 2.5)
        let t = d / 2.5
        return 1.0 - 0.55 * t
    }
    
    private func rotation(for distance: CGFloat) -> Double {
        let d = min(max(distance, -2.5), 2.5)
        let t = d / 2.5
        return Double(t) * debugMaxAngle
    }
    
    private func zIndex(for distance: CGFloat) -> Double {
        100.0 - Double(abs(distance)) * 10.0
    }
    
    private func opacity(for distance: CGFloat) -> Double {
        let d = Double(abs(distance))
        let base = max(0.0, 1.0 - d * 0.4)

        // Плавное затухание для карточек от 1.5 и дальше
        if d >= 1.5 {
            if d >= 2.0 {
                // Третьи карточки (d >= 2.0) полностью прозрачны
                return 0.0
            } else {
                // От 1.5 до 2.0 - плавное затухание
                let fadeProgress = (2.0 - d) / 0.5
                return base * fadeProgress
            }
        }

        return base
    }
    
    private func recenterIndexIfNeeded() {
        let postersCount = posters.count
        let jump = (stackCount / 2) * postersCount
        let lowerBound = postersCount * 2
        let upperBound = items.count - postersCount * 2 - 1
        
        if currentIndex <= lowerBound {
            let newIdx = currentIndex + jump
            if newIdx < items.count {
                currentIndex = newIdx
            }
        } else if currentIndex >= upperBound {
            let newIdx = currentIndex - jump
            if newIdx >= 0 {
                currentIndex = newIdx
            }
        }
    }
}

// MARK: - Debug Menu

struct DebugMenu: View {
    @Binding var spacing: CGFloat
    @Binding var maxAngle: Double
    @Binding var velocityMultiplier: CGFloat
    @Binding var animDuration: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Carousel Settings") {
                    VStack(alignment: .leading) {
                        Text("Spacing: \(spacing, specifier: "%.2f")")
                            .font(.caption)
                        Slider(value: $spacing, in: 0.3...0.8, step: 0.01)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Max Angle: \(maxAngle, specifier: "%.0f")°")
                            .font(.caption)
                        Slider(value: $maxAngle, in: 30...120, step: 1)
                    }
                }
                
                Section("Animation") {
                    VStack(alignment: .leading) {
                        Text("Velocity Multiplier: \(velocityMultiplier, specifier: "%.1f")")
                            .font(.caption)
                        Slider(value: $velocityMultiplier, in: 0.3...3.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Base Duration: \(animDuration, specifier: "%.2f")s")
                            .font(.caption)
                        Slider(value: $animDuration, in: 0.2...1.5, step: 0.05)
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        spacing = 0.55
                        maxAngle = 80
                        velocityMultiplier = 1.2
                        animDuration = 0.5
                    }
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

enum ScrollDirection {
    case forward
    case backward
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - iPod Scroll Wheel

struct iPodScrollWheel: View {
    let onScroll: (ScrollDirection) -> Void
    @State private var lastAngle: CGFloat = 0
    @State private var counter: CGFloat = 0
    @State private var isScrolling = false
    @State private var strokeOpacity: Double = 0.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Visible stroke when scrolling
                Circle()
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 60)
                    .frame(width: size, height: size)
                    .animation(.easeInOut(duration: 0.6), value: strokeOpacity)

                // Invisible scroll area
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: size, height: size)
                    .gesture(dragGesture(in: size))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dragGesture(in size: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Show stroke when scrolling starts
                if !isScrolling {
                    isScrolling = true
                    withAnimation(.easeIn(duration: 0.4)) {
                        strokeOpacity = 0.05
                    }
                }

                let center = size * 0.5
                var angle = atan2(value.location.x - center, center - value.location.y) * 180 / .pi
                if angle < 0 { angle += 360 }

                let theta = lastAngle - angle
                lastAngle = angle

                if abs(theta) < 30 { counter += theta }

                if counter > 30 {
                    onScroll(.backward)
                    counter = 0
                } else if counter < -30 {
                    onScroll(.forward)
                    counter = 0
                }
            }
            .onEnded { _ in
                counter = 0
                lastAngle = 0
                isScrolling = false

                // Hide stroke when scrolling ends
                withAnimation(.easeOut(duration: 0.6)) {
                    strokeOpacity = 0.0
                }
            }
    }
}

private struct PosterCard: View {
    let imageName: String
    let size: CGFloat
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ContentView()
}
