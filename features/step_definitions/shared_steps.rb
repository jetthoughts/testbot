def rails3?
  @version[0, 1].to_i == 3
end

def create_app
  if rails3? 
    system "rake build 1> /dev/null" if rails3?
    system("gem install #{find_latest_gem} 1> /dev/null") || raise("Testbot install failed")
    system("rails new #{@app_path} 1> /dev/null") || raise('Failed to create rails3 app')
  else
    system("rails #{@app_path} 1> /dev/null") || raise("Failed to create rails2 app")
  end
end

def with_test_gemset
  begin
    require 'rvm'
    RVM.gemset_use! @test_gemset_name
    yield
  ensure
    RVM.gemset_use! @current_gemset
  end
end

def find_latest_gem
  [ "pkg", Dir.entries("pkg").reject { |file| file[0,1] == '.' }.sort_by { |file| File.mtime("pkg/#{file}") }.last ].join('/')
end

Given /^I have a rails (.+) application$/ do |version|
  has_rvm = system "which rvm &> /dev/null"
  raise "You need rvm to run these tests as the tests use it to setup isolated environments." unless has_rvm
  
  system "rm -rf tmp/cucumber; mkdir -p tmp/cucumber"
  
  @version = version
  @test_gemset_name = "testbot_rails_#{@version}"
  @current_gemset = `rvm gemset name`.chomp
  @testbot_path = Dir.pwd
  @app_path = "tmp/cucumber/rails_#{@version}"

  has_gemset = `rvm gemset list|grep '#{@test_gemset_name}'` != ""
  if has_gemset
    with_test_gemset do
      create_app
    end
  else
    system "rvm gemset create #{@test_gemset_name} 1> /dev/null"
    
    with_test_gemset do
      system("gem install rails -v #{@version} --no-ri --no-rdoc 1> /dev/null") || raise("Failed to install rails#{@version}")
      create_app
    end
  end
end

Given /^I add testbot$/ do
  if rails3?
    system %{echo 'gem "testbot"' >> #{@app_path}/Gemfile}
  else
    system %{cd #{@app_path}; script/plugin install #{@testbot_path}}
  end
end

Given /^I run "([^"]*)"$/ do |command|
  with_test_gemset do
    system("cd #{@app_path}; #{command} 1>/dev/null") || raise("Command failed.")
  end
end

Then /^there is a "([^"]*)" file$/ do |path|
  File.exists?([ @app_path, path ].join('/')) || raise("File missing")
end

Then /^the "([^"]*)" file contains "([^"]*)"$/ do |path, content|
  File.read([ @app_path, path ].join('/')).include?(content) || raise("#{path} did not contain #{content}")
end

Then /^the testbot rake tasks are present$/ do
  pending
  # p `cd #{@app_path}; rake -T testbot` 
end
