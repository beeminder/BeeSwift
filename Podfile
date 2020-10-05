# Uncomment this line to define a global platform for your project
platform :ios, '10.0'
use_frameworks!
inhibit_all_warnings!
target 'BeeSwift' do
	pod "Alamofire", '~> 4.9'
	pod "AlamofireImage", '~> 3.6'
	pod 'AlamofireNetworkActivityIndicator', '~> 2.4'
	pod 'SnapKit', '~> 4.0'
	pod "SwiftyJSON"	
	pod "MBProgressHUD"
	pod 'IQKeyboardManager'
	pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.0.6'
end
target 'BeeSwiftToday' do
	pod 'Alamofire', '~> 4.9'
	pod 'AlamofireImage', '~>3.6'
	pod 'SnapKit', '~> 4.0'
	pod "SwiftyJSON"
	pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.0.6'
	pod "MBProgressHUD"	
end
target 'BeeSwiftTests' do
	pod "Alamofire", '~> 4.9'
	pod "AlamofireImage", '~> 3.6'
	pod 'AlamofireNetworkActivityIndicator', '~> 2.4'
	pod 'SnapKit', '~> 4.0'
	pod "SwiftyJSON"
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '4.0'
    end
  end
end
