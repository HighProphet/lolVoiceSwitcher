module SimpleHook
  def do_before(*methods, &block)
    do_when :before, *methods, &block
  end
  
  def do_after(*methods, &block)
    do_when :after, *methods, &block
  end
  
  def do_when(occasion, *methods)
    raise 'No Block is given!' unless block_given?
    methods.each do |method|
      alias_method "old_#{method}", method
      define_method method do |*args, &block|
        yield(self, *args) if occasion == :before
        result = send "old_#{method}", *args, &block
        yield(self, *args) if occasion == :after
        result
      end
    end
  end
end