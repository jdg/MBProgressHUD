Pod::Spec.new do |s|
  s.name                = "MBProgressHUD"
  s.version             = "0.5"
  s.summary             = "iOS  translucent HUD with an indicator."
  s.license             = { :type => 'MIT', :file => 'LICENSE' }
  s.homepage            = "https://stripe.com"
  s.author              = { "Alex MacCaw" => "alex@stripe.com" }
  s.source              = { :git => "https://github.com/jdg/MBProgressHUD.git", :tag => "0.5"}
  s.source_files        = '*.{h,m}'
  s.public_header_files = '*.h'
  s.platform            = :ios
  s.requires_arc        = true
end