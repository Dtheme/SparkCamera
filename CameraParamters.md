# 相机参数汇总

### 1. **曝光（Exposure）**
- **曝光补偿（Exposure Compensation）**
  - 范围：`-2 EV` 到 `+2 EV`
  - 步长：`1/3 EV`
  - 自动模式推荐值：`0 EV`
  - 使用 `AVCaptureDevice` 的 `setExposureTargetBias(_:completionHandler:)`
  
- **快门速度（Shutter Speed）**
  - 范围：`1/8000s` 到 `30s`
  - 步长：`1/3 EV`
  - 自动模式推荐值：根据光线条件自动调整
  - 使用 `AVCaptureDevice` 的 `setExposureModeCustom(duration:iso:completionHandler:)`

- **ISO（感光度）**
  - 范围：`ISO 100` 到 `ISO 102400`（扩展 ISO 范围）
  - 步长：`1/3 EV`
  - 可设定自动 ISO 最大值，避免过高噪点
  - 使用 `AVCaptureDevice` 的 `setExposureModeCustom(duration:iso:completionHandler:)`

- **曝光锁定（AE-L）**
  - 锁定当前曝光设置，防止自动曝光调整
  - 使用 `AVCaptureDevice` 的 `exposureMode` 设置为 `.locked`

### 2. **对焦（Focus）**
- **自动对焦（Auto Focus, AF）**
  - 支持：自动对焦，通常支持触摸对焦区域
  - 使用 `AVCaptureDevice` 的 `focusMode` 设置为 `.autoFocus`

- **手动对焦（Manual Focus）**
  - 支持：用户精确调整对焦
  - 精度：在高端设备上支持高精度对焦
  - 使用 `AVCaptureDevice` 的 `setFocusModeLocked(lensPosition:completionHandler:)`

- **连续自动对焦（Continuous Autofocus, CAF）**
  - 支持：跟踪移动物体时，持续自动对焦
  - 使用 `AVCaptureDevice` 的 `focusMode` 设置为 `.continuousAutoFocus`

- **焦点锁定（AF-L）**
  - 锁定当前焦点，防止焦点随镜头移动变化
  - 使用 `AVCaptureDevice` 的 `focusMode` 设置为 `.locked`

- **焦点微调（Focus Fine-Tuning）**
  - 精细调节对焦点，适合高精度拍摄
  - 使用 `AVCaptureDevice` 的 `setFocusModeLocked(lensPosition:completionHandler:)`

- **反向对焦（Focus Peaking）**
  - 高亮显示对焦区域，辅助手动对焦，确保对焦准确
  - ~iOS 原生不支持，需要第三方库实现~
  - 推荐库：`GPUImage` 或 `Core Image`

### 3. **白平衡（White Balance）**
- **自动白平衡（AWB）**
  - 默认白平衡，自动调整以匹配环境光源
  - 使用 `AVCaptureDevice` 的 `whiteBalanceMode` 设置为 `.continuousAutoWhiteBalance`

- **手动白平衡（Manual WB）**
  - 范围：`2500K` 到 `7500K`
  - 步长：`100K` 调节
  - 用户可以通过 `AVCaptureDevice` 设置精确的色温
  - 使用 `AVCaptureDevice` 的 `setWhiteBalanceModeLocked(with:completionHandler:)`

- **自定义白平衡（Custom WB）**
  - 通过白平衡卡或环境参考点设定自定义白平衡
  - 使用 `AVCaptureDevice` 的 `setWhiteBalanceModeLocked(with:completionHandler:)`

- **白平衡锁定（AWB Lock）**
  - 锁定当前的白平衡设置，避免自动变化
  - 使用 `AVCaptureDevice` 的 `whiteBalanceMode` 设置为 `.locked`

### 4. **图像格式与输出**
- **RAW 图像（RAW Image Capture）**
  - 支持：`DNG`、`RAW` 格式
  - 设置：通过 `AVCapturePhotoSettings` 配置 RAW 输出
  - 提供更多后期处理的空间，如调整曝光、白平衡等
  - 使用 `AVCapturePhotoOutput` 的 `setPhotoSettingsForSceneMonitoring(_:)`

- **JPEG 格式（JPEG Image Capture）**
  - 支持：压缩格式，适合快速共享和处理
  - 使用 `AVCapturePhotoOutput` 的 `capturePhoto(with:delegate:)`

- **HEIF（高效图像格式）**
  - 支持：高效压缩但保留高质量图像
  - 使用 `AVCapturePhotoOutput` 的 `capturePhoto(with:delegate:)`

### 5. **视频录制参数**
- **视频分辨率（Resolution）**
  - 选项：`1920x1080`（Full HD）、`3840x2160`（4K）
  - 支持更高分辨率的设备，如 ProRes 视频录制（iPhone 13 Pro 及更新设备）
  - 使用 `AVCaptureSession` 的 `sessionPreset`

- **帧率（Frame Rate）**
  - 范围：`30fps`、`60fps`、`120fps`、`240fps`
  - 可支持更高帧率的视频录制，适用于慢动作和高质量视频录制
  - 使用 `AVCaptureDevice` 的 `activeVideoMinFrameDuration` 和 `activeVideoMaxFrameDuration`

- **视频质量（Video Quality）**
  - 支持：ProRes、HEVC（高效视频编码）
  - 配置：视频质量可根据设备配置自动调节，确保视频质量和文件大小平衡
  - 使用 `AVCaptureSession` 的 `sessionPreset`

