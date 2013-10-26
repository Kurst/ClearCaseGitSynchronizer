=begin
Observable class for conflict monitoring.

@Author:        Semerhanov Ilya
@Date:          18.06.2013
@Last Update:   10.07.2013
@Company:       T-Systems CIS
=end
require 'observer'
require 'ftools'

module Monitoring
  class Conflict
    include Observable

    def parse(path,filename)
      f = File.new(path + filename)
      text = f.read
      if text =~ /CONFLICT/
        if File.exist? path + "conflict.lock"
          changed
          notify_observers(1,"CONFLICT WAS DISCOVERED")
        else
          File.open(path + "conflict.lock", "w") { |f|
            time = Time.now
            f.puts time
          }
          changed
          notify_observers(1,"CONFLICT WAS DISCOVERED")
        end
      end
      f.close
    end

    def check_lock(path)
      if File.exist? path + "/../conflict.lock"
        changed
        notify_observers(1,"CONFLICT LOCK DETECTED")
      end
    end

    def create_lock(path)
      File.open(path, "w") { |f|
        time = Time.now
        f.puts time
      }
    end

  end
end