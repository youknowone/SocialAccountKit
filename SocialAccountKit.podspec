Pod::Spec.new do |s|
  s.name         = "SocialAccountKit"
  s.version      = "0.5"
  s.summary      = "Accounts.framework/Social.framework boilerplate toolkit."
  s.homepage     = "https://github.com/youknowone/SocialAccountKit"
  s.license      = "2-clause BSD"
  s.author       = { "Jeong YunWon" => "jeong@youknowone.org" }
  s.source       = { :git => "https://github.com/youknowone/SocialAccountKit.git", :tag => "0.5" }
  s.platform     = :ios, '6.0'
  s.header_dir   = "SocialAccount"
  s.source_files = "SocialAccount/*.h", "SocialAccount/*.m"
  s.public_header_files = "SocialAccount/*.h"
  s.requires_arc = true
  s.frameworks = 'Accounts', 'Social'

  s.dependency 'TwitterReverseAuth'
  s.dependency 'FoundationExtension'
end
