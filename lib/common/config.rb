=begin
Class for parsing config file.

@Author:  Semerhanov Ilya
@Date:    24.08.2013
@Company: T-Systems CIS

=end

module Common
  require 'yaml'

  class Configuration

    attr_reader :clearcaseserver_hostname, :clearcaseserver_user, :clearcaseserver_cleartool,
                :clearcaseserver_vob, :clearcaseserver_bin_home, :clearcaseserver_configspec_folder,
                :gitserver_hostname, :gitserver_port, :gitserver_user, :gitserver_remote_synchome,
                :app_polling_time, :git_remote_name, :git_bare_repo, :git_branch,
                :git_repo, :storage, :clearcase_view, :clearcase_configspec, :clearcase_branch, :clearcase_modified_map,
                :app_temp_folder, :clearcase_output, :git_stable_repo, :git_tag, :git_modified_files_map, :git_added_files_map,
                :git_deleted_files_map, :git_output_folder, :clearcaseserver_storage, :git_remote_stable_name, :app_filter,
                :app_pathcut, :app_sendto, :app_pathappend


    def initialize path
      raise ArgumentError unless File.exists?(path)
      @path = path
    end

    def read
      cfg = YAML.load_file(@path)
      if cfg["clearcaseserver"] != nil
        @clearcaseserver_user               = cfg["clearcaseserver"]["user"]
        @clearcaseserver_hostname           = cfg["clearcaseserver"]["hostname"]
        @clearcaseserver_bin_home           = cfg["clearcaseserver"]["bin_home"]
        @clearcaseserver_storage            = cfg["clearcaseserver"]["storage"]
        @clearcaseserver_cleartool          = cfg["clearcaseserver"]["cleartool"]
        @clearcaseserver_vob                = cfg["clearcaseserver"]["vob"]
        @clearcaseserver_configspec_folder  = cfg["clearcaseserver"]["configspec_folder"]
      end
      if cfg["gitserver"] != nil
        @gitserver_user            = cfg["gitserver"]["user"]
        @gitserver_hostname        = cfg["gitserver"]["hostname"]
        @gitserver_port            = cfg["gitserver"]["port"]
        @gitserver_remote_synchome = cfg["gitserver"]["remote_synchome"]

        @gitserver_port = "22" if @gitserver_port.nil?

      end
      if cfg["application"] != nil
        @storage                  = cfg["application"]["storage"]
        @app_polling_time         = cfg["application"]["polling_time"]
        @app_temp_folder          = cfg["application"]["temp_folder"]
        @app_filter               = cfg["application"]["filter"]
        @app_pathcut              = cfg["application"]["pathcut"]
        @app_pathcut = "" if @app_pathcut.nil?
        @app_sendto               = cfg["application"]["sendto"]
        @app_sendto = cfg["git"]["branch"] if @app_sendto.nil?
        @app_pathappend              = cfg["application"]["pathappend"]
        @app_pathappend = "" if @app_pathappend.nil?
      end
      if cfg["clearcase"] != nil
        @clearcase_view           = cfg["clearcase"]["view"]
        @clearcase_configspec     = cfg["clearcase"]["configspec"]
        @clearcase_branch         = cfg["clearcase"]["branch"]
        @clearcase_modified_map   = cfg["clearcase"]["modified_map"]
        @clearcase_output         = cfg["clearcase"]["output"]
      end
      if cfg["git"] != nil
        @git_remote_name          = cfg["git"]["repo_name"]
        @git_remote_stable_name   = cfg["git"]["stable_repo_name"]
        @git_bare_repo            = cfg["git"]["bare_repo"]
        @git_branch               = cfg["git"]["branch"]
        @git_stable_repo          = cfg["git"]["stable_repo"]
        @git_tag                  = cfg["git"]["tag"]
        @git_modified_files_map   = cfg["git"]["modified_files_map"]
        @git_added_files_map      = cfg["git"]["added_files_map"]
        @git_deleted_files_map    = cfg["git"]["deleted_files_map"]
        @git_output_folder        = cfg["git"]["output_folder"]
      end



    end

    def update_tag next_tag
      cfg = YAML.load_file(@path)
      cfg["git"]["tag"] = next_tag
      File.open(@path, 'w') do |f|
        f.puts cfg.to_yaml
      end
    end
  end
end