require 'fileutils'
require 'json'
require './persisted_config.rb'
require './simple_hook.rb'
require 'find'
require './file_zipper.rb'

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
    CONFIG_DEFAULT.each_with_index do |val, key|
      if @cfg[key].nil?
        @cfg[key] = val
      end
    end
  end
  
  def process_arguments (args)
    @args = args
    @args.each_with_index do |arg, i|
      if arg =~ /^--(\w+)/
        @args[i]=$1
      end
    end
    @opt = {}
    case @args[0]
      when 'config', 'c'
        @opt[:opt] = :config
        @opt[:cfg_args] = {}
        @args[1..@args.length].each do |arg|
          ary = arg.split('=')
          @opt[:cfg_args][ary[0].to_sym] = ary[1]
        end
      when 'schedule', 's'
        @opt[:opt] = :schedule
      when 'backup', 'b'
        @opt[:opt] = :backup
      else
        @opt[:opt] = :help
    end
  end
  
  def backup
    File.join
  end
  
  def recover
  
  end
  
  def resolve_voice_file_list
    if File.directory?(@cfg[:root])
      @client_voice_file_list = []
      Find.find @cfg[:root] do |path|
        @client_voice_file_list << path if path =~ VOICE_FILE_REGEX
      end
    else
      print 'Cannot find lol client.lol client root:'
      @cfg[:root] = gets
      resolve_voice_file_list
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
        name: %w(schedule s --schedule),
        description: [
          ''
        ]
      },
      {
        name: %w(config c --config),
        description: [
          'set program configs'
        ],
        sub_opr: [{
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
    puts generate_help title, operations
  end
  
  
  # arg operations example
  # [{name:['config','c','--config'], description:['first line', 'second line']}]
  def generate_help(title=nil, operations=[], ending=nil)
    str = StringIO.new
    str << "\n"
    str << "#{title}\n" if title
    operations.each do |opr|
      str << sprintf('%-25s', opr[:name].join(', '))
      opr[:description].each do |d|
        str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
        str << "#{d}\n"
      end
      if opr[:sub_opr]
        opr[:sub_opr].each do |o|
          str << sprintf('  %-23s', o[:name])
          o[:description].each do |d|
            str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
            str << "#{d}\n"
          end
        end
      end
      str << "\n"
    end
    str << "\n"
    str << "#{ending}\n" if ending
    str << "\n"
    str.string
  end
  
  Switcher.extend SimpleHook
  Switcher.do_after(:config, :schedule, :help) {|switcher| switcher.send(:exit, 0)}
  Switcher.do_before(:backup, :recover) {|switcher| switcher.send(:resolve_voice_file_list)}

end

switcher = Switcher.new

# switcher.run_program *'config root=G:/Games/英雄联盟'.split(' ')
switcher.run_program 'help'