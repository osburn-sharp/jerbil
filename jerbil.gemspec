$LOAD_PATH.unshift 'lib'
my_gemspec = __FILE__
project = my_gemspec.sub(/.gemspec$/,'')
mod = project.capitalize

require "#{project}/version"

Gem::Specification.new do |s|
  s.name              = "#{project}"
  s.version           = self.instance_eval("#{mod}::Version")
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = File.read("Summary.txt")
  #s.homepage          = "http://github.com/#{login}/#{name}"
  s.email             = "robert@osburn-sharp.ath.cx"
  s.authors           = [ "Dr Robert" ]
  s.has_rdoc          = true

  s.files             = %w( README.txt History.txt LICENCE.txt Bugs.txt )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("sbin/**/*")
  s.files            += Dir.glob("etc/**/*")
  #s.files            += Dir.glob("init.d/**/*")
  s.files            += Dir.glob("doc/**/*")
  s.files            += Dir.glob("spec/**/*")
  s.files            += Dir.glob("test/**/*")
  
  s.add_dependency('colored')
  s.add_dependency('jelly')
  s.add_dependency('jeckyl')
  
  s.executables << 'jerbs'

#  s.executables       = %w( #{name} )
  s.description       = File.read("Intro.txt")
end