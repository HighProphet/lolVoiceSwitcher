require 'zip'
require 'fileutils'

class FileZipMission
  
  def initialize (target_name=nil, source_names=[], output_dir=Dir.pwd)
    @target_name = target_name
    @source_names = source_names
    @output_dir = output_dir
    @completed = false
  end
  
  def start
    if @completed
      puts 'The mission is completed already!'
      return
    end
    @zip_file = Zip::File.open(File.join(@output_dir, @target_name), Zip::File::CREATE)
    puts @zip_file
    do_zip(@source_names, '')
  end
  
  def do_zip(files, path)
    files.each do |file|
      in_zip_path = path=='' ? file : File.join(path, file)
      abs_path = File.join(@output_dir, in_zip_path)
      if File.directory? abs_path
        @zip_file.mkdir in_zip_path
        sub_files = Dir.entries(abs_path) - %w(. ..)
        do_zip sub_files, in_zip_path
      else
        @zip_file.get_output_stream(in_zip_path) do |os|
          puts "writing #{in_zip_path} into #{@target_name}"
          os.write(File.open(abs_path, 'rb').read)
        end
      end
    end
  end

end