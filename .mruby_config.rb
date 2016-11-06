MRuby::Build.new do |conf|
  toolchain :gcc
  enable_debug
  enable_test
  gembox 'default'
end
