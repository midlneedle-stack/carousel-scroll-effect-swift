//
//  CameraControlManager.swift
//  expirimental
//
//  Created for Camera Control integration experiment
//

import SwiftUI
import AVFoundation
import AVKit
import Combine

class CameraControlManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published @MainActor var isSupported = false
    @Published @MainActor var isActive = false
    @Published @MainActor var currentSliderValue: Double = 0
    @Published @MainActor var controlsInFullscreen = false

    // MARK: - Private Properties

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.expirimental.cameraControlQueue")
    private var carouselSlider: AVCaptureSlider?
    private var captureDevice: AVCaptureDevice?
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    @available(iOS 17.2, *)
    private var captureEventInteraction: AVCaptureEventInteraction?

    // Callback для обновления карусели
    @MainActor var onCarouselIndexChanged: ((Int) -> Void)?

    // Отслеживаем предыдущее значение слайдера для определения направления
    private var previousSliderValue: Float = 0

    // Публичный доступ к preview layer для добавления в view hierarchy
    @MainActor var getPreviewLayer: (() -> AVCaptureVideoPreviewLayer?)?

    // Публичный доступ к AVCaptureEventInteraction для добавления в view
    @available(iOS 17.2, *)
    @MainActor var getEventInteraction: (() -> AVCaptureEventInteraction?)?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Setup

    func setup(itemCount: Int) async {
        // Проверяем доступность Camera Control
        guard captureSession.supportsControls else {
            print("⚠️ Camera Control не поддерживается на этом устройстве")
            await MainActor.run { isSupported = false }
            return
        }

        print("✅ Camera Control поддерживается!")
        await MainActor.run { isSupported = true }

        // Запрашиваем разрешение на камеру
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch cameraAuthStatus {
        case .authorized:
            print("✅ Доступ к камере уже разрешен")
            await configureCaptureSession(itemCount: itemCount)

        case .notDetermined:
            print("⏳ Запрашиваем доступ к камере...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                print("✅ Доступ к камере разрешен")
                await configureCaptureSession(itemCount: itemCount)
            } else {
                print("❌ Доступ к камере отклонен")
                await MainActor.run { isSupported = false }
            }

        case .denied, .restricted:
            print("❌ Доступ к камере запрещен")
            await MainActor.run { isSupported = false }

        @unknown default:
            await MainActor.run { isSupported = false }
        }
    }

    // MARK: - Capture Session Configuration

    private func configureCaptureSession(itemCount: Int) async {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // Устанавливаем низкий preset для минимальной нагрузки
            self.captureSession.sessionPreset = .low
            print("✅ Session preset установлен на .low")

            // Пытаемся добавить минимальный input для того чтобы session был валидным
            // Сначала пробуем заднюю камеру, потом фронтальную
            var cameraAdded = false

            // Попытка 1: Задняя камера
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.captureSession.canAddInput(input) {
                        self.captureSession.addInput(input)
                        self.captureDevice = device
                        self.deviceInput = input
                        cameraAdded = true
                        print("✅ Задняя камера добавлена")
                    }
                } catch {
                    print("⚠️ Задняя камера не работает: \(error)")
                }
            }

            // Попытка 2: Фронтальная камера (если задняя не сработала)
            if !cameraAdded, let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.captureSession.canAddInput(input) {
                        self.captureSession.addInput(input)
                        self.captureDevice = device
                        self.deviceInput = input
                        cameraAdded = true
                        print("✅ Фронтальная камера добавлена")
                    }
                } catch {
                    print("⚠️ Фронтальная камера не работает: \(error)")
                }
            }

            if !cameraAdded {
                print("❌ Не удалось добавить ни одну камеру!")
            }

            // Добавляем video data output - КРИТИЧЕСКИ ВАЖНО для Camera Control UI
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
                print("✅ Video output добавлен")
            } else {
                print("⚠️ Не удалось добавить video output")
            }

            // Создаем слайдер для карусели
            let slider = AVCaptureSlider(
                "Carousel",
                symbolName: "photo.stack.fill",
                in: 0...Float(itemCount - 1)
            )

            // Устанавливаем действие на главном потоке
            slider.setActionQueue(.main) { [weak self] (value: Float) in
                guard let self = self else { return }

                // Определяем направление свайпа
                let delta = value - self.previousSliderValue

                // Если изменение больше порога (0.1), это свайп в определенном направлении
                if abs(delta) >= 0.1 {
                    // delta > 0 = forward (вправо), delta < 0 = backward (влево)
                    let step = delta > 0 ? 1 : -1

                    Task { @MainActor in
                        // Вызываем callback со шагом (+1 или -1)
                        self.onCarouselIndexChanged?(step)

                        print("📸 Camera Control swipe: \(delta > 0 ? "forward" : "backward"), step = \(step)")
                    }

                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()

                    // Сохраняем текущее значение ПОСЛЕ обработки
                    self.previousSliderValue = value
                }

                Task { @MainActor in
                    self.currentSliderValue = Double(value)
                }
            }

            // Добавляем контрол к сессии
            if self.captureSession.canAddControl(slider) {
                self.captureSession.addControl(slider)
                self.carouselSlider = slider
                print("✅ Carousel slider добавлен к capture session")
            } else {
                print("❌ Не удалось добавить slider к capture session")
            }

            // Устанавливаем делегат
            self.captureSession.setControlsDelegate(self, queue: .main)

            self.captureSession.commitConfiguration()

            // Создаем preview layer (КРИТИЧНО для Camera Control)
            let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
            preview.videoGravity = .resizeAspectFill
            self.previewLayer = preview
            print("✅ Preview layer создан")

            // Публикуем preview layer и event interaction ПЕРЕД запуском сессии
            Task { @MainActor in
                // Публикуем preview layer для использования в UI
                self.getPreviewLayer = { [weak self] in
                    return self?.previewLayer
                }

                // Публикуем event interaction для добавления в view
                if #available(iOS 17.2, *) {
                    self.getEventInteraction = { [weak self] in
                        return self?.captureEventInteraction
                    }
                }
            }

            // Создаем AVCaptureEventInteraction (КРИТИЧНО для работы Camera Control!)
            if #available(iOS 17.2, *) {
                let eventInteraction = AVCaptureEventInteraction { event in
                    print("📸 AVCaptureEventInteraction event phase: \(event.phase)")
                }
                eventInteraction.isEnabled = true
                self.captureEventInteraction = eventInteraction
                print("✅ AVCaptureEventInteraction создан")
            }

            // Запускаем сессию
            self.captureSession.startRunning()

            Task { @MainActor in
                print("🎬 Capture session запущена")
                self.isSupported = true
            }
        }
    }

    // MARK: - Public Methods

    func cleanup() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureSessionControlsDelegate

