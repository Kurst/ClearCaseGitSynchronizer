=begin
Observer class for monitoring states of observables, such as conflicts in git log.

@Author:        Semerhanov Ilya
@Date:          18.06.2013
@Last Update:   24.06.2013
@Company:       T-Systems CIS
=end

module Monitoring
class EventMonitor

  def update(state,msg)
    if state == 1
      raise "***EVENT MONITOR: #{msg}***"
    end
    if state == 2
      puts "***EVENT MONITOR: #{msg}***"
    end
  end
end
end