class HelpGenerator
  
  # arg operations example
  # [{name:['config','c','--config'], description:['first line', 'second line']}]
  def self.generate_help(title=nil, operations=[], ending=nil)
    str = StringIO.new
    str << "\n"
    str << "#{title}\n" if title
    operations.each do |opr|
      str << sprintf('%-25s', opr[:name].is_a?(Array) ? opr[:name].join(', ') : opr[:name])
      if opr[:description].is_a? Array
        opr[:description].each do |d|
          str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
          str << "#{d}\n"
        end
      else
        str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
        str << "#{opr[:description]}\n"
      end
      if opr[:sub_opr]
        opr[:sub_opr].each do |o|
          str << sprintf('  %-23s', o[:name].is_a?(Array) ? o[:name].join(', ') : o[:name])
          if o[:description].is_a? Array
            o[:description].each do |d|
              str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
              str << "#{d}\n"
            end
          else
            str << sprintf('%-25s', ' ') if str.string.end_with? "\n"
            str << "#{o[:description]}\n"
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
end