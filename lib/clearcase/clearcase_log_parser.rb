=begin
Class for parsing output file of clearcase lshistory.
The output must be formated	in a correct way.

Parser will return multiple hash with array.

@Author:          Semerhanov Ilya
@Create Date:     31.01.2013
@Last Update:     24.04.2013
@Company:         T-Systems CIS
=end

module ClearCase
class ClearCaseLogParser

  FILEPATH_REGEXP = /^create version:\s(.*)\s[|]{1}.*[|]{2}/
  DIR_REGEXP = /^create directory version:\s(.*)\s[|]{1}.*[|]{2}/
  COMMENT_REGEXP = /[|]{2}\s(TM.*)$/
  USER_REGEXP = /[|]{1}\s(.*)\s[|]{2}/

  def initialize path
    raise ArgumentError unless File.exists?(path)
    @file = File.open(path)
  end

  def process
    path = ""
    comment = ""
    user = ""
    items = Hash.new

    @file.each_line do |line|
      if line.match(COMMENT_REGEXP) != nil && line.match(FILEPATH_REGEXP) != nil
        line.sub(FILEPATH_REGEXP) { path = $1 }
        line.sub(COMMENT_REGEXP) { comment = $1 }
        line.sub(USER_REGEXP) { user = $1 }
        if path.length > 0
          items[user] ||= Hash.new # putting values in Hash => Hash => Array
          items[user][comment] ||= Array.new
          path = path.gsub('\\', '/')
          items[user][comment] << path.chomp
        end
      end
    end
    return items
  end


  def process_dir
    path = ""
    comment = ""
    user = ""
    items = Hash.new

    @file.each_line do |line|
      if line.match(DIR_REGEXP) != nil
        line.sub(DIR_REGEXP) { path = $1 }
        line.sub(COMMENT_REGEXP) { comment = $1 }
        line.sub(USER_REGEXP) { user = $1 }
        if path.length > 0
          items[user] ||= Hash.new # putting values in Hash => Hash => Array
          items[user][comment] ||= Array.new
          path = path.gsub('\\', '/')
          items[user][comment] << path.chomp
        end
      end
    end
    return items
  end
end
end