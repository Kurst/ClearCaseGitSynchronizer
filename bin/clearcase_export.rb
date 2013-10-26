#!/usr/bin/env ruby
=begin
Main script for clearcase exporting.

Steps:
1. Start clearcase view and configspec.
2. Extract list of updated files
3. Extract files to archive
4. Send archive to git server


@Author:            Semerhanov Ilya
@Creation Date:     28.01.2013
@Last Update:       17.10.2013
@Company:           T-Systems CIS
=end

require '../lib/common'
require '../lib/clearcase'
require 'ftools'
require 'net/ssh'
require 'net/scp'

include Common
include ClearCase

props_file = *ARGV[0]
poll_time = *ARGV[1] #time delta in minutes

LOGGER.info "Starting clearcase_export.rb script with #{props_file} properties"

# Reading config file
settings = Configuration.new('.settings')
settings.read
conf = Configuration.new(props_file)
conf.read

LOGGER.info "Polling ClearCase from #{poll_time}"

LOGGER.info 'Starting cleartool'
shell_output  = ''
IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
  clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
  clearcase.prepare_environment
  clearcase.setcs(conf.clearcase_configspec)
  LOGGER.info 'Extracting the list of modified files'
  clearcase.lshistory(poll_time, conf.clearcase_branch, settings.clearcaseserver_vob, settings.clearcaseserver_bin_home,
                      conf.clearcase_modified_map, conf.app_filter)

  f.close_write
  shell_output = f.read
}
puts shell_output

shell_output = ''
IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
  clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
  clearcase.prepare_environment
  clearcase.setcs(conf.clearcase_configspec)
  LOGGER.info 'Extracting the list of modified directories'
  clearcase.lsdirhistory(poll_time, conf.clearcase_branch, settings.clearcaseserver_vob, settings.clearcaseserver_bin_home,
                         conf.clearcase_modified_map, conf.app_filter)

  f.close_write
  shell_output = f.read
}
puts shell_output

if File.size(conf.clearcase_modified_map) > 0

  changed_files = ClearCaseLogParser.new(conf.clearcase_modified_map)
  changed_files_list = changed_files.process
  changed_dirs = ClearCaseLogParser.new(conf.clearcase_modified_map)
  changed_dirs_list = changed_dirs.process_dir

  #Copying of dirs
  shell_output = ''
  IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
    clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
    clearcase.prepare_environment
    clearcase.setcs(conf.clearcase_configspec)
    LOGGER.info 'Extracting dirs'
    changed_dirs_list.each do |id, line|
      line.each do |comment, dirs|
        dirs.each do |dirpath|
          path = ''
          #Cut path if needed
          if conf.app_pathcut != ""
            p = conf.app_pathcut
            p.gsub('/', '\/')
            dirpath.sub(/#{p}(.*)/) { path = $1 }
          else
            dirpath.sub(/vobs\/(.*)/) { path = $1 }
          end
          #Add path if needed
          if conf.app_pathappend != ""
            p = conf.app_pathappend
            p.gsub('/', '\/')
            path = p + "/" + path
          end

          dst = conf.app_temp_folder + '/' + path
          File.makedirs(dst) unless File.exists?(dst)
          clearcase.copy_dir(dirpath, dst)
        end
      end
    end
    f.close_write
    shell_output = f.read
  }
  puts shell_output

  #Copying of files
  File.makedirs(conf.app_temp_folder) unless File.exists?(conf.app_temp_folder)
  shell_output = ''
  IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
    clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
    clearcase.prepare_environment
    clearcase.setcs(conf.clearcase_configspec)
    LOGGER.info 'Extracting files'
    changed_files_list.each do |id, line|
      line.each do |comment, files|
        files.each do |filepath|
          path = ''
          #Cut path if needed
          if conf.app_pathcut != ""
            p = conf.app_pathcut
            p.gsub('/', '\/')
            File.dirname(filepath).sub(/#{p}(.*)/) { path = $1 }
          else
            File.dirname(filepath).sub(/vobs\/(.*)/) { path = $1 }
          end
          #Add path if needed
          if conf.app_pathappend != ""
            p = conf.app_pathappend
            p.gsub('/', '\/')
            path = p + "/" + path
          end

          dst = conf.app_temp_folder + '/' + path
          File.makedirs(dst) unless File.exists?(dst)
          `find #{dst} -type f -exec chmod 644 {} \\;`
          clearcase.copy(filepath, dst)
          file = dst + '/' + File.basename(filepath)
          `chmod 755 "#{file}"`
        end
      end
    end
    f.close_write
    shell_output = f.read
  }

  #Zip extracted files to archive
  `rm -rf "#{conf.clearcase_output}"`
  File.makedirs(conf.clearcase_output)
  Zipper.zip(conf.app_temp_folder, conf.clearcase_output+'/archive.zip', true)

  #Copy map file to output folder
  LOGGER.info "Copying #{conf.clearcase_modified_map} to #{conf.clearcase_output}/"
  m_map = File.basename(conf.clearcase_modified_map)
  m_map_folder = File.dirname(conf.clearcase_modified_map)
  File.makedirs "#{conf.clearcase_output}/#{m_map_folder}"
  File.copy conf.clearcase_modified_map, "#{conf.clearcase_output}/#{m_map_folder}/#{m_map}"

  #Send archive to remote server

  LOGGER.info "Sending files to remote server #{settings.gitserver_hostname}:#{settings.gitserver_port}"
  Net::SCP.start(settings.gitserver_hostname, settings.gitserver_user, :port => settings.gitserver_port) do |scp|
    scp.upload! "#{conf.clearcase_output}/", "#{settings.gitserver_remote_synchome}/#{conf.app_sendto}",
                :recursive => true
  end
end
puts shell_output
LOGGER.info 'ClearCase export finished'
