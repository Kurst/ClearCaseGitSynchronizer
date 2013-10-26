#!/usr/bin/env ruby
=begin
This script starts the whole clearcase to git synchronization procedure.
 
@Author:      Semerhanov Ilya
@Date:        25.03.2013
@LastUpdate:  17.10.2013
@Company:     T-Systems CIS

Versions:
  - 0.1 first draft
  - 0.5 four simple scripts
  - 1.0 run.rb introduced
  - 1.5 rebase instead of merge
  - 1.6 new configs
  - 2.0 monitoring of conflicts
  - 2.1 config refactoring
  - 3.5 separate filtering of folders in git and cc
=end

require '../lib/git'
require '../lib/common'
require '../lib/monitoring'
require 'rubygems'
require 'time'
require 'optparse'
require 'ftools'
require 'net/ssh'
require 'net/scp'

include Common
include Git
include Monitoring

ENV['JAVA_HOME'] = '/opt/jrockit/'
ENV['BEA_HOME'] = '/pkg/momw/bea/wls121'
ENV['MAVEN_HOME'] = '/opt/apache-maven-3.0.4'
ENV['PATH'] = "#{ENV['PATH']}:#{ENV['MAVEN_HOME']}/bin"

#ENV['JAVA_HOME'] = '/opt/jrockit/'
#ENV['BEA_HOME'] = '/pkg/momw/bea/wls1033'
#ENV['MAVEN_HOME'] = '/opt/apache-maven-3.0.4'
#ENV['PATH'] = "#{ENV['PATH']}:#{ENV['MAVEN_HOME']}/bin"

VER = '3.5'
build = true
POM_PATH = 'wfa_source/eca_apps/pom.xml'
MAVEN_CMD = 'clean install'
MAVEN_PROFILE = 'noredeploy,archive'
#MAVEN_OPTS = '-Dmaven.test.skip=true -DskipTests=true -Dmaven.repo.local=/home/gitserver/maven-repo -Dwlsver=1033'
MAVEN_OPTS = '-Dmaven.test.skip=true -DskipTests=true -Dmaven.repo.local=/home/git/synchronizer/maven-repo -Dwlsver=1211_unix'
overwrite_flag = false

LOGGER.info 'Initializing Git - ClearCase synchronizer v ' + VER

options = {}
options[:notag] = '0'
options[:id] = ''
opt_parser = OptionParser.new do |opt|
  opt.banner = 'Usage: run.rb -t [TASK] -c [CFG]'
  opt.separator ''
  opt.separator 'Options'

  opt.on('-t', '--task TASK', 'Define task: import or export to/from git') do |task|
    options[:task] = task
  end

  opt.on('-c', '--config CFG', 'Define config file for run script') do |cfg|
    options[:cfg] = cfg
  end

  opt.on('-s', '--skip', 'Skip build') do
    build = false
  end

  opt.on('-o', '--overwrite', 'Skip overwrite instead of merge') do
    overwrite_flag = true
  end

  opt.on('-h', '--help', 'Help') do
    puts opt_parser
    exit 1
  end

  opt.on('-v', '--version', 'Version') do
    puts VER
    exit 1
  end

  opt.on('-nt', '--no-tag', 'No tag') do
    options[:notag] = '1'
  end

  opt.on('-i', '--id ID', 'ID') do  |id|
    options[:id] = id
  end
end

opt_parser.parse!

if options[:task].nil? || options[:cfg].nil?
  puts '[ *ERROR*   Not all options were specified. Type -h option for help. ]'
  exit 1
end

#Reading configuration files
settings = Configuration.new('.settings')
settings.read
config = Configuration.new(options[:cfg])     #main_config.
config.read

