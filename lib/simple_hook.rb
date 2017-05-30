module SimpleHook
  
  def do_before(*methods, &block)
    do_when :before, *methods, &block
  end
  
  def do_after(*methods, &block)
    do_when :after, *methods, &block
  end
  
  def __method_chain(occasion, method, &block)
    @method_chain[occasion][method] = [] unless @method_chain[occasion][method]
    if block
      @method_chain[occasion][method] << block
    else
      @method_chain[occasion][method]
    end
  end
  
  def self.extended(base)
    base.instance_variable_set(:@method_chain, {before: {}, after: {}})
  end
  
  private
  def do_when(occasion, *methods, &block)
    raise 'No Block is given!' unless block_given?
    methods.each do |method|
      __method_chain occasion, method, &block
      original_method = "original_#{method}".to_sym
      unless method_defined?(original_method) || private_method_defined?(original_method)
        alias_method original_method, method
        define_method method do |*args, &block|
          before_chain = self.class.__method_chain(:before, method)
          before_chain.each do |blk|
            blk.call self, *args
          end
          result = send original_method, *args, &block
          after_chain = self.class.__method_chain(:after, method)
          after_chain.each do |blk|
            blk.call self, *args
          end
          result
        end
      end
    end
  end

end