- **音频输入（Audio Input）**
  - 支持：外部麦克风的接入，允许调节录制音频的输入增益
  - 选择：设备内置麦克风或外部音频设备
  - 使用 `AVCaptureSession` 添加音频输入设备

### 6. **高动态范围（HDR）**
- **HDR 图像（High Dynamic Range, HDR）**
  - 支持：设备自动或手动启用 HDR 模式，结合多张不同曝光的照片，扩展动态范围
  - 高端设备（如 iPhone 12 Pro 及以上）支持智能 HDR、Deep Fusion 等高级处理技术
  - 使用 `AVCapturePhotoOutput` 的 `isHighResolutionCaptureEnabled`

### 7. **曝光与对焦联合控制**
- **曝光与对焦区域联合设置**
  - 支持：用户在屏幕上选择对焦区域，自动调节该区域的曝光设置
  - 通过触摸对焦和曝光的结合，可以同时调整焦点和亮度
  - 使用 `AVCaptureDevice` 的 `setExposurePointOfInterest` 和 `setFocusPointOfInterest`

### 8. **多镜头支持（Multi-lens Support）**
- **多个摄像头（Multi-Camera）**
  - 支持：通过多个镜头（如超广角、广角、长焦）提供不同的拍摄视角
  - 在设备上自动切换镜头，或者通过手动控制指定某一镜头进行拍摄
  - 使用 `AVCaptureDevice.DiscoverySession` 获取可用摄像头

### 9. **其他高级功能**
- **深度感知（Depth Perception）**
  - 支持：iPhone 12 Pro 及以上设备的 LiDAR 扫描仪，可用于增强低光环境中的对焦精度、创建3D模型和进行背景虚化（人像模式）
  - 使用 `AVCaptureDepthDataOutput`

- **慢动作与超慢动作（Slow Motion / Super Slow Motion）**
  - 支持：`120fps`、`240fps` 等高帧率录制，适用于慢动作拍摄
  - **自动模式建议值**：根据场景光线和运动速度，自动调整慢动作的帧率（`120fps` 或 `240fps`）。
  - 使用 `AVCaptureDevice` 的 `activeFormat` 设置支持的高帧率

- **变焦（Zoom）**
  - 支持：数码变焦和光学变焦（仅适用于支持光学变焦的设备）
  - **自动模式建议值**：在支持光学变焦的设备上，建议限制变焦范围为 `2x` 到 `5x`，以避免使用过多的数码变焦而影响图像质量。
  - 使用 `AVCaptureDevice` 的 `videoZoomFactor`

### 10. **镜头畸变校正（Lens Distortion Correction）**
- **功能**：自动或手动校正图像中的几何畸变，尤其是在广角镜头或超广角镜头下，防止图像边缘出现不自然的弯曲。
- **支持设备**：所有配备广角和超广角镜头的设备（如 iPhone 11 及以上设备）。
- **自动模式建议值**：启用自动畸变校正，尤其是在拍摄建筑物、景物时。
- 使用 `AVCaptureDevice` 的 `isLensStabilizationDuringBracketedCaptureEnabled`

### 11. **实时滤镜（Live Filters）**
- **功能**：通过实时应用预设的滤镜效果（如黑白、复古、暖色调等），在拍摄过程中对图像进行美化。
- **支持设备**：所有配备 iOS 相机应用的设备。
- **自动模式建议值**：默认不启用滤镜，用户可以根据需要手动选择滤镜类型。
- 需要第三方库实现
  - 推荐库：`GPUImage` 或 `Core Image`

### 12. **自动HDR（Auto HDR）**
- **功能**：自动启用 HDR 模式，在高对比场景下，通过合成多张不同曝光的照片，扩大亮度范围，增强图像的细节。
- **支持设备**：iPhone 12 及以上设备，支持智能 HDR 或 Deep Fusion。
- **自动模式建议值**：在高对比度的场景中自动启用 HDR，用户可选择关闭以避免过度处理。
- 使用 `AVCapturePhotoOutput` 的 `isHighResolutionCaptureEnabled`

### 13. **人像模式（Portrait Mode）**
- **功能**：模拟大光圈拍摄效果，背景虚化，突出人物主体。
- **支持设备**：iPhone 7 Plus 及以上（部分设备配备 LiDAR 扫描仪支持更精确的背景虚化）。
- **自动模式建议值**：自动启用人像模式，当检测到面部或人物时，自动切换到该模式以提供虚化效果。
- 使用 `AVCapturePhotoOutput` 的 `isDepthDataDeliveryEnabled`

### 14. **实时对焦追踪（Real-time Focus Tracking）**
- **功能**：自动追踪画面中的移动物体，保持焦点不变。尤其适用于运动场景或动态物体。
- **支持设备**：iPhone 11 及以上设备。
- **自动模式建议值**：启用实时对焦追踪，尤其是拍摄运动物体或动态场景时。
- 使用 `AVCaptureDevice` 的 `focusMode` 设置为 `.continuousAutoFocus`

### 15. **连续拍摄（Burst Mode）**
- **功能**：在按下快门时，快速连拍多张照片，适合拍摄快速运动物体。
- **支持设备**：所有支持 iOS 相机的设备。
- **自动模式建议值**：默认连拍模式启用，特别是在拍摄运动物体、快速变化的场景时，帮助选择最佳拍摄瞬间。
- 使用 `AVCapturePhotoOutput` 的 `capturePhoto(with:delegate:)` 在循环中调用
