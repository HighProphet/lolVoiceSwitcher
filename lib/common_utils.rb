require 'open-uri'
require 'digest/md5'
class CommonUtils
  
  def self.copy_files(src_paths, dest_dir)
    src_paths.each do |src_name|
      File.open src_name do |s|
        dest_name = File.join(dest_dir, File.basename(src_name))
        File.open dest_name, 'wb' do |d|
          yield src_name, dest_name if block_given?
          IO.copy_stream s, d
        end
      end
    end
  end
  
  def self.download_files(src_urls, dest_dir)
    src_urls.each do |src_url|
      dest_file = File.join(dest_dir, File.basename(src_url))
      yield src_url, dest_file if block_given?
      download_file src_url, dest_file
    end
  end
  
  def self.download_file(src_url, dest_file=File.basename(src_url))
    dir = File.dirname dest_file
    unless File.directory? dir
      Dir.mkdir_p dir
    end
    ds = open(src_url)
    IO.copy_stream ds, dest_file
  end
  
  def self.md5_file(src)
    raise "#{src } is not a file" unless File.exist? src
    md5 = Digest::MD5.new
    file = File.open src, 'rb'
    while ((buf = file.read(65536))&& (buf.length > 0))
      md5.update buf
    end
    md5
  end
end