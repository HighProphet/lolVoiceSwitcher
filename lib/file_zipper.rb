require 'zip'
require 'fileutils'
require_relative 'simple_hook'
require 'logger'

class FileZipper
  def self.zip(target_name, source_paths, logger=Logger.new($stdout), quiet=false)
    mission = FileZipMission.new target_name, source_paths, logger
    mission.execute quiet
  end
  
  def self.unzip(source, dir=nil, quiet=false, logger=Logger.new($stdout))
    source = File.expand_path source
    if dir
      dir = File.expand_path dir
    else
      dir = File.expand_path("#{source}.d")
    end
    FileUtils.mkdir_p dir unless File.directory? dir
    archive = Zip::File.open(source)
    archive.each do |entry|
      puts "working on #{entry.name}" unless quiet
      logger.debug "Extracting #{entry.name}"
      file_name = File.join(dir, entry.name)
      dir_name = File.dirname file_name
      FileUtils.mkdir_p dir_name unless File.directory? dir_name
      entry.extract(file_name)
    end
    logger.debug "Finish extracting #{source}"
  end
  
  class FileZipMission
    
    attr_reader :completed
    
    # create a file zip mission in order to generate an archive
    # target_name: name of the zip file
    # source_paths: all the files you want to archive into the zip
    def initialize (target_name, source_paths, logger=Logger.new($stdout))
      @target_name = File.expand_path target_name
      @source_paths = source_paths.map! {|p| File.expand_path p}
      @completed = false
      @logger = logger
      @count = 0
    end
    
    # if you want to use additional files, invoke this before the mission execution
    def add_files(*files)
      @source_paths &= files
    end
    
    # execute the mission, archive the source files into the zip file
    def execute(quiet=false)
      @quiet = quiet
      @zip_file = ::Zip::File.open(@target_name, ::Zip::File::CREATE)
      do_zip(@source_paths, '')
      @zip_file.close
      @logger.debug("#{@count} files archived in #{@target_name}")
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
            puts "archive #{in_zip_path} into #{@target_name} from #{file}" unless @quiet
            os.write(File.open(file, 'rb').read)
            @count += 1
            @logger.debug("file: \"#{in_zip_path}\" archived")
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
end

