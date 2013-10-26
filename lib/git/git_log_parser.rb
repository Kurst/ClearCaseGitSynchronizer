=begin
Class for parsing output file of git log script. 
The output must be formated	in a correct way.

Parser will return multiple hash with array.

@Author:  Semerhanov Ilya
@Date:    30.12.2012
@Company: T-Systems CIS
=end

module Git
  class GitLogParser

    SUBMITTER_REGEXP = /^Submitter.*?:\s(.*)\s[|][|]\s/
    COMMENT_REGEXP = /Comment.*?:\s(.*)$/

    def initialize path
      raise ArgumentError unless File.exists?(path)
      @file = File.open(path)
    end

    def process
      submitter = ""
      comment = ""
      items = Hash.new

      @file.each_line do |line|
        if (line.match(SUBMITTER_REGEXP) != nil)
          line.sub(SUBMITTER_REGEXP) { submitter = $1 }
          line.sub(COMMENT_REGEXP) { comment = $1 }
          items[submitter] ||= Hash.new # putting values in Hash => Hash => Array
          items[submitter][comment] ||= Array.new
        elsif /\S/ =~ line # checking for empty line
          line = line.gsub('\\', '/')
          items[submitter][comment] << line.chomp
        end
      end
      return items
    end
  end
end