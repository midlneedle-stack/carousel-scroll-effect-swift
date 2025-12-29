# Camera Control Integration Guide

## 🎮 Что добавлено

Интеграция **Camera Control** (физическая кнопка на iPhone 16) для управления каруселью постеров через свайп по кнопке.

---

## 📁 Новые файлы

### 1. `CameraControlManager.swift`
**Главный менеджер для работы с Camera Control API**

**Основные компоненты:**
- `AVCaptureSession` - минимальная capture session
- `AVCaptureSlider` - слайдер для управления каруселью (0...itemCount)
- `AVCaptureDeviceInput` - фронтальная камера (для валидации session)
- Делегат `AVCaptureSessionControlsDelegate` для отслеживания активации

**Published свойства:**
- `isSupported: Bool` - поддерживается ли Camera Control
- `isActive: Bool` - активны ли контролы сейчас
- `controlsInFullscreen: Bool` - в fullscreen режиме ли контролы

**Callback:**
- `onCarouselIndexChanged: ((Int) -> Void)?` - вызывается при изменении индекса через Camera Control

---

### 2. `Info.plist`
**Разрешение на использование камеры**

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses Camera Control for experimental UI interactions. Camera access enables physical button integration for carousel scrolling.</string>
```

При первом запуске iOS запросит разрешение на камеру.

---

## 🔧 Модификации в ContentView

### Добавлено:

**1. StateObject для CameraControlManager**
```swift
@StateObject private var cameraControlManager = CameraControlManager()
```

**2. Setup при загрузке view**
```swift
.task {
    await cameraControlManager.setup(itemCount: posters.count)

    cameraControlManager.onCarouselIndexChanged = { newIndex in
        // Обновляем карусель
    }
}
```

**3. Синхронизация currentIndex → Camera Control**
```swift
.onChange(of: currentIndex) { _, newValue in
    let normalizedIndex = newValue % posters.count
    cameraControlManager.updateSliderValue(Double(normalizedIndex))
}
```

**4. Скрытие iPod Wheel в fullscreen режиме**
```swift
if !cameraControlManager.controlsInFullscreen {
    iPodScrollWheel(...)
        .transition(.opacity)
}
```

**5. Секция в DebugMenu**
- Показывает статус Camera Control (Supported/Not Available)
- Показывает активность (Active/Inactive)
- Показывает fullscreen режим

---

## 🎯 Как это работает

### Инициализация:

1. **При загрузке ContentView:**
   - Проверяется `captureSession.supportsControls`
   - Если поддерживается → запрашивается доступ к камере

2. **После получения разрешения:**
   - Создается минимальная `AVCaptureSession`
   - Добавляется фронтальная камера как input (для валидности session)
   - Создается `AVCaptureSlider` с диапазоном `0...postersCount`
   - Слайдер добавляется к session
   - Session запускается

### Взаимодействие:

**Пользователь → Camera Control → Карусель:**
```
Light Press на Camera Control
    ↓
Система показывает overlay с "Carousel" слайдером
    ↓
Пользователь свайпает пальцем по Camera Control
    ↓
AVCaptureSlider.value изменяется
    ↓
Вызывается action closure
    ↓
onCarouselIndexChanged callback
    ↓
ContentView.currentIndex обновляется
    ↓
Карусель анимируется к новому индексу
```

**Пользователь → Экран → Camera Control:**
```
Пользователь свайпает по экрану
    ↓
ContentView.currentIndex изменяется
    ↓
onChange(currentIndex) срабатывает
    ↓
cameraControlManager.updateSliderValue() вызывается
    ↓
