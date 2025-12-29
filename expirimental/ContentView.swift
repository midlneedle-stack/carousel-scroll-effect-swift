import SwiftUI
import CoreMotion
import Combine

// MARK: - Motion Manager

class MotionManager: ObservableObject {
    @Published var tiltX: Double = 0.0
    @Published var tiltY: Double = 0.0
    private let motionManager = CMMotionManager()

    init() {
        startDeviceMotion()
    }

    private func startDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            let gravity = motion.gravity
            DispatchQueue.main.async {
                self?.tiltX = gravity.x
                self?.tiltY = gravity.y
            }
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}

struct ContentView: View {
    private let carPosters = [
        "Instagram post - 54",
        "Instagram post - 55",
        "Instagram post - 56",
        "Instagram post - 58",
        "Instagram post - 663",
        "Instagram post - 664",
        "Instagram post - 665",
        "Instagram post - 666",
        "Instagram post - 668",
        "Instagram post - 671",
        "Instagram post - 672",
        "Instagram post - 673"
    ]

    private let musicPosters = [
        "air",
        "beatle",
        "bitterend",
        "blondie",
        "brat",
        "brian",
        "canada",
        "carpenter",
        "coen",
        "deftones",
        "depeche",
        "division",
        "doom",
        "doors",
        "downshift",
        "duft",
        "football",
        "head",
        "heawen",
        "iscala",
        "joy",
        "justic",
        "justicee",
        "lllcomun",
        "lush",
        "martic",
        "massive",
        "mazzy",
        "meat",
        "men",
        "metall",
        "mmdood",
        "paranoid",
        "pasosh",
        "punk",
        "slint",
        "slowdive",
        "sonic",
        "sunny",
        "tony",
        "toxicity",
        "tribe",
        "tubeaway",
        "tyler",
        "win",
        "youth"
    ]

    private var posters: [String] {
        debugPosterSet == 0 ? carPosters : musicPosters
    }

    private var stackCount: Int {
        debugPosterSet == 0 ? 12 : 6  // Music uses fewer stacks for performance
    }

    private var initialStackIndex: Int {
        debugPosterSet == 0 ? 6 : 3  // Adjust initial index for music
    }
    private let visibleCardWidthRatio: CGFloat = 0.58

    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int
    @State private var debugPosterSet: Int = 0
    @State private var dragStartTime: Date?
    @State private var isDragging = false
    @State private var accumulatedVelocity: CGFloat = 0  // накопленная скорость
    @State private var isAnimating = false  // флаг активной анимации
    
    // Debug parameters
    @State private var showDebug = false
    @State private var debugSpacing: CGFloat = 0.55
    @State private var debugMaxAngle: Double = 80
    @State private var debugVelocityMultiplier: CGFloat = 0.3
    @State private var debugAnimDuration: Double = 1.5
    @State private var debugCarouselOffset: CGFloat = -60
    @State private var debugWheelBottomPadding: CGFloat = 100
    @State private var debugWheelFillGradientEnabled: Bool = true
    @State private var debugWheelStrokeGradientEnabled: Bool = true
    @State private var debugWheelFillGradientOpacity: Double = 0.1
    @State private var debugWheelStrokeGradientOpacity: Double = 0.2
    @State private var debugWheelFadeEnabled: Bool = false
    @State private var debugGlassBorderEnabled: Bool = true
    @State private var debugGlassStrokeWidth: CGFloat = 1.0
    @State private var debugGlassStrokeOpacity: Double = 0.10
    @State private var debugGlassGradientOpacity: Double = 0.20
    @State private var debugGlossyShineEnabled: Bool = true
    @State private var debugGlossyShineIntensity: Double = 0.05
    @State private var debugGlossyShineSize: Double = 1.00
    @State private var debugParallaxEnabled: Bool = true
    @State private var debugParallaxAmount: Double = 5.0
    @State private var debugCenterParallaxEnabled: Bool = true
    @State private var debugCenterParallaxAmount: Double = 10.0
    @State private var debugParallaxRotationEnabled: Bool = true
    @State private var debugParallaxRotationAmount: Double = 6.0
    private let glassRadius: CGFloat = 0

    // Режим управления
    @State private var controlMode: ControlMode = .scrollWheel

    @StateObject private var motionManager = MotionManager()
    @StateObject private var cameraControlManager = CameraControlManager()

