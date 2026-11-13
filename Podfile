platform :ios, '16.0'

target 'LinkAJADemo' do
  use_frameworks!
  pod 'CleverTap-iOS-SDK'

  target 'LinkAJADemoTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
