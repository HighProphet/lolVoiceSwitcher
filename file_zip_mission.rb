require 'zip'
require 'fileutils'
require_relative 'simple_hook'

class FileZipMission
  
  attr_reader :completed
  
  # create a file zip mission in order to generate an archive
  # target_name: name of the zip file
  # source_paths: all the files you want to archive into the zip
  def initialize (target_name=nil, source_paths=[])
    @target_name = File.expand_path target_name
    @source_paths = source_paths.map! {|p| File.expand_path p}
    @completed = false
  end
  
  # if you want to use additional files, invoke this before the mission execution
  def add_files(*files)
    @source_paths &= files
  end
  
  # execute the mission, archive the source files into the zip file
  def execute
    @zip_file = ::Zip::File.open(@target_name, ::Zip::File::CREATE)
    puts @zip_file
    do_zip(@source_paths, '')
    @zip_file.close
  end
  
  def do_zip(files, path)
    files.each do |file|
      in_zip_path = path=='' ? File.basename(file) : File.join(path, File.basename(file))
      if File.directory? file
        @zip_file.mkdir in_zip_path
        sub_files = (Dir.entries(file) - %w(. ..))
        sub_files.each_index {|i| sub_files[i]= File.join(file, sub_files[i])}
        do_zip sub_files, in_zip_path
      else
        @zip_file.get_output_stream(in_zip_path) do |os|
          puts "archive #{in_zip_path} into #{@target_name} from #{file}"
          os.write(File.open(file, 'rb').read)
        end
      end
    end
  end
  
  extend SimpleHook
  FileZipMission.do_before :execute, :add_files do |mission|
    if mission.completed
      puts 'The mission is completed already!'
      break
    end
  end

end