#Starting tasks
if options[:task].downcase == 'import'

  LOGGER.info 'Task IMPORT was selected'
  conflict = Conflict.new
  nosync = NoSync.new
  monitor = EventMonitor.new
  conflict.add_observer monitor
  nosync.add_observer monitor
  LOGGER.info 'Event monitor was started'


  conflict_lock_path = config.storage + "/../conflict.lock"
  if File.exist? conflict_lock_path
    str = File.read(conflict_lock_path)
    poll_time = (Time.parse(str) - (config.app_polling_time.to_i * 60)).strftime('%d-%b.%H:%M')
  else
    poll_time = (Time.now - (config.app_polling_time.to_i * 60)).strftime('%d-%b.%H:%M')
  end

  LOGGER.info 'Calling clearcase export script on remote machine'
  #Net::SSH somehow not working this time...
  system "ssh #{settings.clearcaseserver_user}@#{settings.clearcaseserver_hostname} \"cd #{settings.clearcaseserver_bin_home}; ./clearcase_export.rb #{options[:cfg]} #{poll_time}\""

  LOGGER.info 'Executing git_import.rb script'
  if overwrite_flag
    res = system "./git_import.rb #{options[:cfg]} overwrite | tee #{config.storage}/../import.log"
  else
    res = system "./git_import.rb #{options[:cfg]} | tee #{config.storage}/../import.log"
  end

  if res

    LOGGER.info 'Event monitoring started'
    conflict.parse "#{config.storage}/../", "import.log"
    r = nosync.parse "#{config.storage}/../", "import.log", options[:id]
    if r
      local_git_path = "#{config.storage}/../#{config.git_remote_name}"
      pom = "#{local_git_path}/#{POM_PATH}"
      if build
        LOGGER.info 'Starting maven build'
        res_mvn = system "mvn -f #{pom} #{MAVEN_OPTS} #{MAVEN_CMD} -P #{MAVEN_PROFILE}"
      else
        res_mvn = true
      end

      if res_mvn
        LOGGER.info 'Deleting conflict lock'
        `rm -rf "#{config.storage}/../conflict.lock"`

        git = GitWrapper.new(config.git_bare_repo)
        git.pull_rebase(local_git_path, config.git_branch)
        LOGGER.info "Pushing changes to remote git repo #{config.git_remote_name}"
        git.push(local_git_path, config.git_branch)
      else
        LOGGER.fatal 'Failure. Creating lock'
        conflict.create_lock conflict_lock_path
        LOGGER.fatal 'Build Failed'
        raise '***Build Failed***'
      end
    end
  else
    LOGGER.info 'Exiting'
  end

elsif options[:task].downcase == 'export'

  LOGGER.info 'Task EXPORT was selected'
  #Create local git repo
  conflict = Conflict.new
  monitor = EventMonitor.new
  conflict.add_observer monitor
  LOGGER.info 'Event monitor was started'

  LOGGER.info 'Conflict monitoring started'
  conflict.check_lock "#{config.storage}"
  local_git_path = "#{config.storage}/../clearcase_import/#{config.git_remote_stable_name}"

  git = GitWrapper.new(config.git_stable_repo)
  git.clone("#{local_git_path}", "#{settings.gitserver_user}@#{settings.gitserver_hostname}:#{config.git_remote_stable_name}")
  LOGGER.info "Remote repo #{settings.gitserver_hostname}:#{config.git_remote_stable_name} was cloned"
  pom = "#{local_git_path}/#{POM_PATH}"
  if build
    LOGGER.info 'Starting maven build'
    res_mvn = system "mvn -f #{pom} #{MAVEN_OPTS} #{MAVEN_CMD} -P #{MAVEN_PROFILE}"
  else
    res_mvn = true
  end

  if res_mvn

    LOGGER.info 'Executing git_export.rb script'
    if  options[:notag] == '0'
      system "./git_export.rb #{options[:cfg]}"
    else
      system "./git_export.rb #{options[:cfg]} -notag"
    end
    `rm -rf "#{local_git_path}"`

    LOGGER.info 'Pushing changes to backup devlab server'
    git.push_remote('devlab')
    LOGGER.info 'Preparing for the next sync'
    local_git_path = "#{config.storage}/../#{config.git_remote_name}"
    `rm -rf "#{local_git_path}"`
    git_next = GitWrapper.new(config.git_bare_repo)
    git_next.clone("#{local_git_path}", "#{settings.gitserver_user}@#{settings.gitserver_hostname}:#{config.git_remote_name}")
    LOGGER.info "Remote repo #{settings.gitserver_hostname}:#{config.git_remote_name} was cloned"

    git_next.checkout_remote(local_git_path, config.git_branch)
    LOGGER.info "Remote branch #{config.git_branch} was checked out"
    commit_id = git_next.get_head_id(local_git_path)
    File.open("#{local_git_path}/../.commit", 'w') do |f|
      f.puts commit_id
    end
  else
    LOGGER.fatal 'Build Failed'
    raise '***Build Failed***'
  end
else
  LOGGER.error 'Wrong task was selected. Use import or export tasks'
end



