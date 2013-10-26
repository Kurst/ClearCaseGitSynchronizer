#!/usr/bin/env ruby
=begin
Main script of git - clearcase syncronizator.
Steps:
1. Recieve from git list of modifed, added and deleted files.
2. Parse map files into memory
3. Extract files from git using map files
4. Archive extracted files
5. Send archive and map files to another machine (tmv716)
6. Execute clearcase_import.rb script on remote mashine via ssh

@Author:            Semerhanov Ilya
@Date:              20.01.2013
@Last Update:       17.10.2013
@Company:           T-Systems CIS
=end

require '../lib/git2'
require '../lib/common'
require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'ftools'

include Common
include Git

props_file = *ARGV[0]
without_tag = *ARGV[1]
no_send = *ARGV[2]
no_import = *ARGV[3]


LOGGER.info "Starting git_export.rb script with #{props_file} properties"
# Reading config file
settings = Configuration.new('.settings')
settings.read
conf = Configuration.new(props_file)
conf.read

#Initialize git wrapper
git = GitWrapper.new(conf.git_stable_repo)
#Switch branch
git.switch_bare_branch(conf.git_branch)
#Generate tags
current_tag = conf.git_tag.to_s

#Apply tag on git
if without_tag.nil?
  next_tag = conf.git_branch + '_' + Time.now.strftime("%Y%m%d%H%M%S")
  LOGGER.info "Applying tag #{next_tag}"
  git.create_tag(next_tag)
  conf.update_tag next_tag
else
  next_tag = current_tag
  current_tag = git.get_previous_tag conf.git_branch
end

#Get list of modified files
git.get_modified_files(current_tag, next_tag, conf.git_modified_files_map)
git.get_added_files(current_tag, next_tag, conf.git_added_files_map)
git.get_deleted_files(current_tag, next_tag, conf.git_deleted_files_map)

#Parse files to memory
modified_files = GitLogParser.new(conf.git_modified_files_map)
added_files = GitLogParser.new(conf.git_added_files_map)
modified_files_list = modified_files.process
added_files_list = added_files.process

#Extract files from git
File.makedirs(conf.app_temp_folder) unless File.exists?(conf.app_temp_folder)

LOGGER.info 'Extracting files from git'
modified_files_list.each do |user, commit|
  commit.each do |comment, files|
    files.each do |filepath|
      git.extract_file(filepath, conf.git_branch, conf.app_temp_folder)
    end
  end
end

added_files_list.each do |user, commit|
  commit.each do |comment, files|
    files.each do |filepath|
      git.extract_file(filepath, conf.git_branch, conf.app_temp_folder)
    end
  end
end

#Archive extracted files
LOGGER.debug 'Archiving extracted files'
`rm -rf "#{conf.git_output_folder}"`
File.makedirs(conf.git_output_folder)
Zipper.zip(conf.app_temp_folder, conf.git_output_folder+'/archive.zip', true)

#Copy map files
LOGGER.debug 'Copying map files'
puts "\n[ Copying map files to #{conf.git_output_folder}/ folder ]"
m_map = File.basename(conf.git_modified_files_map)
a_map = File.basename(conf.git_added_files_map)
d_map = File.basename(conf.git_deleted_files_map)
File.copy conf.git_modified_files_map, "#{conf.git_output_folder}/#{m_map}"
File.copy conf.git_added_files_map, "#{conf.git_output_folder}/#{a_map}"
File.copy conf.git_deleted_files_map, "#{conf.git_output_folder}/#{d_map}"

#Send archive to remote server
if no_send.nil?

  LOGGER.info "Sending files to remote server #{settings.clearcaseserver_hostname}"
  Net::SCP.upload!(settings.clearcaseserver_hostname, settings.clearcaseserver_user,
                   "#{conf.git_output_folder}/", "#{settings.clearcaseserver_storage}/#{conf.app_sendto}",
                   :recursive => true)

  LOGGER.debug 'Saving files to old/ folder'
  time = Time.now.strftime('%Y%m%d_%H%M%S')
  File.makedirs("old/#{time}") unless File.exists?("old/#{time}")
  File.copy "#{conf.git_output_folder}/archive.zip", "old/#{time}/archive.zip"
  File.copy "#{conf.git_output_folder}/#{m_map}", "old/#{time}/#{m_map}"
  File.copy "#{conf.git_output_folder}/#{a_map}", "old/#{time}/#{a_map}"
  File.copy "#{conf.git_output_folder}/#{d_map}", "old/#{time}/#{d_map}"
end
LOGGER.info 'Git export finished'

if no_import.nil?
  LOGGER.info 'Executing clearcase_import.rb on remote machine'
  Net::SSH.start(settings.clearcaseserver_hostname, settings.clearcaseserver_user) do |ssh|
    puts ssh.exec! "cd  #{settings.clearcaseserver_bin_home}; ./clearcase_import.rb #{props_file}"
  end
end

#Switch branch back to master
git.switch_bare_branch('master')




