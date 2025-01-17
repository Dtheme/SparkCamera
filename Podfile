# Uncomment the next line to define a global platform for your project
 platform :ios, '14.0'

# 添加这行来忽略所有警告
inhibit_all_warnings!

target 'SparkCamera' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  pod 'SnapKit', '~> 5.0'
  pod 'RxSwift', '~> 6.0'
  pod 'RxCocoa', '~> 6.0'
  pod 'SwiftMessages'
  pod 'RealmSwift', '~> 10.45.0'
  pod 'GPUImage'
  
  # 添加这个配置来处理签名问题
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        
        # 添加这些行来解决签名问题
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      end
    end
  end
end

