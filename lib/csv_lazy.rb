class Csv_lazy
  include Enumerable
  
  def initialize(args, &blk)
    @args = {
      :quote_char => '"',
      :row_sep => "\n",
      :col_sep => ";"
    }.merge(args)
    
    @io = @args[:io]
    @eof = false
    @buffer = ""
    @debug = @args[:debug]
    #@debug = true
    
    accepted = [:quote_char, :row_sep, :col_sep, :io]
    @args.each do |key, val|
      if accepted.index(key) == nil
        raise "Unknown argument: '#{key}'."
      end
    end
    
    raise "No ':quote_char' was given." if @args[:quote_char].to_s.strip.empty?
    raise "No ':col_sep' was given." if @args[:col_sep].to_s.strip.empty?
    raise "No ':row_sep' was given." if @args[:row_sep].to_s.empty?
    raise "No ':io' was given." if !@args[:io]
    
    @regex_begin_quote_char = /\A\s*#{Regexp.escape(@args[:quote_char])}/
    
    @regex_row_end = /\A\s*?#{Regexp.escape(@args[:row_sep])}/
    @regex_colsep_next = /\A#{Regexp.escape(@args[:col_sep])}/
    
    @regex_read_until_quote_char = /\A(.*?)#{Regexp.escape(@args[:quote_char])}/
    @regex_read_until_col_sep = /\A(.*?)#{Regexp.escape(@args[:col_sep])}/
    @regex_read_until_row_sep = /\A(.+?)#{Regexp.escape(@args[:row_sep])}/
    @regex_read_until_end = /\A(.+?)\Z/
    
    self.each(&blk) if blk
  end
  
  #Yields each row as an array.
  def each
    while row = read_row
      yield(row)
    end
  end
  
  private
  
  #Reads more content into the buffer.
  def read_buffer
    read = @io.read(4096)
    if !read
      @eof = true
    else
      @buffer << read
    end
  end
  
  #Returns the next row.
  def read_row
    @row = []
    while !@eof or !@buffer.empty?
      break if !read_next_col
    end
    
    row = @row
    @row = nil
    
    puts "csv_lazy: Row: #{row}\n\n" if @debug
    
    if row.empty?
      return false
    else
      return row
    end
  end
  
  #Runs a regex against the buffer. If matched it also removes it from the buffer.
  def read_remove_regex(regex)
    if match = @buffer.match(regex)
      oldbuffer = @buffer
      @buffer = @buffer.gsub(regex, "")
      
      if @debug
        print "csv_lazy: Regex: #{regex.to_s}\n"
        print "csv_lazy: Match: #{match.to_a}\n"
        print "csv_lazy: Buffer before: #{oldbuffer}\n"
        print "csv_lazy: Buffer after: #{@buffer}\n"
        print "\n"
      end
      
      raise "Buffer was the same before regex?" if oldbuffer == @buffer
      return match
    end
    
    return false
  end
  
  #Adds the next column to the row. Returns true if more columns should be read or false if this was the end of the row.
  def read_next_col
    read_buffer if @buffer.length < 4096
    return false if @buffer.empty? and @eof
    
    if @buffer.empty? or read_remove_regex(@regex_row_end)
      return false
    elsif match = read_remove_regex(@regex_begin_quote_char)
      read = ""
      
      loop do
        match_read = read_remove_regex(@regex_read_until_quote_char)
        if !match_read
          read_buffer
        else
          @row << match_read[1]
          break
        end
      end
      
      read_buffer if @buffer.length < 4096
      
      if read_remove_regex(@regex_colsep_next)
        return true
      elsif @eof and @buffer.empty?
        puts "csv_lazy: End-of-file and empty buffer." if @debug
        return false
      elsif read_remove_regex(@regex_row_end)
        puts "csv_lazy: Row-end found." if @debug
        return false
      else
        raise "Dont know what to do (#{@buffer.length}): #{@buffer}"
      end
    elsif match = read_remove_regex(@regex_read_until_col_sep)
      @row << match[1]
      return true
    elsif match = read_remove_regex(@regex_read_until_row_sep)
      puts "csv_lazy: Row seperator reached." if @debug
      @row << match[1]
      return false
    elsif match = read_remove_regex(@regex_read_until_end)
      if @eof
        @row << match[1]
        return false
      end
      
      @buffer << match[0]
      read_buffer
      raise Csv_lazy::Retry
    else
      raise "Dont know what to do with buffer: #{@buffer}"
    end
  rescue Csv_lazy::Retry
    retry
  end
end

class Csv_lazy::Retry < RuntimeError

end