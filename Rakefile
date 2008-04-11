require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'
require 'spec/rake/spectask'
require 'fileutils'
def __DIR__
  File.dirname(__FILE__)
end

require __DIR__+'/tools/rakehelp'
require __DIR__+'/tools/annotation_extract'
include FileUtils

NAME = "smart_proxy"
MYVERSION = "0.1"
CLEAN.include ['**/.*.sw?', '*.gem', '.config']


@windows = (PLATFORM =~ /win32/)

SUDO = @windows ? "" : (ENV["SUDO_COMMAND"] || "sudo")

setup_clean [ "pkg", "lib/*.bundle", "*.gem", "doc/rdoc", ".config", 'coverage', "cache"]


desc "Packages up SmartProxy."
task :default => [:package]
task :smart_proxy => [:clean, :rdoc, :package]

task :doc => [:rdoc]

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.version = MYVERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = false
  s.extra_rdoc_files = ["README", "LICENSE", 'TODO']
  #s.rdoc_options += RDOC_OPTS + 
  #  ['--exclude', '^(app|uploads)']
  s.summary = "SmartProxy is a application-level HTTP proxy for web spiders."
  s.description = s.summary
  s.author = "Alexey Kovyrin"
  s.email = 'alexey@kovyrin.net'
  s.homepage = 'http://blog.kovyrin.net'
  s.executables = []

  s.add_dependency('curb')
  s.required_ruby_version = '>= 1.8.4'

  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob("{spec,lib,examples,script}/**/*") 
      
  s.require_path = "lib"
  s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  #p.need_tar = true
  p.gem_spec = spec
end

task :install do
  sh %{rake package}
  sh %{#{SUDO} gem install pkg/#{NAME}-#{MYVERSION} --no-rdoc --no-ri}
end

task :uninstall => [:clean] do
  sh %{#{SUDO} gem uninstall #{NAME}}
end

desc "run webgen"
task :doc_webgen do
  sh %{cd doc/site ; webgen}
end

desc "rdoc to rubyforge"
task :doc_rforge do
  sh %{rake doc}
  sh %{#{SUDO} chmod -R 755 doc} unless @windows
  sh %{/usr/bin/scp -r -p doc/rdoc/* ezmobius@rubyforge.org:/var/www/gforge-projects/merb}
end

desc 'Run all specs and then rcov'
task :aok do
  sh %{rake specs;rake rcov}
end

desc "Run all specs"
Spec::Rake::SpecTask.new('specs') do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = Dir['spec/**/*_spec.rb'].sort
end

desc "Run a specific spec with TASK=xxxx"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.libs = ['lib', 'server/lib' ]
  t.spec_files = ["spec/merb/#{ENV['TASK']}_spec.rb"]
end

desc "Run all specs output html"
Spec::Rake::SpecTask.new('specs_html') do |t|
  t.spec_opts = ["--format", "html"]
  t.libs = ['lib', 'server/lib' ]
  t.spec_files = Dir['spec/**/*_spec.rb'].sort
end

desc "RCov"
Spec::Rake::SpecTask.new('rcov') do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = Dir['spec/**/*_spec.rb'].sort
  t.libs = ['lib', 'server/lib' ]
  t.rcov = true
end

STATS_DIRECTORIES = [
  %w(Code               lib/),
  %w(Unit\ tests        specs),
].collect { |name, dir| [ name, "./#{dir}" ] }.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require __DIR__ + '/tools/code_statistics'
  #require 'extra/stats'
  verbose = true
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end

task :release => :package do
  if ENV['RELEASE']
    sh %{rubyforge add_release merb merb "#{ENV['RELEASE']}" pkg/#{NAME}-#{MYVERSION}.gem}
  else
    puts 'Usage: rake release RELEASE="Clever tag line goes here"'
  end
end

##############################################################################
# SVN
##############################################################################

desc "Add new files to subversion"
task :svn_add do
   system "svn status | grep '^\?' | sed -e 's/? *//' | sed -e 's/ /\ /g' | xargs svn add"
end


# Run specific tests or test files
# 
# Based on a technique popularized by Geoffrey Grosenbach
rule "" do |t|
  spec_cmd = (RUBY_PLATFORM =~ /java/) ? 'jruby -S spec' : 'spec'
  # spec:spec_file:spec_name
  if /spec:(.*)$/.match(t.name)
    arguments = t.name.split(":")
    file_name = arguments[1]
    spec_name = arguments[2..-1]

    if File.exist?("spec/merb/#{file_name}_spec.rb")
      run_file_name = "spec/merb/#{file_name}_spec.rb" 
    end
    
    example = !spec_name.empty? ? " -e '#{spec_name}'" : ""

    sh "#{spec_cmd} #{run_file_name} --format specdoc --colour #{example}" 
  end
end


