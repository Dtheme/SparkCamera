import UIKit
import GPUImage
import SnapKit
import Photos

class TestVC: UIViewController {
    
    private lazy var filterView: SCFilterView = {
        let view = SCFilterView()
        view.delegate = self
        return view
    }()
    
    private lazy var filterOptionView: SCFilterOptionView = {
        let view = SCFilterOptionView()
        view.delegate = self
        view.templates = SCFilterTemplate.templates
        return view
    }()
    
    private var slider: SCScaleSlider!
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 设置FilterView
        view.addSubview(filterView)
        filterView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(filterView.snp.width).multipliedBy(4.0/3.0)
        }
        
        // 设置FilterOptionView
        view.addSubview(filterOptionView)
        filterOptionView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(120)
        }
        
        // 配置滑块
        let config = SCScaleSliderConfig(
            minValue: 0,
            maxValue: 4.0,
            step: 0.1,
            defaultValue: 1.0
        )
        
        slider = SCScaleSlider(config: config)
        slider.style = .Style.default.style
        view.addSubview(slider)
        
        // 添加值显示标签
        view.addSubview(valueLabel)
        
        // 设置约束
        slider.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalToSuperview().offset(40)
            make.right.equalToSuperview().offset(-40)
            make.height.equalTo(60)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.bottom.equalTo(slider.snp.top).offset(-20)
            make.centerX.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(30)
        }
        
        // 配置值变化回调
        slider.valueChangedHandler = { [weak self] value in
            guard let self = self else { return }
            // 根据步长对齐值
            let steps = round(value / config.step)
            let alignedValue = steps * config.step
            // 更新显示
            self.updateValueLabel(alignedValue)
        }
        
        // 设置初始值
        updateValueLabel(0.0)
    }
    
    private func loadImage() {
        guard let image = UIImage(named: "test_image2") else {
            print("无法加载测试图片")
            return
        }
        
        // 设置图片到FilterView
        filterView.setImage(image)
        
        // 更新滤镜列表 - 在初始化时已经设置了模板，不需要再次更新
        // filterOptionView.updateTemplates(SCFilterTemplate.templates)
    }
    
    private func saveImageToAlbum() {
        // 生成滤镜图片
        filterView.getFilteredImage { [weak self] image in
            guard let self = self,
                  let image = image else {
                self?.showAlert(title: "错误", message: "无法生成滤镜图片")
                return
            }
            
            // 保存到相册
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }, completionHandler: { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.showAlert(title: "成功", message: "图片已保存到相册")
                            } else {
                                self.showAlert(title: "错误", message: error?.localizedDescription ?? "保存失败")
                            }
                        }
                    })
                } else {
                    DispatchQueue.main.async {
                        self.showAlert(title: "错误", message: "没有相册访问权限")
                    }
                }
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                print("保存图片失败：\(error.localizedDescription)")
                self.showAlert(title: "保存失败", message: error.localizedDescription)
            } else {
                print("图片已保存到相册")
                self.showAlert(title: "保存成功", message: "图片已保存到相册")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func updateValueLabel(_ value: Float) {
        // 根据值的大小选择合适的格式
        let absValue = abs(value)
        let format = absValue >= 10 ? "%.0f" : (absValue >= 1 ? "%.1f" : "%.2f")
        valueLabel.text = String(format: format, value)
    }
}

// MARK: - SCFilterViewDelegate
extension TestVC: SCFilterViewDelegate {
    func filterView(_ filterView: SCFilterView, didChangeFilter template: SCFilterTemplate?) {
        // 处理滤镜变化
    }
    
    func filterViewDidTap(_ filterView: SCFilterView) {
        // 处理点击事件
    }
    
    func filterViewDidDoubleTap(_ filterView: SCFilterView) {
        // 处理双击事件
    }
    
    func filterViewDidLongPress(_ filterView: SCFilterView) {
        // 长按保存图片
        saveImageToAlbum()
    }
}

// MARK: - SCFilterOptionViewDelegate
extension TestVC: SCFilterOptionViewDelegate {
    func filterOptionView(_ filterOptionView: SCFilterOptionView, didSelectTemplate template: SCFilterTemplate) {
        // 应用选中的滤镜
        filterView.filterTemplate = template
    }
} 