AVCaptureSlider.value синхронизируется
```

### Делегат события:

**`sessionControlsDidBecomeActive`** → `isActive = true`
**`sessionControlsWillEnterFullscreenAppearance`** → скрывает iPod Wheel
**`sessionControlsWillExitFullscreenAppearance`** → показывает iPod Wheel
**`sessionControlsDidBecomeInactive`** → `isActive = false`

---

## 🚀 Как тестировать

### Требования:
- ✅ **iPhone 16, 16 Plus, 16 Pro, 16 Pro Max**
- ✅ **iOS 18.0+**
- ✅ **Реальное устройство** (Camera Control недоступен в симуляторе)

### Шаги:

1. **Запустить приложение на iPhone 16**
2. **Разрешить доступ к камере** (при запросе)
3. **Открыть Debug Menu** (tap на верхнюю часть экрана)
4. **Проверить секцию "Camera Control (iPhone 16+)":**
   - Status должен быть **"Supported"** (зеленый)
5. **Закрыть Debug Menu**
6. **Light Press на Camera Control** (легкое нажатие с задержкой)
   - Должен появиться overlay с контролом "Carousel"
7. **Свайпать пальцем по Camera Control** вправо/влево
   - Карусель должна прокручиваться
   - Haptic feedback при переключении
8. **Light Double Press** → можно переключаться между контролами (если добавим еще)
9. **В fullscreen режиме** iPod Wheel должен исчезнуть

---

## 🐛 Возможные проблемы

### Проблема 1: "Status: Not Available"

**Причины:**
- Устройство не iPhone 16
- iOS версия < 18.0
- `captureSession.supportsControls` вернул `false`

**Решение:**
- Убедись что устройство iPhone 16+
- Обнови iOS до 18.0+

---

### Проблема 2: Запрос разрешения не появляется

**Причины:**
- Info.plist не подключен к проекту
- `NSCameraUsageDescription` отсутствует

**Решение:**
1. Открой проект в Xcode
2. Перейди в Project Settings → Info
3. Добавь Custom iOS Target Property:
   - Key: `Privacy - Camera Usage Description`
   - Value: `This app uses Camera Control for experimental UI interactions.`

---

### Проблема 3: Session не запускается

**Причины:**
- Не удалось добавить camera input
- Разрешение на камеру отклонено

**Решение:**
- Проверь логи в консоли (есть emoji-индикаторы)
- Сбрось разрешения: Settings → Privacy → Camera → удали приложение

---

### Проблема 4: Slider не добавляется к session

**Причины:**
- `captureSession.canAddControl()` вернул `false`
- Session достиг `maxControlsCount`

**Решение:**
- Проверь логи: "❌ Не удалось добавить slider"
- Убедись что session запущена перед добавлением контрола

---

## 📊 Логирование

CameraControlManager использует emoji для визуальной индикации в консоли:

- ✅ **Успех** (зеленый checkmark)
- ⚠️ **Предупреждение** (желтый восклицательный знак)
- ❌ **Ошибка** (красный крестик)
- ⏳ **Процесс** (песочные часы)
- 🎬 **Session** (кинокамера)
- 🎮 **Controls** (геймпад)
- 📸 **Camera Control event** (камера)

**Пример логов при успешной инициализации:**
```
✅ Camera Control поддерживается!
⏳ Запрашиваем доступ к камере...
✅ Доступ к камере разрешен
✅ Camera input добавлен
✅ Carousel slider добавлен к capture session
🎬 Capture session запущена
```

**При взаимодействии:**
```
🎮 Camera Controls активированы
📸 Camera Control: index = 5, value = 5.0
🎮 Camera Controls вошли в fullscreen режим
```

---

## 💡 Расширение функционала

### Добавить больше контролов:

**Пример: Slider для регулировки spacing**
```swift
let spacingSlider = AVCaptureSlider(
    "Spacing",
    symbolName: "arrow.left.and.right",
    in: 0.3...0.8
)

spacingSlider.setActionQueue(.main) { value in
    debugSpacing = value
}

captureSession.addControl(spacingSlider)
```

**Пример: Picker для выбора poster set**
```swift
let posterPicker = AVCaptureIndexPicker(
    "Collection",
    symbolName: "photo.stack",
    localizedIndexTitles: ["Cars", "Music"]
)

posterPicker.setActionQueue(.main) { index in
    debugPosterSet = index
}

captureSession.addControl(posterPicker)
```

---

## 🎉 Результат

Теперь в приложении **3 способа управления каруселью:**

1. **👆 Свайпы по экрану** (классический способ)
2. **🎡 iPod Scroll Wheel** (уникальная фича)
3. **📸 Camera Control** (iPhone 16+ эксклюзив)

Все три метода полностью синхронизированы между собой!

---

## 🔗 Полезные ссылки

- [Apple Developer: Camera Control HIG](https://developer.apple.com/design/human-interface-guidelines/camera-control)
- [Apple Developer: AVCaptureSlider](https://developer.apple.com/documentation/avfoundation/avcaptureslider)
- [WWDC 2025 Session 253: Enhancing your camera experience](https://developer.apple.com/videos/play/wwdc2025/253/)

---

**Happy Experimenting! 🚀**
