=begin
Class for executing basic clearcase commands in ruby scripts.
Atria cleartool is used for executing commands.

@Author:            Semerhanov Ilya
@Creation Date:     22.01.2013
@Last Update:       10.07.2013
@Company:           T-Systems CIS
=end

module ClearCase
class ClearCaseWrapper

  def initialize stdin, cleartool, configspec_folder
    @configspec_folder = configspec_folder
    @cleartool = cleartool
    @stdin = stdin
  end

  def prepare_environment
    @stdin.puts('export PATH="$PATH:/usr/atria/bin";')
    @stdin.puts('export NLS_LANG="GERMAN";')
    @stdin.puts('export CMHOME="/nethome/tmt508/v/vobadmin/ClearMobil";')
  end

  def setcs configspec
    @stdin.puts("#{@cleartool} setcs #{@configspec_folder}/#{configspec}")
  end

  def catcs
    @stdin.puts("#{@cleartool} catcs")
  end

  def checkout filepath
    @stdin.puts("#{@cleartool} co -unr -nc /vobs/#{filepath}")
  end

  def uncheckout filepath
    @stdin.puts("#{@cleartool} unco /vobs/#{filepath}")
  end

  def checkin filepath, comment, submiter
    cm = "#{comment}.\nSubmitted by #{submiter}. *Imported from GIT*"
    regex = /^Merge\s/
    if regex.match(cm)
      cm = "TMOad01515 #{cm}"
    end

    @stdin.puts("#{@cleartool} ci -c \"#{cm}\" /vobs/#{filepath}")
  end

  def update src, filepath, comment, submiter
    self.checkout(filepath)
    @stdin.puts("cp #{src} /vobs/#{filepath}")
    self.checkin(filepath, comment, submiter)
  end

  def uncheckout_all
    cmd = "#{@cleartool} lsco -cview -avobs | #{@cleartool} unco -rm `awk '{ print $(5) }' | sed -e 's/^\"*//' -e 's/ *\"$//'`"
    @stdin.puts(cmd)
  end

  def lshistory time, branch, vob, dir, filename, filter
    File.delete "#{filename}" if File.exist? "#{filename}"
    filter.split("|").each{|f|
      base = File.dirname f
      cmd = "cd #{vob}/#{base}; #{@cleartool} lshistory -sin #{time} -all -nco -fmt \"%e: %En | %u || %c\n\" -branch \"#{branch}\" | grep \"#{vob}/#{f}\" | grep \"create version:.*||\\sTM.*\" | tee -a ~/#{dir}/#{filename}"
      @stdin.puts(cmd)
    }

  end

  def lshistory2 time, branch, vob, dir, filename
    cmd = "#{@cleartool} lshistory -sin #{time} -nco -fmt \"%e: %En | %u || %c\n\" -branch \"#{branch}\" -recurse #{vob}/* | grep \"#{vob}/java\" | grep \"create version:.*||\\sTM.*\"  | grep -v \"CHECKEDOUT\" | tee ~/#{dir}/#{filename}"
    @stdin.puts(cmd)
  end

  def lsdirhistory time, branch, vob, dir, filename, filter
    filter.split("|").each{|f|
      base = File.dirname f
      cmd = "cd #{vob}/#{base}; #{@cleartool} lshistory -sin #{time} -nco -all -fmt \"%e: %En | %u || %c\n\" -branch \"#{branch}\" | grep \"#{vob}/#{f}\" | grep \"create directory version:.*\"  | tee -a ~/#{dir}/#{filename}"
      @stdin.puts(cmd)
    }
  end

  def lsdirhistory2 time, branch, vob, dir, filename
    cmd = "#{@cleartool} lshistory -sin #{time} -nco -fmt \"%e: %En | %u || %c\n\" -branch \"#{branch}\" -recurse #{vob}/* | grep \"#{vob}/java\" | grep \"create directory version:.*\"  | grep -v \"CHECKEDOUT\" | tee -a ~/#{dir}/#{filename}"
    @stdin.puts(cmd)
  end

  def import path, vob, comment, submiter, filename
    cm = "#{comment}. Add file: #{filename}\nSubmitted by #{submiter}. *Imported from GIT*"
    regex = /^Merge\s/
    if regex.match(cm)
      cm = "TMOad01515 #{cm}"
    end
    cmd = "clearfsimport -nsetevent -recurse -comment \"#{cm}\" #{path} #{vob}/eca_apps"
    @stdin.puts(cmd)
  end

  def remove path, filepath, comment, submiter
    cm = "#{comment}.\nSubmitted by #{submiter}. *Imported from GIT*"
    self.checkout(path)
    cmd = "#{@cleartool} rmname -c \"#{cm}\" /vobs/#{filepath}"
    @stdin.puts(cmd)
    self.checkin(path, comment, submiter)
  end

  def copy src, dst
    puts "Copying #{src} to #{dst}..."
    puts
    @stdin.puts("cp #{src} #{dst}")
    sleep 2
  end

  def copy_dir src, dst
    puts "Copying dir #{src} to #{dst}..."
    puts
    # @stdin.puts("#{@cleartool} co -unr -nc #{src}")
    @stdin.puts("cp -r #{src} #{dst}/../")
    #@stdin.puts("#{@cleartool} unco #{src}")
    @stdin.puts("find #{dst}/../ -type f -exec chmod 755 {} \\;")
    @stdin.puts("find #{dst}/../ -type f -exec chmod 644 {} \\;")
    sleep 2
  end


end
end
