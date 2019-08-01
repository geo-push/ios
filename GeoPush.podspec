Pod::Spec.new do |s|
  s.name             = 'GeoPush'
  s.version          = '1.0.0'
# s.homepage         = ''
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'robo-dev'
  s.source           = { :git => 'https://github.com/robo-dev/ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'GeoPush/**/*'
end
