#encoding: utf-8

require "rubygems"
require "string-strtr"

#A simple library for parsing CSV-files through IO's. Solves corrupt file formats automatically like when files contains several spaces after a column and more.
class CsvLazy
  include Enumerable

  #===Examples
  #  File.open("csvfile.csv", "r") do |fp|
  #    CsvLazy.new(io: fp, quote_char: '"', col_sep: ";", row_sep: "\n", encode: "utf-8") do |row_array|
  #      puts "Row: #{row_array}"
  #    end
  #  end
  def initialize(args = {}, &blk)
    @args = {
      quote_char: '"',
      row_sep: "\n",
      col_sep: ";",
      headers: false,
      buffer_length: 4096
    }.merge(args)

    @io = @args[:io]
    @eof = false
    @buffer = ""
    @debug = @args[:debug]
    @encode = @args[:encode]
    @mutex = Mutex.new
    @buffer_length = @args[:buffer_length]
    @escape_char = "\\"
    @escaped_quote = "#{@escape_char}#{@args[:quote_char]}"
    @escaped_quote_double = "#{@escape_char}#{@escape_char}#{@args[:quote_char]}"

    #@debug = true

    accepted = [:encode, :quote_char, :row_sep, :col_sep, :io, :debug, :headers, :buffer_length]
    @args.each do |key, val|
      raise "Unknown argument: '#{key}'." unless accepted.include?(key)
    end

    raise "No ':quote_char' was given." if @args[:quote_char].to_s.strip.empty?
    raise "No ':col_sep' was given." if @args[:col_sep].to_s.empty?
    raise "No ':row_sep' was given." if @args[:row_sep].to_s.empty?
    raise "No ':io' was given." unless @args[:io]

    @regex_begin_quote_char = /\A\s*#{Regexp.escape(@args[:quote_char])}/

    @regex_row_end = /\A\s*?#{Regexp.escape(@args[:row_sep])}/
    @regex_colsep_next = /\A#{Regexp.escape(@args[:col_sep])}/

    @regex_read_until_quote_char = /\A(.*?)#{Regexp.escape(@args[:quote_char])}/
    @regex_read_until_col_sep = /\A(.*?)#{Regexp.escape(@args[:col_sep])}/
    @regex_read_until_row_sep = /\A(.+?)#{Regexp.escape(@args[:row_sep])}/
    @regex_read_until_end = /\A(.+?)\Z/

    if @args[:headers]
      headers = []
      read_row.each do |key|
        headers << key.to_sym
      end

      @headers = headers
    end

    self.each(&blk) if blk
  end

  #Yields each row as an array.
  def each
    if block_given?
      @mutex.synchronize do
        while row = read_row
          yield(row)
        end
      end
    else
      Enumerable.new do |yielder|
        @mutex.synchronize do
          while row = read_row
            yielder << row
          end
        end
      end
    end
  end

  #Returns the next row.
  def read_row
    @row = []
    while !@eof || !@buffer.empty?
      break unless read_next_col
    end

    row = @row
    @row = nil

    puts "csv_lazy: Row: #{row}\n\n" if @debug

    if row.empty? && @eof
      return false
    else
      if @headers
        ret = {}
        row.length.times do |count|
          ret[@headers[count]] = row[count]
        end

        return ret
      else
        return row
      end
    end
  end

private

  #Reads more content into the buffer.
  def read_buffer
    while @buffer.length < @buffer_length && !@eof
      read = @io.gets

      if read == nil
        @eof = true
      else
        read = read.encode(@encode) if @encode
        @buffer << read
      end
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

  def unescape(str)
    return str.strtr(
      "\\\\" => "\\",
      "\\t" => "\t",
      "\\n" => "\n",
      "\\r" => "\r",
      "\\\"" => "\""
    )
  end

  #Adds the next column to the row. Returns true if more columns should be read or false if this was the end of the row.
  def read_next_col
    read_buffer if @buffer.length < @buffer_length
    return false if @buffer.empty? && @eof

    if @buffer.empty? || read_remove_regex(@regex_row_end)
      return false
    elsif match = read_remove_regex(@regex_begin_quote_char)
      read = ""
      col_content = ""

      loop do
        if read_until_quote_and_end
          break
        elsif match_read = read_remove_regex(@regex_read_until_quote_char)
          all = match_read[0]
          escaped_quote_char = all[-@escaped_quote.length, @escaped_quote.length]
          double_escaped_quote_char = all[-@escaped_quote_double.length, @escaped_quote_double.length]
          all_without_quote = match_read[1]

          if escaped_quote_char == @escaped_quote && double_escaped_quote_char != @escaped_quote_double
            #continue reading - the quote char is escaped.
            col_content << all
          else
            col_content << match_read[1]
            add_col(unescape(col_content))
            break
          end
        else
          if @eof
            add_col(@buffer) unless @buffer.empty?
            @buffer = ""
            break
          else
            read_buffer
          end
        end
      end

      read_buffer if @buffer.length < 4096

      if read_remove_regex(@regex_colsep_next)
        return true
      elsif @eof && @buffer.empty?
        puts "csv_lazy: End-of-file and empty buffer." if @debug
        return false
      elsif read_remove_regex(@regex_row_end)
        puts "csv_lazy: Row-end found." if @debug
        return false
      else
        raise "Dont know what to do (#{@buffer.length}): #{@buffer}"
      end
    elsif match = read_remove_regex(@regex_read_until_col_sep)
      add_col(match[1])
    elsif match = read_remove_regex(@regex_read_until_row_sep)
      puts "csv_lazy: Row seperator reached." if @debug
      add_col(match[1])
      return false
    elsif match = read_remove_regex(@regex_read_until_end)
      #If the very end of the file has been reached, then add this data and stop parsing.
      if @eof
        add_col(match[1])
        return false
      end

      #The end-of-file hasnt been reached. Add more data to buffer and try again.
      @buffer << match[0]
      read_buffer
      raise Errno::EAGAIN
    else
      raise "Dont know what to do with buffer: '#{@buffer}'."
    end
  rescue Errno::EAGAIN
    puts "csv_lazy: Retry! Probably we ran out of buffer..." if @debug
    retry
  end

  def read_until_quote_and_end
    if match = @buffer.match(/\A(.*?)#{Regexp.escape(@args[:quote_char])}(#{Regexp.escape(@args[:col_sep])}|#{Regexp.escape(@args[:row_sep])})/)
      @buffer = @buffer.gsub(/\A#{Regexp.escape(match[1])}#{Regexp.escape(@args[:quote_char])}/, "")
      add_col(match[1])
      true
    else
      false
    end
  end

  #Adds a new column to the current row.
  def add_col(str)
    @row << str
  end
end
