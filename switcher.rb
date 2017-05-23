require 'fileutils'
require 'json'
require 'find'
require_relative 'persisted_config'
require_relative 'simple_hook'
require_relative 'file_zip_mission'
require_relative 'help_generator'

class Switcher
  VOICE_FILE_REGEX = /\w+audio.wpk/ # Analysis shows that this is the different file pattern
  CONFIG_DEFAULT = {version: '1.0', repository: 'http://ol2c7b167.bkt.clouddn.com/', backup: 'lol_voice_bak.zip'}
  
  def initialize
    @logger = Logger.new File.new('dev_log.txt', 'w+')
    @logger.debug('Program started...')
    @cfg_file_name = "#{Dir.pwd}/config.json"
    @cfg = PersistedConfig.new(@cfg_file_name, logger: @logger)
    check_essential_cfg
  end
  
  def run_program (*args)
    if args.length > 0
      process_arguments args
    else
      process_arguments ARGV
    end
    
    # do method invoke
    self.send(@opt[:opt])
  end
  
  private
  def check_essential_cfg
    CONFIG_DEFAULT.each_pair do |key, val|
      if @cfg[key].nil?
        @cfg[key] = val
      end
    end
  end
  
  def process_arguments (args)
    @args = args
    # @args.each_with_index do |arg, i|
    #   if arg =~ /^--(\w+)/
    #     @args[i]=$1
    #   end
    # end
    @opt = {}
    case @args[0]
      when '--config', 'c', 'config'
        @opt[:opt] = :config
        @opt[:cfg_args] = {}
        @args[1...@args.length].each do |arg|
          ary = arg.split('=')
          @opt[:cfg_args][ary[0].to_sym] = ary[1]
        end
      when '--backup', 'b', 'backup'
        @opt[:opt] = :backup
        @opt[:bkp_args] = {force: false, quiet: false}
        bkp_arg_map = {f: :force, q: :quiet}
        @args[1...@args.length].each do |arg|
          if arg =~ /^-(\w+)/
            $1.each_char do |c|
              c = c.to_sym
              if bkp_arg_map.has_key? c
                @opt[:bkp_args][bkp_arg_map[c]] = true
              end
            end
          elsif arg =~/^--(\w+)/ && @opt[:bkp_args].has_key?($1.to_sym)
            @opt[:bkp_args][$1.to_sym] = true
          elsif arg == @args.last
            @opt[:bkp_args][:file_name] = arg
          else
            puts "Can't resolve parameter \"#{arg}\",please check your expression"
          end
        end
      when 'schedule', 's'
        @opt[:opt] = :schedule
      else
        @opt[:opt] = :help
    end
  end
  
  # make local voice pack backup
  def backup
    # solve override problem
    if @cfg[:backup]
      while true
        print "Already have backup in archive \"#{@cfg[:backup]}\",override?(y/n)"
        opt = gets
        case opt
          when /^y/i
            break
          when /^n/i
            return
          else
            next
        end
      end
    end
    
    # do backup
  
  end
  
  def recover
  
  end
  
  def resolve_voice_file_list(strict=false)
    if @cfg[:local_files] && @cfg[:local_files].size > 0 && !strict
      return
    end
    while true
      if File.directory?(@cfg[:root]||'')
        @cfg[:local_files] = []
        @cfg[:local_files] = []
        Find.find @cfg[:root] do |path|
          if path =~ VOICE_FILE_REGEX
            @logger.debug "file search hit: #{path}"
            @cfg[:local_files] << path
          end
        end
        if @cfg[:local_files].size > 0
          return
        end
        puts "It seems that \"#{@cfg[:root]}\" is not the root of LoL client for the program can find no voice file!"
      end
      print 'LoL client root:'
      @cfg[:root] = gets
    end
  end
  
  def config
    @logger.debug 'Operation: config'
    candidates ={root: 'root_path', repo: 'repository'}
    @cfg[:cfg_args].each_key do |item|
      if candidates.has_key?(item)
        @logger.debug "setting [#{candidates[item]}] to \"#{@opt[:cfg_args][item]}\""
        @cfg[item] = @opt[:cfg_args][item]
      else
        raise "Cannot resolve config argument \"#{item}\"! \nThe rest config arguments will be abandoned"
      end
    end
  end
  
  def schedule
    case mode
      when nil
      
      when 'n', 'new'
      
      else
        puts "Can't resolve operation \"schedule #{mode}\""
    end
  end
  
  def exit(status)
    @cfg.stop_persistence
    super(status)
  end
  
  def help
    title = <<~HELP
      League of Legends Hero Voice Switcher v#{@cfg['version']} help
      this program downloads an en_US voice pack and switch into your lol client
    HELP
    operations = [
      {
        name: 'backup, b, --backup [options][file_name]',
        description: [
          'back up current client voice files into a zip file',
          'the backup file will be named by %file_name%',
          'if %file_name% isn\'t given,the program will decide to name it'
        ],
        sub_opr:
          [{
             name: %w(-f --force),
             description: 'suppress overwrite warnings'
            
           },
           {
             name: %w(-q --quiet),
             description: 'show no information'
           }
          
          ]
      },
      {
        name: %w(schedule s --schedule),
        description: [
          ''
        ]
      },
      {
        name: %w(config c --config),
        description:
          [
            'set program configs'
          ],
        sub_opr:
          [{
             name: 'root=<lol_root>',
             description: [
               'tell the program your lol client root path',
               'with which you want to substitute voice pack.'
             ]
           }, {
             name: 'repo=<repository>',
             description: [
               'change the repository from which the prog downloads voice pack',
               '*WARNING* use this ONLY if you are definitely sure'
             ]
            
           }]
      }, {
        name: %w(help h --help),
        description: [
          'show this text'
        ]
      }
    ]
    puts HelpGenerator.generate_help title, operations
  end
  
  
  Switcher.extend SimpleHook
  Switcher.do_after(:config, :schedule, :help, :backup) {|switcher| switcher.send(:exit, 0)}
  # Switcher.do_before(:backup, :recover) {|switcher| switcher.send(:resolve_voice_file_list)}

end

switcher = Switcher.new

switcher.run_program *'backup -fq test.zip'.split(' ')
# switcher.run_program 'help'