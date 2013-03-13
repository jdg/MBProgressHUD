Pod::Spec.new do |s|
  s.name         = "MBProgressHUD"
  s.version      = "0.6"
  s.summary      = "An iOS activity indicator view."
  s.description  = <<-DESC
                    MBProgressHUD is an iOS drop-in class that displays a translucent HUD 
                    with an indicator and/or labels while work is being done in a background thread. 
                    The HUD is meant as a replacement for the undocumented, private UIKit UIProgressHUD 
                    with some additional features.
                   DESC
  s.homepage     = "http://www.bukovinski.com"
  s.screenshots = [ "http://dl.dropbox.com/u/378729/MBProgressHUD/1.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/2.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/3.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/4.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/5.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/6.png",
                    "http://dl.dropbox.com/u/378729/MBProgressHUD/7.png" ]
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Matej Bukovinski' => 'matej@bukovinski.com' }
  s.source       = { :git => "https://github.com/matej/MBProgressHUD.git", :tag => s.version.to_s }
  s.platform     = :ios
  s.source_files = '*.{h,m}'
  s.framework    = "CoreGraphics"
  s.requires_arc = true
end
