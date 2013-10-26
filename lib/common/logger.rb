=begin
Simple singleton class for logging.

@Author:        Semerhanov Ilya
@Date:          05.06.2013
@Last Update:   24.06.2013
@Company:       T-Systems CIS
=end

require 'logger'
module Common
  class LOGGER

    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::DEBUG
    proc = @@logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{severity}] #{msg}\n"
    end

    def self.debug(x)
      @@logger.debug(x)
    end

    def self.info(x)
      @@logger.info(x)
    end

    def self.error(x)
      @@logger.error(x)
    end

    def self.fatal(x)
      @@logger.fatal(x)
    end

  end
end