extension CameraControlManager: AVCaptureSessionControlsDelegate {

    nonisolated func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        Task { @MainActor in
            print("🎮 Camera Controls активированы")
            isActive = true
        }
    }

    nonisolated func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        Task { @MainActor in
            print("🎮 Camera Controls вошли в fullscreen режим")
            controlsInFullscreen = true
        }
    }

    nonisolated func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        Task { @MainActor in
            print("🎮 Camera Controls вышли из fullscreen режима")
            controlsInFullscreen = false
        }
    }

    nonisolated func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        Task { @MainActor in
            print("🎮 Camera Controls деактивированы")
            isActive = false
        }
    }
}

// MARK: - Camera Preview View (UIKit wrapper for preview layer)

struct CameraPreviewView: UIViewRepresentable {
    let manager: CameraControlManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Добавляем AVCaptureEventInteraction - КРИТИЧНО для Camera Control!
        if #available(iOS 17.2, *) {
            Task { @MainActor in
                if let getInteraction = manager.getEventInteraction,
                   let interaction = getInteraction() {
                    view.addInteraction(interaction)
                    print("✅ AVCaptureEventInteraction добавлен в view")
                }
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Добавляем preview layer к view если он доступен
        Task { @MainActor in
            // Небольшая задержка чтобы дать время closures установиться
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды

            if let getLayer = manager.getPreviewLayer,
               let previewLayer = getLayer() {

                // Удаляем старый слой если есть
                uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

                // Устанавливаем frame для preview layer
                previewLayer.frame = uiView.bounds

                // Добавляем preview layer
                uiView.layer.addSublayer(previewLayer)

                print("✅ Preview layer добавлен в view hierarchy")
            }

            // Проверяем и добавляем event interaction если еще не добавлен
            if #available(iOS 17.2, *) {
                if let getInteraction = manager.getEventInteraction,
                   let interaction = getInteraction() {
                    if !uiView.interactions.contains(where: { $0 === interaction }) {
                        uiView.addInteraction(interaction)
                        print("✅ AVCaptureEventInteraction добавлен в view (updateUIView)")
                    }
                }
            }
        }
    }
}
