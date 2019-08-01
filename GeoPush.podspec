Pod::Spec.new do |s|
  s.name             = 'GeoPush'
  s.version          = '1.0.0'
  s.homepage         = ''
  s.summary          = ''
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'robo-dev'
  s.source           = { :git => 'https://github.com/geo-push/ios.git', :tag => s.version.to_s }
  s.source_files     = 'GeoPush/**/*'
  s.ios.deployment_target = '10.0'
end
