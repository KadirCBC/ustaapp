Pod::Spec.new do |s|
  s.name             = 'call_screen'
  s.version          = '0.0.1'
  s.summary          = 'Call screen wake and lockscreen plugin for ustaapp'
  s.description      = <<-DESC
Call screen wake and lockscreen plugin for ustaapp
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'UstaGelio Team' => 'dev@ustagelio.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
