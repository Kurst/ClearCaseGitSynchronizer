#!/usr/bin/env ruby
=begin
Main script for clearcase importing.

Steps:
1. Recieve archive from git server.
2. Copy to tmp folder
3. Extract archive
4. Parse map files
5. Setview and setcs in clearcase
6. Copy files to distination
7. Chekin new files

@Author:            Semerhanov Ilya
@Date:              21.01.2013
@Last Update:       27.10.2013
@Company:           T-Systems CIS
=end

require '../lib/git'
require '../lib/common'
require '../lib/clearcase'
require 'ftools'
require 'uuidtools'

include Common
include ClearCase
include Git

props_file = *ARGV[0]

LOGGER.info "Starting clearcase_import.rb script with #{props_file} properties"
# Reading config file
settings = Configuration.new('.settings')
settings.read
conf = Configuration.new(props_file)
conf.read

#Copy from storage to tmp
LOGGER.info 'Copying files from storage to tmp folder'
File.makedirs(conf.app_temp_folder + '/' + conf.git_branch) unless File.exists?(conf.app_temp_folder)
modifed_map = File.basename(conf.git_modified_files_map)
added_map = File.basename(conf.git_added_files_map)
deleted_map = File.basename(conf.git_deleted_files_map)
begin
  File.copy "#{conf.storage}/#{conf.git_output_folder}/archive.zip", "#{conf.app_temp_folder}/#{conf.git_branch}/archive.zip"
  File.copy "#{conf.storage}/#{conf.git_output_folder}/#{modifed_map}", "#{conf.app_temp_folder}/#{conf.git_branch}/#{modifed_map}"
  File.copy "#{conf.storage}/#{conf.git_output_folder}/#{added_map}", "#{conf.app_temp_folder}/#{conf.git_branch}/#{added_map}"
  File.copy "#{conf.storage}/#{conf.git_output_folder}/#{deleted_map}", "#{conf.app_temp_folder}/#{conf.git_branch}/#{deleted_map}"
rescue
  LOGGER.error "Archive is missing"
  exit 1
end


#Extract files from archive
LOGGER.info 'Extracting the archive'
Zipper.unzip("#{conf.app_temp_folder}/#{conf.git_branch}/archive.zip", "#{conf.app_temp_folder}/#{conf.git_branch}/#{conf.git_output_folder}/")

#Parse map files
modified_files = GitLogParser.new("#{conf.app_temp_folder}/#{conf.git_branch}/#{modifed_map}")
added_files = GitLogParser.new("#{conf.app_temp_folder}/#{conf.git_branch}/#{added_map}")
deleted_files = GitLogParser.new("#{conf.app_temp_folder}/#{conf.git_branch}/#{deleted_map}")
modified_files_list = modified_files.process
added_files_list = added_files.process
deleted_files_list = deleted_files.process

#Importing to clearcase
LOGGER.info 'Starting cleartool'
shell_output = ''
IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
  clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
  clearcase.prepare_environment
  clearcase.setcs(conf.clearcase_configspec)

  LOGGER.info 'Small delay'
  sleep 10
  LOGGER.info 'Importing modified files to clearcase'
  modified_files_list.each do |submiter, commit|
    commit.each do |comment, files|
      files.each do |filepath|
        src = conf.app_temp_folder + "/" + conf.git_branch + "/#{conf.git_output_folder}/" + filepath
        #Remove folders from git
        flg = 1
        if conf.app_pathappend != ""
          git_prefix = conf.app_pathappend
          git_prefix.gsub('/', '\/')
          if filepath =~ /#{git_prefix}/
            filepath.sub(/#{git_prefix}\/(.*)/) { filepath = $1}
          else
            flg = 0
          end
        end

        #Add folder for CC and remove /vobs/
        if conf.app_pathcut != ""
          filepath = conf.app_pathcut + filepath
          filepath.sub(/vobs\/(.*)/) { filepath = $1 }
        end
        begin
          clearcase.update(src, filepath, comment, submiter) if flg == 1
        rescue
          LOGGER.error "File is missing"
        end

      end
    end
  end

  if !added_files_list.empty?
    add_dir = conf.app_temp_folder + '/' + conf.git_branch + '/to_add'
    `rm -rf "#{add_dir}"` if File.exist?(add_dir)
    added_files_list.each do |submiter, commit|
      commit.each do |comment, files|
        files.each do |filepath|
          uuid = UUIDTools::UUID.random_create
          n_add_dir = add_dir + "/" + uuid.to_s
          src = conf.app_temp_folder + "/" + conf.git_branch + "/#{conf.git_output_folder}/"  + filepath
          flg = 1
          #Remove folders from git
          if conf.app_pathappend != ""
            git_prefix = conf.app_pathappend
            git_prefix.gsub('/', '\/')
            if filepath =~ /#{git_prefix}/
              filepath.sub(/#{git_prefix}\/(.*)/) { filepath = $1}
            else
              flg = 0
            end
          end

          #Add folder for CC and remove /vobs/
          if conf.app_pathcut != ""
            filepath = conf.app_pathcut + filepath
            filepath.sub(/vobs\/(.*)/) { filepath = $1 }
          end
          if flg == 1
            dst = n_add_dir + "/" + File.dirname(filepath)
            File.makedirs(dst) unless File.exist?(dst)
            begin
              File.copy src, dst
              clearcase.import(n_add_dir+'/wfa_source/eca_apps/*', settings.clearcaseserver_vob, comment, submiter, File.basename(filepath))
            rescue
              LOGGER.error "File missing"
            end
          end

        end
      end
    end
  end


  deleted_files_list.each do |submiter, commit|
    commit.each do |comment, files|
      files.each do |filepath|
        flg = 1
        #Remove folders from git
        if conf.app_pathappend != ""
          git_prefix = conf.app_pathappend
          git_prefix.gsub('/', '\/')
          if filepath =~ /#{git_prefix}/
            filepath.sub(/#{git_prefix}\/(.*)/) { filepath = $1}
          else
            flg = 0
          end
        end

        #Add folder for CC and remove /vobs/
        if conf.app_pathcut != ""
          filepath = conf.app_pathcut + filepath
          filepath.sub(/vobs\/(.*)/) { filepath = $1 }
        end
        path = File.dirname(filepath)

        clearcase.remove(path, filepath, comment, submiter) if flg ==1
      end
    end
  end
  f.close_write
  shell_output = f.read
}

puts shell_output
`rm -rf "#{conf.app_temp_folder}"`

#Undoing checkouts
LOGGER.info 'Undoing checkouts'
shell_output = ''
IO.popen("#{settings.clearcaseserver_cleartool} setview #{conf.clearcase_view}", 'w+') { |f|
  clearcase = ClearCaseWrapper.new(f, settings.clearcaseserver_cleartool, settings.clearcaseserver_configspec_folder)
  clearcase.prepare_environment
  clearcase.setcs(conf.clearcase_configspec)
  LOGGER.info 'Small delay'
  sleep 10
  clearcase.uncheckout_all
  f.close_write
  shell_output = f.read
}
puts shell_output
LOGGER.info 'ClearCase import finished. Exiting'