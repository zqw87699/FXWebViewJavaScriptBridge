Pod::Spec.new do |s|
  s.name         = "FXWebViewJavaScriptBridge"
  s.version      = "1.0.1"
  s.summary      = "JS桥接框架"

  s.homepage     = "https://github.com/zqw87699/FXWebViewJavaScriptBridge"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = {"zhangdazong" => "929013100@qq.com"}

  s.source       = { :git => "https://github.com/zqw87699/FXWebViewJavaScriptBridge.git", :tag => "#{s.version}"}

  s.platform     = :ios, "7.0"

  s.frameworks = "Foundation", "UIKit" , "WebKit"

  s.module_name = 'FXWebViewJavaScriptBridge' 

  s.requires_arc = true

  s.resources = 'Classes/Resources/*'

  s.source_files = 'Classes/*'
  s.public_header_files = 'Classes/*.h'

  s.dependency "FXLog"
  s.dependency "FXCommon/Core" 

end
