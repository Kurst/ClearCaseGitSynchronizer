=begin
Observable class for empty folder monitoring.

@Author:        Semerhanov Ilya
@Date:          24.06.2013
@Last Update:   24.06.2013
@Company:       T-Systems CIS
=end
require 'observer'
require 'ftools'

module Monitoring
  class NoSync
    include Observable

    def parse(path,filename, id)
      f = File.new(path + filename)
      text = f.read
      if text =~ /Nothing to sync/
        changed
        notify_observers(2,"NOTHING TO SYNC FOR: #{id}")
        f.close
        return false
      end
      f.close
      return true
    end
  end
end