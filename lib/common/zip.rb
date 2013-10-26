=begin
Class for zipping into archives

@Author:        Semerhanov Ilya
@Date:          20.01.2013
@Last Update:   20.01.2013
@Company:       T-Systems CIS
=end
require 'rubygems'
require 'zip/zip'
require 'find'
require 'ftools'

module Common
  class Zipper

    def self.zip(dir, zip_dir, remove_after = false)
      Zip::ZipFile.open(zip_dir, Zip::ZipFile::CREATE) do |zipfile|
        Find.find(dir) do |path|
          Find.prune if File.basename(path)[0] == ?.
          dest = /#{dir}\/(\w.*)/.match(path)
          begin
            zipfile.add(dest[1], path) if dest
          rescue Zip::ZipEntryExistsError
          end
        end
      end
      `rm -rf "#{dir}"` if remove_after
    end

    def self.unzip(zip, unzip_dir, remove_after = false)
      Zip::ZipFile.open(zip) do |zip_file|
        zip_file.each do |f|
          f_path=File.join(unzip_dir, f.name)
          File.makedirs(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        end
      end
      `rm -rf "#{zip}"` if remove_after
    end

    def self.open_one(zip_source, file_name)
      Zip::ZipFile.open(zip_source) do |zip_file|
        zip_file.each do |f|
          next unless "#{f}" == file_name
          file = File.new('out.txt', 'w')
          file.write f.get_input_stream.read
          return f.get_input_stream.read
        end
      end
      nil
    end
  end
end