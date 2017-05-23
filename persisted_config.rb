require 'json'
require_relative 'simple_hook.rb'
require 'logger'

# Persist a JSON Object into a File
# run persist proc every 0.05 seconds by default
class PersistedConfig
  
  def initialize(file_name, default_data: {}, auto_start: true, interval: 0.05, logger: Logger.new($stdout))
    @p_mtx = Mutex.new
    @data = {}
    @cfg_file_name = file_name
    @interval = interval
    @logger = logger
    if File.file?(@cfg_file_name) && File.size?(@cfg_file_name)
      json = JSON.parse(File.read(@cfg_file_name))
      @data.merge! json
    end
    merge! default_data
    start_persistence if auto_start
  end
  
  def start_persistence
    raise 'Persistence already started...' if @handler
    @running = true
    @handler = Thread.start do
      @logger.debug 'Persistence handler is running...'
      while @running || @updated
        wait_count = 0
        sync do
          if @updated
            if @wait
              @wait = false
              @logger.debug 'still updating, wait...'
            else
              @logger.debug "writing config: #{@data}"
              file = File.open(@cfg_file_name, 'w')
              file.puts @data.to_json
              file.close
              @logger.debug 'persistence completed...'
              @updated = false
            end
          else
            if wait_count == 100
              @logger.debug 'nothing changed, handler vacant...'
              wait_count = 0
            else
              wait_count += 1
            end
          end
        end
        sleep @interval
      end
      @logger.debug('Persistence handler stopped...')
    end
  end
  
  def stop_persistence
    @running = false
    @handler.join if @handler
    @handler = nil
  end
  
  def bind(file_name)
    @cfg_file_name = file_name
  end
  
  def bound_file
    @cfg_file_name
  end
  
  def [](key)
    @data[key]
  end
  
  def delete(*args)
    out = nil
    sync {out = @data.delete *args}
    out
  end
  
  def []=(key, value)
    out = nil
    sync {out = @data.store(key, value)}
    out
  end
  
  def merge! (*args)
    out = nil
    case args[0]
      when Hash
        sync {out = @data.merge! *args}
      when PersistedConfig
        sync {out = @data.merge! args[0].data}
      else
        raise "Cannot merge with #{args[0].class} instance: #{args[0]}"
    end
    out
  end
  
  #-------------private methods-----------
  private
  def content_changed
    @logger.debug 'content changed...'
    sync do
      @updated = true
      @wait = true
    end
  end
  
  def data
    @data
  end
  
  def sync(mutex=@p_mtx)
    if block_given?
      mutex.lock
      begin
        yield
      ensure
        mutex.unlock
      end
    end
  end
  
  #-----------------private end---------------------
  
  # Add trigger to wake the persistence thread up to work
  PersistedConfig.extend SimpleHook
  PersistedConfig.do_after :[]=, :delete, :merge! do |config|
    config.send(:content_changed)
  end
end