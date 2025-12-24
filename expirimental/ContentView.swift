import SwiftUI

struct ContentView: View {
    private let posters = [
        "Instagram post - 54",
        "Instagram post - 55",
        "Instagram post - 56",
        "Instagram post - 58"
    ]
    
    private let stackCount = 8
    private let initialStackIndex = 4
    private let visibleCardWidthRatio: CGFloat = 0.58
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int
    @State private var dragStartTime: Date?
    @State private var isDragging = false
    
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
            
            ZStack {
                Color.black.ignoresSafeArea()
                
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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if dragStartTime == nil { dragStartTime = value.time }
                            if !isDragging { isDragging = true }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let cardWidth = proxy.size.width * visibleCardWidthRatio
                            handleDragEnd(value, cardWidth: cardWidth)
                            dragStartTime = nil
                            isDragging = false
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        
        // cards / second
        let velocityCardsPerSec = (translation / cardWidth) / duration
        
        let dragComponent     = translation / cardWidth
        let velocityComponent = velocityCardsPerSec * 0.3
        
        var rawStep = dragComponent + velocityComponent
        rawStep = max(min(rawStep, 3), -3)          // ограничиваем
        
        var step = Int(round(rawStep))
        
        // если жест заметный, но округление даёт 0 — форсим +/-1, чтобы не встать на ту же
        if step == 0 && abs(rawStep) > 0.35 {
            step = rawStep > 0 ? 1 : -1
        }
        
        // маленький «шорох» не меняет карточку вообще
        if abs(rawStep) <= 0.35 {
            step = 0
        }
        
        let newIndex = (currentIndex - step)
            .clamped(to: 0...(items.count - 1))
        
        let speed = max(0.1, abs(velocityCardsPerSec))
        let extra = min(log(speed + 1) * 0.6, 0.9)
        let durationAnim = 0.4 + extra
        
        withAnimation(.timingCurve(0.2, 0.95, 0.25, 1.0, duration: durationAnim)) {
            currentIndex = newIndex
            dragOffset   = 0
        }
        
        recenterIndexIfNeeded()
    }
    
    // MARK: - Geometry / Effects
    
    private func clampedDistance(for index: Int, cardWidth: CGFloat) -> CGFloat {
        let dragProgress = dragOffset / cardWidth
        let raw = CGFloat(index - currentIndex) + dragProgress
        // сильный clamp, чтобы не было резких скачков scale/rotate у дальних карт
        return min(max(raw, -2.2), 2.2)
    }
    
    private func xOffset(for distance: CGFloat, cardWidth: CGFloat) -> CGFloat {
        let spacing: CGFloat = cardWidth * 0.55
        return distance * spacing
    }
    
    private func scale(for distance: CGFloat) -> CGFloat {
        let d = min(abs(distance), 2.2)
        // гладкая кривая: 0 → 1.0, 1 → 0.8, 2.2 → ~0.45
        let t = d / 2.2
        return 1.0 - 0.55 * t          // линейно, без ступеней
    }
    
    private func rotation(for distance: CGFloat) -> Double {
        let d = min(max(distance, -2.2), 2.2)
        let t = d / 2.2
        let maxAngle: Double = 80
        return Double(t) * maxAngle
    }
    
    private func zIndex(for distance: CGFloat) -> Double {
        100.0 - Double(abs(distance)) * 10.0
    }
    
    private func opacity(for distance: CGFloat) -> Double {
        let d = Double(abs(distance))
        
        // базовая плавная кривая: 0 → 1, 2.2 → ~0.2
        var base = max(0.0, 1.0 - d * 0.4)
        
        // третьи (d ~ 2): в покое 0, при скролле base
        if d >= 1.5 && d <= 2.2 {
            return isDragging ? base : 0.0
        }
        
        // дальше почти не видно
        if d > 2.2 {
            return isDragging ? min(base, 0.08) : 0.0
        }
        
        return base
    }
    
    private func recenterIndexIfNeeded() {
        let postersCount = posters.count
        let jump = (stackCount / 2) * postersCount
        let lowerBound = postersCount
        let upperBound = items.count - postersCount - 1
        
        if currentIndex <= lowerBound {
            currentIndex += jump
        } else if currentIndex >= upperBound {
            currentIndex -= jump
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
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
