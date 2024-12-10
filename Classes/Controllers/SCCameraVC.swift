import UIKit
import AVFoundation
import SnapKit
import RxSwift

@available(iOS 15.0, *)
class SCCameraVC: UIViewController {
    
    // MARK: - Properties
    private let cameraManager: SCCameraManager
    private let disposeBag = DisposeBag()
    private var capturedPhotos: [UIImage] = []
    
    // MARK: - UI Components
    private lazy var previewView: SCCameraPreviewV = {
        let view = SCCameraPreviewV()
        view.session = cameraManager.session
        return view
    }()
    
    private lazy var photoPreview: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        return imageView
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 80, height: 80)
        layout.minimumLineSpacing = 10
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "photoCell")
        return collectionView
    }()
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Capture", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    init() {
        let defaultConfiguration = SCCameraConfiguration()
        cameraManager = SCCameraManager(configuration: defaultConfiguration)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startCameraSession()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(view.snp.height).multipliedBy(0.7)
        }
        
        view.addSubview(photoPreview)
        photoPreview.snp.makeConstraints { make in
            make.top.equalTo(previewView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(view.snp.height).multipliedBy(0.2)
        }
        
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(photoPreview.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        view.addSubview(captureButton)
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.width.height.equalTo(50)
        }
    }
    
    private func startCameraSession() {
        cameraManager.startSession()
        print("Camera session started.")
    }
    
    private func handlePhotoCapture(imageData: Data) {
        if let image = UIImage(data: imageData) {
            capturedPhotos.append(image)
            if capturedPhotos.count > 9 {
                capturedPhotos.removeFirst()
            }
            photoPreview.image = image
            collectionView.reloadData()
        }
    }
    
    @objc private func capturePhoto() {
        cameraManager.capturePhoto()
    }
}

// Conform to UICollectionViewDataSource and UICollectionViewDelegate
extension SCCameraVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return capturedPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath)
        
        // Configure the cell
        let imageView = UIImageView(image: capturedPhotos[indexPath.item])
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        cell.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        return cell
    }
} 