# Uncomment this line to define a global platform for your project
platform :ios, '9.0'
use_frameworks!
inhibit_all_warnings!
link_with 'BeeSwift', 'BeeminderToday'
target 'BeeSwift' do
	pod "AFNetworking", '~> 3.0'
	pod "Alamofire", '~> 4.0'
	pod "AlamofireImage", '~> 3.0'
	pod "SnapKit"
	pod "MagicalRecord"
	pod "SwiftyJSON"	
	pod "FBSDKCoreKit"
	pod "FBSDKLoginKit"
	pod "MBProgressHUD"
	pod 'IQKeyboardManager'
	pod 'Google/SignIn'
	pod 'CryptoSwift'
end

target 'BeeSwiftTests' do
	pod "AFNetworking", '~> 3.0'
	pod "Alamofire", '~> 4.0'
	pod "AlamofireImage", '~> 3.0'
	pod "SnapKit"	
	pod "MagicalRecord"
	pod "SwiftyJSON"
	pod "CryptoSwift"	
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end
