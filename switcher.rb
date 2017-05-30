#!/bin/ruby
require 'fileutils'
require 'json'
require 'find'
require_relative 'lib/persisted_config'
require_relative 'lib/simple_hook'
require_relative 'lib/file_zipper'
require_relative 'lib/help_generator'
require_relative 'lib/common_utils'

class Switcher
  VOICE_FILE_REGEX = /\w+audio.wpk/ # Analysis shows that this is the different file pattern
  CONFIG_FILE_NAME = 'config/config.json'
  CONFIG_DEFAULT_FILE_NAME = 'config/config_default.json'
  CONFIG_INITIALIZED = {version: '1.0', repository: 'http://ol2c7b167.bkt.clouddn.com/', backup: 'data/lol_voice_bak', voice_pack: 'data/switcher_voice_pack'}
  
  def initialize
    log_dir = File.join(__dir__, 'log')
    Dir.mkdir log_dir unless File.directory? log_dir
    # @logger = Logger.new File.new(File.join(log_dir, "dev_log_#{Time.now.strftime('%Y_%m_%d_%H%M%S')}.txt"), 'w')
    @logger = Logger.new $stdout
    @logger.debug('Program started...')
    @cfg = PersistedConfig.new(File.join(__dir__, CONFIG_FILE_NAME), logger: @logger)
    @cfg_default = JSON.parse(File.read(File.join(__dir__, CONFIG_DEFAULT_FILE_NAME), encoding: 'UTF-8'), symbolize_names: true)
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
    CONFIG_INITIALIZED.each_pair do |key, val|
      if @cfg[key].nil?
        @cfg[key] = val
      end
    end
  end
  
  def process_arguments (args)
    @opt = {}
    case args[0]
      when '--config', 'c', 'config'
        @opt[:opt] = :config
        @opt[:cfg_args] = {}
        args[1...args.length].each do |arg|
          ary = arg.split('=')
          @opt[:cfg_args][ary[0].to_sym] = ary[1]
        end
      when '--backup', 'b', 'backup'
        @opt[:opt] = :backup
        @opt[:bkp_args] = {force: false, quiet: false}
        bkp_arg_map = {f: :force, q: :quiet}
        args[1...args.length].each do |arg|
          if arg =~ /^-(\w+)/
            $1.each_char do |c|
              c = c.to_sym
              if bkp_arg_map.has_key? c
                @opt[:bkp_args][bkp_arg_map[c]] = true
              end
            end
          elsif arg =~/^--(\w+)/ && @opt[:bkp_args].has_key?($1.to_sym)
            @opt[:bkp_args][$1.to_sym] = true
          else
            puts "Can't resolve parameter \"#{arg}\",please check your expression"
          end
        end
      when 'recover', 'r', '--recover'
        @opt[:opt] = :recover
        @opt[:rcvr_args] = {quiet: false}
        if args[1] == '-q'
          @opt[:rcvr_args][:quiet] = true
        end
      when 'switch', 's', '--switch'
        @opt[:opt] = :switch
        @opt[:voice_pack_files] = Dir.entries(File.join(__dir__, @cfg[:voice_pack])) - %w(. ..)
      when 'update', 'u', '--update'
        @opt[:opt] = :update
        @opt[:upd_args] = {}
        upd_arg_map = {:l => :latest, :s => :system, :v => :voice_pack}
        args[1...args.length].each do |arg|
          if arg =~ /^-(\w+)/
            $1.each_char do |c|
              c = c.to_sym
              if upd_arg_map.has_key? c
                @opt[:upd_arg_map][upd_arg_map[c]] = true
              end
            end
          elsif (arg =~ /^--(\w+)/) && (upd_arg_map.has_value? $1)
            @opt[:upd_arg_map][$1] = true
          end
        end
        # update the voice pack by default
        unless @opt[:upd_arg_map][:system]
          @opt[:upd_arg_map][:voice_pack] = true
        end
      when 'plan', 'p', '--plan'
        @opt[:opt] = :plan
      else
        @opt[:opt] = :help
    end
  end
  
  # make local voice pack backup
  def backup
    # solve override problem
    if backup_exist? && !@opt[:bkp_args][:quiet]
      while true
        print "Already have backup in #{@cfg[:backup]},override?(y/n)"
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
    FileUtils.mkdir_p @cfg[:backup] unless File.directory? @cfg[:backup]
    CommonUtils.copy_files @cfg[:local_files], File.join(__dir__, @cfg[:backup]) do |src, dest|
      @logger.debug "Copying #{src} to #{dest}"
      puts "Backup: #{File.basename src}" unless @opt[:bkp_args][:quiet]
    end
    @logger.debug('Backup completed')
    puts "Backup completed, saved in: #{@cfg[:backup]}" unless @opt[:bkp_args][:quiet]
  end
  
  def switch
  
  end
  
  def recover
    unless backup_exist?
      puts 'ERROR! Cannot find backup files'
      return
    end
    @cfg[:local_files].each do |file|
      basename = File.basename file
      puts "recovering #{basename}" unless @opt[:rcvr_args][:quiet]
      @logger.debug "Copying #{basename}"
      FileUtils.cp File.join(@cfg[:backup], basename), file
    end
    puts 'Recovery completed'
    @logger.debug 'Recovery completed'
  end
  
  # tell the backup files' existence
  def backup_exist?
    abs_path = File.join(__dir__, @cfg[:backup])
    if File.directory?(abs_path) && Dir.entries(abs_path).size > 200
      true
    end
    false
  end
  
  # Ensure the program has voice pack downloaded
  # if +strict+ the program downloads the latest voice pack
  def resolve_voice_pack(strict=false)
    @opt[:upd_args][:voice_pack] = true
    do_update if strict
    unless voice_pack_exist?
      do_update
    end
  end
  
  # tell the voice pack files' existence
  def voice_pack_exist?(thoroughly=true)
    manifest = JSON.parse(File.read(File.join(__dir__, @cfg[:voice_pack][:manifest])), symbolize_names: true)
    if thoroughly
      # -3 means a exception of '.','..' and manifest.json itself
      manifest[:files].length == Dir.entries(__dir__, @cfg[:voice_pack][:storage]).length - 3
    else #strictly
      manifest[:files].each do |file|
        file_path = File.join(__dir__, file[0])
        @logger.debug "Checking #{file_path} record"
        calc_md5 = CommonUtils.md5_file(file_path)
        unless file[1] == calc_md5
          @logger.error "MD5 mismatched on #{file_path},recorded: #{file[1]},calculated: #{calc_md5}"
          return false
        end
      end
      true
    end
  end
  
  def do_update
    manifest_local = File.join(@cfg[:voice_pack][:storage], @cfg[:voice_pack][:manifest])
    CommonUtils.download_file(File.join(@cfg[:repository], @cfg[:voice_pack][:manifest]), manifest_local)
    manifest = JSON.parse(manifest_local)
    
    # count update versions
    if @opt[:upd_args][:latest]
      @opt[:upd_args][:versions] = 'latest_full'
    else
      cur_pos = manifest[:versions].index @cfg[:voice_pack][:version]
      @opt[:upd_args][:versions] = manifest[:versions][cur_pos+1..-1]
    end
    
    # update each version
    @logger.debug "#{@opt[:upd_args][:versions].length} version(s) to upgrade"
    voice_manifest = File.join(__dir__, @cfg[:voice_pack][:manifest])
    if File.exist?(voice_manifest) && @opt[:upd_args][:voice_pack]
      voice_manifest = JSON.parse(voice_manifest, symbolize_names: true)
    end
    @opt[:upd_args][:versions].each do |version|
      %w(system voice_pack).each do |type|
        @logger.debug "Downloading version #{version} #{type} files"
        if @opt[:upd_args][type.to_sym]
          manifest[version][type].each do |file|
            file_url = File.join(@cfg[:repository], file['name'])
            file_path = File.join(__dir__, @cfg[:update_dir], file['name'])
            3.times do |i|
              CommonUtils.download_file(file_url, file_path)
              calculated_md5 = CommonUtils.md5_file file_path
              if calculated_md5 == file['md5']
                if type=='voice_pack'
                  voice_manifest[:files] << file
                end
                break
              elsif i < 2
                @logger.error "Different md5 between #{file['name']} and record, trying again"
              else
                @logger.error "Error happened downloading #{file['name']}, program shutdown"
                Kernel.exit(0)
              end
            end
          end
        end
      end
      if @opt[:upd_args][:voice_pack]
        voice_manifest['version'] = version
      end
    end
    if @opt[:upd_args][:system]
      updates = File.join(__dir__, @cfg[:update_dir], 'switcher')
      FileUtils.cp(updates, File.join(__dir__, '..'))
    end
    if @opt[:upd_args][:voice_pack]
      File.open(File.join(__dir__, @cfg[:voice_pack][:manifest])) do |f|
        f.puts JSON.pretty_generate(voice_manifest)
      end
      voice_manifest['files'].each do |file|
        File.cp(file[0], File.join(@cfg[:voice_pack][:storage], file[0]))
      end
    end
  end
  
  # Ensure the local voice file paths are in @cfg[:local_files]
  def resolve_local_files(strict=false)
    if @cfg[:local_files] && @cfg[:local_files].size > 0 && !strict
      return
    end
    while true
      if File.directory?(@cfg[:root]||'')
        @cfg[:local_files] = []
        @cfg.pause_persistence do
          Find.find @cfg[:root] do |path|
            if path =~ VOICE_FILE_REGEX
              @logger.debug "file search hit: #{path}"
              @cfg[:local_files] << path
            end
          end
        end
        if @cfg[:local_files].size > 0
          return
        end
        puts "It seems that \"#{@cfg[:root]}\" is not the root of LoL client for the program can find no voice file!"
      end
      print 'LoL client root:'
      @cfg[:root] = gets
      next
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
  
  def update
    if @opt[:upd_args][:system]
    
    else #update voice pack
      resolve_voice_pack true
    end
  end
  
  def plan
    case mode
      when nil
      
      when 'n', 'new'
      
      else
        puts "Can't resolve operation \"schedule #{mode}\""
    end
  end
  
  def exit(status)
    @cfg.stop_persistence
    @logger.debug 'Program exiting..'
    if @opt[:upd_on_exiting]
      FileUtils.cp_r File.join(__dir__, @cfg[:update_dir], 'switcher'), File.join(__dir__, '..')
    end
    super(status)
  end
  
  def help
    title = <<~HELP
      League of Legends Hero Voice Switcher v#{@cfg[:version]} help
      this program downloads an en_US voice pack and switch into your lol client
    HELP
    operations = [
      {
        name: 'backup, b, --backup [options]',
        description: 'back up current client voice files into %lol_root%/voice_backup',
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
        name: %w(switch s --switch),
        description: 'switch the local lol voice pack to en_US'
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
      },
      {
        name: %w(update u --update),
        description: [
          'update the program files incrementally',
          'it will only update voice packs by default'
        ],
        sub_opr: [
          {
            name: %w(-s --system),
            description: 'update the program itself'
          },
          {
            name: %w(-v --voice_pack),
            description: 'update the voice pack'
          },
          {
            name: %w(-l --latest),
            description: [
              'directly download the latest full package',
              '*ATTENTION* Downloading the whole program with voice pack takes a long time'
            ]
          }
        ]
      },
      {
        name: %w(help h --help),
        description: [
          'show this text'
        ]
      }
    ]
    puts HelpGenerator.generate_help title, operations
  end
  
  Switcher.extend SimpleHook
  Switcher.do_after(:config, :switch, :help, :backup) {|switcher| switcher.send(:exit, 0)}
  Switcher.do_before(:backup, :recover) {|switcher| switcher.send(:resolve_local_files)}
  Switcher.do_before(:switch) {|switcher| switcher.send(:resolve_voice_pack)}

end

switcher = Switcher.new

switcher.run_program *'help'.split(' ')
# switcher.run_program ARGV