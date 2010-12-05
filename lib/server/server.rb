require 'rubygems'
require 'sinatra'
require 'yaml'
require 'json'
require File.expand_path(File.join(File.dirname(__FILE__), '/../shared/testbot'))
require File.expand_path(File.join(File.dirname(__FILE__), 'job.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'group.rb')) #unless defined?(Group)
require File.expand_path(File.join(File.dirname(__FILE__), 'runner.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'build.rb'))

module Testbot::Server

  if ENV['INTEGRATION_TEST']
    set :port, 22880
  else
    set :port, Testbot::SERVER_PORT
  end

  class Server
    def self.valid_version?(runner_version)
      Testbot.version == runner_version
    end
  end

  post '/builds' do
    build = Build.create_and_build_jobs(params)[:id].to_s
  end

  get '/builds/:id' do
    build = Build.find(:id => params[:id].to_i)
    build.destroy if build[:done]
    { "done" => build[:done], "results" => build[:results], "success" => build[:success] }.to_json
  end

  get '/jobs/next' do
    next_job, runner = Job.next(params, @env['REMOTE_ADDR'])
    if next_job
      next_job.update(:taken_at => Time.now, :taken_by_id => runner.id)
      [ next_job[:id], next_job[:requester_mac], next_job[:project], next_job[:root], next_job[:type], (next_job[:jruby] == 1 ? 'jruby' : 'ruby'), next_job[:files] ].join(',')
    end
  end

  put '/jobs/:id' do
    job = Job.find(:id => params[:id].to_i)
    result = "\n\nExpected:#{Build.expected_time(job.files)/100.0}:Act#{params[:time].to_i/100.0}"
    result += params[:result]
    result += Build.result!(job, Runner.find(:id => job.taken_by_id), job.files, params[:time])
    Job.find(:id => params[:id].to_i).update(:result => result, :success => params[:success], :time => params[:time]); nil
  end

  get '/runners/ping' do
    return unless Server.valid_version?(params[:version])
    runner = Runner.find(:uid => params[:uid])
    runner.update(params.merge({ :last_seen_at => Time.now })) if runner
    nil
  end

  get '/runners/outdated' do
    Runner.find_all_outdated.map { |runner| [ runner[:ip], runner[:hostname], runner[:uid] ].join(' ') }.join("\n").strip
  end

  get '/runners/available_instances' do
    Runner.available_instances.to_s
  end

  get '/runners/cpu_test_times' do
    Runner.find_all_available.map { |runner| [ runner[:hostname], runner[:cpu_test_time] ].join(',') }.join("\n")
  end

  get '/runners/total_instances' do
    Runner.total_instances.to_s
  end

  get '/runners/available' do
    Runner.find_all_available.map { |runner| [ runner[:ip], runner[:hostname], runner[:uid], runner[:username], runner[:idle_instances] ].join(' ') }.join("\n").strip
  end

  get '/version' do
    Testbot.version
  end

end