    init() {
        // Always start with cars default position
        let initialID = 6 * carPosters.count
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

                    // Spacer зависит от режима
                    if controlMode == .scrollWheel || controlMode == .cameraControl {
                        Spacer()
                    }

                    // Carousel
                    ZStack {
                        ForEach(items.indices, id: \.self) { index in
                            let distance = clampedDistance(for: index, cardWidth: cardWidth)
                            let isCenterCard = abs(distance) < 0.5

                            // Only render cards within visible range for performance
                            if abs(distance) < 2.5 {
                                PosterCard(
                                imageName: items[index],
                                size: cardWidth,
                                glassBorderEnabled: debugGlassBorderEnabled,
                                glassStrokeWidth: debugGlassStrokeWidth,
                                glassStrokeOpacity: debugGlassStrokeOpacity,
                                glassGradientOpacity: debugGlassGradientOpacity,
                                glassRadius: glassRadius,
                                glossyShineEnabled: debugGlossyShineEnabled && isCenterCard,
                                glossyShineIntensity: debugGlossyShineIntensity,
                                glossyShineSize: debugGlossyShineSize,
                                tiltX: isCenterCard ? motionManager.tiltX : 0,
                                tiltY: isCenterCard ? motionManager.tiltY : 0,
                                distance: distance
                            )
                            .scaleEffect(scale(for: distance))
                            .rotation3DEffect(
                                .degrees(rotation(for: distance) + (debugParallaxRotationEnabled ? -motionManager.tiltX * debugParallaxRotationAmount : 0)),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .center,
                                perspective: 0.7
                            )
                            .offset(x: xOffset(for: distance, cardWidth: cardWidth))
                            .offset(
                                x: debugParallaxEnabled ? motionManager.tiltX * debugParallaxAmount : 0,
                                y: debugParallaxEnabled ? motionManager.tiltY * debugParallaxAmount : 0
                            )
                            .offset(
                                x: (debugCenterParallaxEnabled && isCenterCard) ? motionManager.tiltX * debugCenterParallaxAmount : 0,
                                y: (debugCenterParallaxEnabled && isCenterCard) ? motionManager.tiltY * debugCenterParallaxAmount : 0
                            )
                            .zIndex(zIndex(for: distance))
                            .opacity(opacity(for: distance))
                            }
                        }
                    }
                    .frame(height: cardHeight * 1.2)
                    .offset(y: debugCarouselOffset)
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

                    // Spacer зависит от режима
                    if controlMode == .scrollWheel || controlMode == .cameraControl {
                        Spacer()
                    }

                    // iPod-style scroll wheel at bottom - только в режиме scrollWheel
                    if controlMode == .scrollWheel && !cameraControlManager.controlsInFullscreen {
                        iPodScrollWheel(
                            fillGradientEnabled: debugWheelFillGradientEnabled,
                            strokeGradientEnabled: debugWheelStrokeGradientEnabled,
                            fillGradientOpacity: debugWheelFillGradientOpacity,
                            strokeGradientOpacity: debugWheelStrokeGradientOpacity,
                            fadeEnabled: debugWheelFadeEnabled,
                            tiltX: motionManager.tiltX,
                            tiltY: motionManager.tiltY,
                            onScroll: { direction in
                                scrollCard(direction: direction)
                            }
                        )
                        .frame(width: 180, height: 180)
                        .padding(.bottom, debugWheelBottomPadding)
                        .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                // Camera preview - только в режиме cameraControl
                if controlMode == .cameraControl && cameraControlManager.isSupported {
                    CameraPreviewView(manager: cameraControlManager)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .padding(.top, 60)
                        .padding(.trailing, 16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showDebug) {
                DebugMenu(
                    controlMode: $controlMode,
                    posterSet: $debugPosterSet,
                    spacing: $debugSpacing,
                    maxAngle: $debugMaxAngle,
                    velocityMultiplier: $debugVelocityMultiplier,
                    animDuration: $debugAnimDuration,
                    carouselOffset: $debugCarouselOffset,
                    wheelBottomPadding: $debugWheelBottomPadding,
                    wheelFillGradientEnabled: $debugWheelFillGradientEnabled,
                    wheelStrokeGradientEnabled: $debugWheelStrokeGradientEnabled,
                    wheelFillGradientOpacity: $debugWheelFillGradientOpacity,
                    wheelStrokeGradientOpacity: $debugWheelStrokeGradientOpacity,
                    wheelFadeEnabled: $debugWheelFadeEnabled,
                    glassBorderEnabled: $debugGlassBorderEnabled,
                    glassStrokeWidth: $debugGlassStrokeWidth,
                    glassStrokeOpacity: $debugGlassStrokeOpacity,
                    glassGradientOpacity: $debugGlassGradientOpacity,
                    glossyShineEnabled: $debugGlossyShineEnabled,
                    glossyShineIntensity: $debugGlossyShineIntensity,
                    glossyShineSize: $debugGlossyShineSize,
                    parallaxEnabled: $debugParallaxEnabled,
                    parallaxAmount: $debugParallaxAmount,
                    centerParallaxEnabled: $debugCenterParallaxEnabled,
                    centerParallaxAmount: $debugCenterParallaxAmount,
                    parallaxRotationEnabled: $debugParallaxRotationEnabled,
                    parallaxRotationAmount: $debugParallaxRotationAmount,
                    cameraControlManager: cameraControlManager
                )
            }
        }
        .onChange(of: currentIndex) { _, newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                recenterIndexIfNeeded()
            }
        }
        .onChange(of: debugPosterSet) { _, newValue in
            // Reset to initial position when changing poster set
            let newPosters = newValue == 0 ? carPosters : musicPosters
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = initialStackIndex * newPosters.count
            }
        }
        .task {
            // Настраиваем Camera Control только в режиме cameraControl
            if controlMode == .cameraControl {
                await cameraControlManager.setup(itemCount: posters.count)

                // Устанавливаем callback для обновления карусели
                cameraControlManager.onCarouselIndexChanged = { [self] step in
                    // step = +1 (forward) или -1 (backward)
                    // Работает как iPod scroll wheel - пошаговая прокрутка
                    let newIndex = (currentIndex + step).clamped(to: 0...(items.count - 1))

                    withAnimation(.timingCurve(0.12, 0.9, 0.2, 1.0, duration: 0.5)) {
                        currentIndex = newIndex
                    }
                }
            }
        }
        .onChange(of: controlMode) { oldValue, newValue in
            // Запускаем/останавливаем Camera Control при смене режима
            if newValue == .cameraControl && oldValue != .cameraControl {
                Task {
                    await cameraControlManager.setup(itemCount: posters.count)

                    cameraControlManager.onCarouselIndexChanged = { [self] step in
                        let newIndex = (currentIndex + step).clamped(to: 0...(items.count - 1))

                        withAnimation(.timingCurve(0.12, 0.9, 0.2, 1.0, duration: 0.5)) {
                            currentIndex = newIndex
                        }
                    }
                }
            } else if oldValue == .cameraControl && newValue != .cameraControl {
                cameraControlManager.cleanup()
            }
        }
        .onDisappear {
            cameraControlManager.cleanup()
        }
    }
    
    // MARK: - Scroll handling

    private func scrollCard(direction: ScrollDirection) {
        let step = direction == .forward ? 1 : -1
        let newIndex = (currentIndex + step).clamped(to: 0...(items.count - 1))

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

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

        // Haptic feedback if cards changed
        if step != 0 {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }

        // Длительность: базовая + пропорционально количеству карточек
        let cardsTraveled = abs(step)
        let extraDuration = min(Double(cardsTraveled) * 0.25, 3.0)
        let durationAnim = debugAnimDuration + extraDuration

        // Сохраняем остаточную скорость на случай нового свайпа во время анимации
        accumulatedVelocity = totalVelocity * 0.3

        // Устанавливаем флаг анимации
        isAnimating = true

        // Сбрасываем dragOffset с плавной spring-анимацией
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            dragOffset = 0
        }

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
    @Binding var controlMode: ControlMode
    @Binding var posterSet: Int
    @Binding var spacing: CGFloat
    @Binding var maxAngle: Double
    @Binding var velocityMultiplier: CGFloat
    @Binding var animDuration: Double
    @Binding var carouselOffset: CGFloat
    @Binding var wheelBottomPadding: CGFloat
    @Binding var wheelFillGradientEnabled: Bool
    @Binding var wheelStrokeGradientEnabled: Bool
    @Binding var wheelFillGradientOpacity: Double
    @Binding var wheelStrokeGradientOpacity: Double
    @Binding var wheelFadeEnabled: Bool
    @Binding var glassBorderEnabled: Bool
    @Binding var glassStrokeWidth: CGFloat
    @Binding var glassStrokeOpacity: Double
    @Binding var glassGradientOpacity: Double
    @Binding var glossyShineEnabled: Bool
    @Binding var glossyShineIntensity: Double
    @Binding var glossyShineSize: Double
    @Binding var parallaxEnabled: Bool
    @Binding var parallaxAmount: Double
    @Binding var centerParallaxEnabled: Bool
    @Binding var centerParallaxAmount: Double
    @Binding var parallaxRotationEnabled: Bool
    @Binding var parallaxRotationAmount: Double
    @ObservedObject var cameraControlManager: CameraControlManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Control Mode") {
                    Picker("Mode", selection: $controlMode) {
                        Text("Scroll Wheel").tag(ControlMode.scrollWheel)
                        Text("Simple Swipe").tag(ControlMode.simpleSwipe)
                        Text("Camera Control").tag(ControlMode.cameraControl)
                    }
                }

                if controlMode == .cameraControl {
                    Section("Camera Control Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        if cameraControlManager.isSupported {
                            Text("Supported")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Available")
                                .foregroundColor(.secondary)
                        }
                    }

                    if cameraControlManager.isSupported {
                        HStack {
                            Text("Active")
                            Spacer()
                            if cameraControlManager.isActive {
                                Text("Yes")
                                    .foregroundColor(.green)
                            } else {
                                Text("No")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Fullscreen Mode")
                            Spacer()
                            if cameraControlManager.controlsInFullscreen {
                                Text("Yes")
                                    .foregroundColor(.blue)
                            } else {
                                Text("No")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                        Text("Light press Camera Control to activate carousel slider")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Poster Set") {
                    Picker("Collection", selection: $posterSet) {
                        Text("Cars").tag(0)
                        Text("Music").tag(1)
                    }
                }

                Section("Layout") {
                    VStack(alignment: .leading) {
                        Text("Carousel Offset: \(carouselOffset, specifier: "%.0f")pt")
                            .font(.caption)
                        Slider(value: $carouselOffset, in: -200...200, step: 5)
                    }

                    VStack(alignment: .leading) {
                        Text("Wheel Bottom Padding: \(wheelBottomPadding, specifier: "%.0f")pt")
                            .font(.caption)
                        Slider(value: $wheelBottomPadding, in: 0...300, step: 5)
                    }
                }

                Section("Scroll Wheel") {
                    Toggle("Fade Effect", isOn: $wheelFadeEnabled)

                    Toggle("Fill Gradient", isOn: $wheelFillGradientEnabled)

                    if wheelFillGradientEnabled {
                        VStack(alignment: .leading) {
                            Text("Fill Gradient Opacity: \(wheelFillGradientOpacity, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $wheelFillGradientOpacity, in: 0.0...1.0, step: 0.05)
                        }
                    }

                    Toggle("Stroke Gradient", isOn: $wheelStrokeGradientEnabled)

                    if wheelStrokeGradientEnabled {
                        VStack(alignment: .leading) {
                            Text("Stroke Gradient Opacity: \(wheelStrokeGradientOpacity, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $wheelStrokeGradientOpacity, in: 0.0...1.0, step: 0.05)
                        }
                    }
                }

                Section("Glass Border") {
                    Toggle("Enabled", isOn: $glassBorderEnabled)

                    if glassBorderEnabled {
                        VStack(alignment: .leading) {
                            Text("Stroke Opacity: \(glassStrokeOpacity, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $glassStrokeOpacity, in: 0.0...0.5, step: 0.05)
                        }

                        VStack(alignment: .leading) {
                            Text("Gradient Opacity: \(glassGradientOpacity, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $glassGradientOpacity, in: 0.0...1.0, step: 0.05)
                        }
                    }
                }

                Section("Glossy Shine") {
                    Toggle("Enabled", isOn: $glossyShineEnabled)

                    if glossyShineEnabled {
                        VStack(alignment: .leading) {
                            Text("Intensity: \(glossyShineIntensity, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $glossyShineIntensity, in: 0.0...1.0, step: 0.05)
                        }

                        VStack(alignment: .leading) {
                            Text("Size: \(glossyShineSize, specifier: "%.2f")")
                                .font(.caption)
                            Slider(value: $glossyShineSize, in: 0.1...1.0, step: 0.05)
                        }
                    }
                }

                Section("Carousel") {
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

                    Toggle("Parallax (All Cards)", isOn: $parallaxEnabled)

                    if parallaxEnabled {
                        VStack(alignment: .leading) {
                            Text("Amount: \(parallaxAmount, specifier: "%.0f")")
                                .font(.caption)
                            Slider(value: $parallaxAmount, in: 0...50, step: 5)
                        }
                    }

                    Toggle("Parallax (Center Card)", isOn: $centerParallaxEnabled)

                    if centerParallaxEnabled {
                        VStack(alignment: .leading) {
                            Text("Amount: \(centerParallaxAmount, specifier: "%.0f")")
                                .font(.caption)
                            Slider(value: $centerParallaxAmount, in: 0...100, step: 5)
                        }
                    }

                    Toggle("Parallax Rotation", isOn: $parallaxRotationEnabled)

                    if parallaxRotationEnabled {
                        VStack(alignment: .leading) {
                            Text("Rotation Amount: \(parallaxRotationAmount, specifier: "%.0f")°")
                                .font(.caption)
                            Slider(value: $parallaxRotationAmount, in: 0...20, step: 1)
                        }
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
                        posterSet = 0
                        spacing = 0.55
                        maxAngle = 80
                        velocityMultiplier = 0.3
                        animDuration = 1.5
                        carouselOffset = -60
                        wheelBottomPadding = 100
                        wheelFillGradientEnabled = true
                        wheelStrokeGradientEnabled = true
                        wheelFillGradientOpacity = 0.1
                        wheelStrokeGradientOpacity = 0.2
                        wheelFadeEnabled = false
                        glassBorderEnabled = true
                        glassStrokeWidth = 1.0
                        glassStrokeOpacity = 0.1
                        glassGradientOpacity = 0.2
                        parallaxEnabled = true
                        parallaxAmount = 10.0
                        centerParallaxEnabled = true
                        centerParallaxAmount = 20.0
                        parallaxRotationEnabled = true
                        parallaxRotationAmount = 8.0
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

enum ControlMode {
    case scrollWheel    // Scroll wheel внизу + карусель сверху
    case simpleSwipe    // Только свайп, карусель по центру
    case cameraControl  // Camera Control + окно камеры
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - iPod Scroll Wheel

struct iPodScrollWheel: View {
    let fillGradientEnabled: Bool
    let strokeGradientEnabled: Bool
    let fillGradientOpacity: Double
    let strokeGradientOpacity: Double
    let fadeEnabled: Bool
    let tiltX: Double
    let tiltY: Double
    let onScroll: (ScrollDirection) -> Void
    @State private var lastAngle: CGFloat = 0
    @State private var counter: CGFloat = 0
    @State private var isScrolling = false
    @State private var fillOpacity: Double = 0.0
    @State private var touchAngle: Double = 0

    // Computed angle - uses touch angle when scrolling, tilt angle when idle
    private var gradientAngle: Double {
        if isScrolling {
            return touchAngle
        } else {
            // Match the card gradient calculation exactly
            let angle = atan2(tiltY, tiltX) * 180 / .pi
            return angle + 90
        }
    }

    // Independent wheel stroke settings
    private let wheelStrokeWidth: CGFloat = 1.0
    private let wheelStrokeOpacity: Double = 0.1

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Base stroke - only visible when scrolling, opacity depends on fillOpacity
                Circle()
                    .strokeBorder(
                        Color.white.opacity(wheelStrokeOpacity * (fadeEnabled ? (fillOpacity / 0.1) : 1.0)),
                        lineWidth: wheelStrokeWidth
                    )
                    .frame(width: size, height: size)
                    .animation(fadeEnabled ? .easeInOut(duration: 0.6) : .none, value: fillOpacity)

                // Stroke gradient - follows finger when scrolling, follows tilt when idle
                if strokeGradientEnabled {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(0), location: 0.0),
                                    .init(color: Color.white.opacity(strokeGradientOpacity), location: 0.5),
                                    .init(color: Color.white.opacity(0), location: 1.0)
                                ]),
                                startPoint: .init(x: 0.5 + 0.5 * cos(gradientAngle * .pi / 180),
                                                y: 0.5 + 0.5 * sin(gradientAngle * .pi / 180)),
                                endPoint: .init(x: 0.5 - 0.5 * cos(gradientAngle * .pi / 180),
                                              y: 0.5 - 0.5 * sin(gradientAngle * .pi / 180))
                            ),
                            lineWidth: wheelStrokeWidth
                        )
                        .frame(width: size, height: size)
                        .animation(.easeOut(duration: 0.6), value: gradientAngle)
                        .allowsHitTesting(false)
                }

                // Base fill when scrolling
                Circle()
                    .fill(Color.white.opacity(fadeEnabled ? fillOpacity : 0.1))
                    .frame(width: size, height: size)
                    .animation(fadeEnabled ? .easeInOut(duration: 0.6) : .none, value: fillOpacity)
                    .allowsHitTesting(false)

                // Fill gradient following finger
                if fillGradientEnabled {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.white.opacity(0), location: 0.0),
                                    .init(color: Color.white.opacity(fillGradientOpacity), location: 1.0)
                                ]),
                                startPoint: .init(x: 0.5 + 0.5 * cos(touchAngle * .pi / 180),
                                                y: 0.5 + 0.5 * sin(touchAngle * .pi / 180)),
                                endPoint: .init(x: 0.5 - 0.5 * cos(touchAngle * .pi / 180),
                                              y: 0.5 - 0.5 * sin(touchAngle * .pi / 180))
                            )
                        )
                        .frame(width: size, height: size)
                        .opacity(isScrolling ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.3), value: isScrolling)
                        .allowsHitTesting(false)
                }

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
                // Show fill when scrolling starts
                if !isScrolling {
                    isScrolling = true
                    if fadeEnabled {
                        withAnimation(.easeIn(duration: 0.4)) {
                            fillOpacity = 0.1
                        }
                    }
                }

                let center = size * 0.5
                let dx = value.location.x - center
                let dy = value.location.y - center
                var angle = atan2(dy, dx) * 180 / .pi
                if angle < 0 { angle += 360 }

                // Update touch angle for gradient
                touchAngle = Double(angle)

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

                // Hide fill when scrolling ends (only if fade enabled)
                if fadeEnabled {
                    withAnimation(.easeOut(duration: 0.6)) {
                        fillOpacity = 0.0
                    }
                }
            }
    }
}

