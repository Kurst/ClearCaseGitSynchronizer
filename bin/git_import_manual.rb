#!/usr/bin/env ruby
=begin
Script for importing changes from clearcase to git.
Steps:
1. Receive from remote server changes from clearcase.
2. Parse map files into memory
3. Reset repository
4. Create new branch
5. Extract files from archive to new branch
6. Pull --rebase from origin
7. Move to target branch
6. Merge new branch with the target branch
7. Push changes to origin



@Author:            Semerhanov Ilya
@Creation Date:     23.02.2013
@Last Update:       22.08.2013
@Company:           T-Systems CIS


=end

require '../lib/git'
require '../lib/common'
require '../lib/clearcase'
require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'ftools'
require 'find'

include ClearCase
include Common
include Git

props_file = *ARGV[0]

LOGGER.info "Starting git_import.rb script with #{props_file} properties"

# Reading config file
settings = Configuration.new('.settings')
settings.read
conf = Configuration.new(props_file)
conf.read
#Initialize git wrapper
git = GitWrapper.new(conf.git_bare_repo)

#Check dir
dir = Dir.entries(conf.storage)
dir.delete_if { |x| x == '.' || x == '..' }
if !dir.empty? #if not empty then proceed

  #Extract files from archive
  LOGGER.info 'Extracting the archive'
  Zipper.unzip("#{conf.storage}/archive.zip", "#{conf.storage}/#{conf.git_output_folder}/")

  #Create local git repo
  local_git_path = "#{conf.storage}/../#{conf.git_remote_name}"

  if File.directory?(local_git_path)
    begin
      $commit = File.open("#{local_git_path}/../.commit").read
    rescue
      raise '***Error***'
    end
    LOGGER.info 'Resetting repo'
    git.reset_hard(local_git_path, $commit)
    git.abort_rebase(local_git_path)
  else

    git.clone("#{local_git_path}", "#{settings.gitserver_user}@#{settings.gitserver_hostname}:#{conf.git_remote_name}")
    LOGGER.info "Remote repo #{settings.gitserver_hostname}:#{conf.git_remote_name} was cloned"
    git.checkout_remote(local_git_path, conf.git_branch)
    LOGGER.info "Remote branch #{conf.git_branch} was checked out"
    commit_id = git.get_head_id(local_git_path)
    File.open("#{local_git_path}/../.commit", 'w') do |f|
      f.puts commit_id
    end
  end

  #Create and checkout git branch for clearcase
  git.create_branch(local_git_path, 'clearcase')
  LOGGER.info 'Branch for merged was created'
  git.switch_branch(local_git_path, 'clearcase')

  #Import changed files into local git repo, add and commit
  changed_files = ClearCaseLogParser.new(conf.storage + '/' + conf.clearcase_modified_map)
  changed_files_list = changed_files.process

  LOGGER.info 'Importing files to git branch'
  changed_files_list.each do |username, line|
    line.each do |comment, files|
      files.each do |filepath|
        path = ''
        File.dirname(filepath).sub(/vobs\/(.*)/) { path = $1 }
        dst = conf.storage + "/../#{conf.git_remote_name}/" + path
        File.makedirs(dst) unless File.exists?(dst)
        file = path + '/' + File.basename(filepath)
        LOGGER.debug "Copying file #{file}"
        File.copy "#{conf.storage}/#{conf.git_output_folder}/#{file}", dst
        git.add(local_git_path, file)
      end
      git.commit(local_git_path, comment, username)
    end
  end


  #lambda for comparing arrays
  substract = lambda do |ar1, ar2|
    ar2.inject(ar1) do |m, e|
      m.tap do |m|
        i = m.find_index(e)
        m.delete_at(i) if i
      end
    end
  end

  #Import changed dirs into local git repo, add and commit
  changed_dirs = ClearCaseLogParser.new(conf.storage + '/' + conf.clearcase_modified_map)
  changed_dirs_list = changed_dirs.process_dir

  LOGGER.info 'Importing dirs to git branch'
  changed_dirs_list.each do |username, line|
    line.each do |comment, dirs|
      dirs.each do |dirpath|
        path = ''
        dirpath.sub(/vobs\/(.*)/) { path = $1 }
        dst = conf.storage + "/../#{conf.git_remote_name}/" + path
        src = conf.storage + "/#{conf.git_output_folder}/" + path
        LOGGER.debug "Analyze dir #{path}"
        directory1_files = Array.new
        directory2_files = Array.new

        Find.find(dst) do |p|
          if File.file?(p)
            relative_path = p[dst.length, p.length]
            directory1_files << relative_path
          end
        end

        Find.find(src) do |p|
          if File.file?(p)
            relative_path = p[src.length, p.length]
            directory2_files << relative_path
          end
        end

        substract.call directory1_files, directory2_files

        puts directory1_files.inspect
        directory1_files.each do |f|
          f_path = path + f
          if File.extname(f) != '.tld'
            LOGGER.debug "Deleting file #{f_path}"
            git.rm(local_git_path, f_path)
          end
        end

      end
      git.commit(local_git_path, comment, username)
    end
  end

  LOGGER.info 'Rebasing to origin'
  git.pull_rebase(local_git_path, conf.git_branch)

else
  LOGGER.info '***Nothing to sync***'
end