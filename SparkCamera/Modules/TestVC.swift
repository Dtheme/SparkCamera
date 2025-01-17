//
//  TestVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import GPUImage

class TestVC: UIViewController {

    // MARK: - Properties
    private var picture: GPUImagePicture?
    private var currentFilter: GPUImageFilter?
    private var renderQueue = DispatchQueue(label: "com.sparkcamera.gpuimage.render")
    private var isFilterApplied = false
    private var isProcessing = false

    // 滤镜链
    private lazy var brightnessFilter: GPUImageBrightnessFilter = {
        let filter = GPUImageBrightnessFilter()
        filter.brightness = -0.1
        return filter
    }()

    private lazy var contrastFilter: GPUImageContrastFilter = {
        let filter = GPUImageContrastFilter()
        filter.contrast = 1.2
        return filter
    }()

    private lazy var saturationFilter: GPUImageSaturationFilter = {
        let filter = GPUImageSaturationFilter()
        filter.saturation = 0.85
        return filter
    }()

    private lazy var highlightShadowFilter: GPUImageHighlightShadowFilter = {
        let filter = GPUImageHighlightShadowFilter()
        filter.highlights = 0.8
        filter.shadows = 0.2
        return filter
    }()

    private lazy var colorFilter: GPUImageRGBFilter = {
        let filter = GPUImageRGBFilter()
        filter.red = 1.0
        filter.green = 1.1
        filter.blue = 0.9
        return filter
    }()

    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "富士胶片经典镀铬"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var imageView: GPUImageView = {
        let view = GPUImageView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit
        view.fillMode = kGPUImageFillModePreserveAspectRatio
        view.sizeToFit()
        return view
    }()

    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("应用滤镜", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 确保只在第一次布局时加载图片
        if picture == nil {
            loadImage()
        }
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white

        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(imageView)
        view.addSubview(filterButton)
    }

    private func setupConstraints() {
        closeButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
        }

        // 使用固定尺寸而不是动态计算
        let screenWidth = UIScreen.main.bounds.width
        let imageHeight = screenWidth * 4/3 // 使用4:3比例

        imageView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
            make.height.equalTo(imageHeight)
        }

        filterButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(imageView.snp.bottom).offset(40)
            make.height.equalTo(44)
        }
    }

    private func loadImage() {
        guard let image = UIImage(named: "test_image") ?? UIImage(systemName: "photo") else { return }

        renderQueue.async { [weak self] in
            guard let self = self else { return }

            // 创建 GPUImage 图片对象
            self.picture = GPUImagePicture(image: image)

            DispatchQueue.main.async {
                // 直接显示原图
                self.picture?.addTarget(self.imageView)
                self.picture?.processImage()
            }
        }
    }

    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    @objc private func filterButtonTapped() {
        // 防止重复处理
        guard !isProcessing else { return }
        isProcessing = true
        filterButton.isEnabled = false

        renderQueue.async { [weak self] in
            guard let self = self else { return }

            // 移除之前的目标
            self.picture?.removeAllTargets()
            self.brightnessFilter.removeAllTargets()
            self.contrastFilter.removeAllTargets()
            self.saturationFilter.removeAllTargets()
            self.highlightShadowFilter.removeAllTargets()
            self.colorFilter.removeAllTargets()

            if !self.isFilterApplied {
                // 设置滤镜链
                self.picture?.addTarget(self.brightnessFilter)
                self.brightnessFilter.addTarget(self.contrastFilter)
                self.contrastFilter.addTarget(self.saturationFilter)
                self.saturationFilter.addTarget(self.highlightShadowFilter)
                self.highlightShadowFilter.addTarget(self.colorFilter)
                self.colorFilter.addTarget(self.imageView)

                DispatchQueue.main.async {
                    self.filterButton.setTitle("还原图片", for: .normal)
                }
            } else {
                // 还原原图
                self.picture?.addTarget(self.imageView)

                DispatchQueue.main.async {
                    self.filterButton.setTitle("应用滤镜", for: .normal)
                }
            }

            // 处理图片
            self.picture?.processImage()
            self.isFilterApplied.toggle()

            DispatchQueue.main.async {
                self.isProcessing = false
                self.filterButton.isEnabled = true
            }
        }
    }

    // MARK: - Memory Management
    deinit {
        // 清理资源
        picture?.removeAllTargets()
        brightnessFilter.removeAllTargets()
        contrastFilter.removeAllTargets()
        saturationFilter.removeAllTargets()
        highlightShadowFilter.removeAllTargets()
        colorFilter.removeAllTargets()
    }
}