private struct PosterCard: View {
    let imageName: String
    let size: CGFloat
    let glassBorderEnabled: Bool
    let glassStrokeWidth: CGFloat
    let glassStrokeOpacity: Double
    let glassGradientOpacity: Double
    let glassRadius: CGFloat
    let glossyShineEnabled: Bool
    let glossyShineIntensity: Double
    let glossyShineSize: Double
    let tiltX: Double
    let tiltY: Double
    let distance: CGFloat

    var gradientAngle: Double {
        let angle = atan2(tiltY, tiltX) * 180 / .pi
        return angle + 90
    }

    var gradientEffectOpacity: Double {
        return 1.0 - min(abs(distance), 1.0)
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .colorEffect(
                ShaderLibrary.glossyShine(
                    .float2(size, size),
                    .float2(tiltX, tiltY),
                    .float(glossyShineIntensity * gradientEffectOpacity),
                    .float(glossyShineSize)
                ),
                isEnabled: glossyShineEnabled
            )
            .overlay(
                Group {
                    if glassBorderEnabled {
                        GlassBorderEffect(
                            cornerRadius: glassRadius,
                            strokeWidth: glassStrokeWidth,
                            strokeOpacity: glassStrokeOpacity,
                            gradientOpacity: glassGradientOpacity,
                            tiltX: tiltX,
                            tiltY: tiltY,
                            distance: distance
                        )
                    }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct GlassBorderEffect: View {
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let strokeOpacity: Double
    let gradientOpacity: Double
    let tiltX: Double
    let tiltY: Double
    let distance: CGFloat

    var gradientAngle: Double {
        // Конвертируем наклон в угол для градиента (в градусах)
        let angle = atan2(tiltY, tiltX) * 180 / .pi
        return angle + 90 // Смещаем на 90° чтобы градиент был перпендикулярен наклону
    }

    var gradientEffectOpacity: Double {
        // Градиент плавно появляется только у центральной карточки
        return 1.0 - min(abs(distance), 1.0)
    }

    var body: some View {
        ZStack {
            // Базовый stroke - всегда показан
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: strokeWidth)

            // Градиент - только у центральной карточки
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0), location: 0.0),
                            .init(color: .white.opacity(gradientOpacity * gradientEffectOpacity), location: 0.5),
                            .init(color: .white.opacity(0), location: 1.0)
                        ]),
                        startPoint: .init(
                            x: 0.5 + 0.5 * cos(gradientAngle * .pi / 180),
                            y: 0.5 + 0.5 * sin(gradientAngle * .pi / 180)
                        ),
                        endPoint: .init(
                            x: 0.5 - 0.5 * cos(gradientAngle * .pi / 180),
                            y: 0.5 - 0.5 * sin(gradientAngle * .pi / 180)
                        )
                    ),
                    lineWidth: strokeWidth
                )
                .animation(.easeOut(duration: 0.6), value: gradientAngle)
                .animation(.easeInOut(duration: 0.3), value: distance)
        }
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}
