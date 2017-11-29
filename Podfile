# Uncomment this line to define a global platform for your project
platform :ios, '10.0'
use_frameworks!
inhibit_all_warnings!
target 'BeeSwift' do
	pod "AFNetworking", '~> 3.0'
	pod "Alamofire", '~> 4.5'
	pod "AlamofireImage", '~> 3.3'
	pod 'AlamofireNetworkActivityIndicator', '~> 2.2'
	pod 'SnapKit', '~> 3.2.0'
	pod "MagicalRecord"
	pod "SwiftyJSON"	
	pod "FBSDKCoreKit"
	pod "FBSDKLoginKit"
	pod "MBProgressHUD"
	pod 'IQKeyboardManager'
	pod 'TwitterKit'
	pod 'GoogleSignIn'
	pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '3.9.1'
end
target 'BeeSwiftToday' do
	pod 'AFNetworking', '~>3.0'
	pod 'Alamofire', '~>4.5'
	pod 'AlamofireImage', '~>3.3'
	pod 'SnapKit', '~> 3.2.0'
	pod "MagicalRecord" 
	pod "SwiftyJSON"
	pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '3.9.1'
	pod "MBProgressHUD"	
end
target 'BeeSwiftTests' do
	pod "AFNetworking", '~> 3.0'
	pod "Alamofire", '~> 4.5'
	pod "AlamofireImage", '~> 3.3'
	pod 'AlamofireNetworkActivityIndicator', '~> 2.2'
	pod 'SnapKit', '~> 3.2.0'
	pod "MagicalRecord"
	pod "SwiftyJSON"
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end
