require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "CsvLazy" do
  it "should be able to read CSV" do
    cont = "1;2;3;4;5\n6;7;8;9;10"
    
    count = 0
    Csv_lazy.new(:io => StringIO.new(cont)) do |csv|
      raise "Expected count of 5 but it wasnt: #{csv.length} (#{csv})" if csv.length != 5
      
      csv.each do |csv_ele|
        raise "Expected numeric value but it wasnt: '#{csv_ele}'." if !csv_ele.to_s.match(/^(\d+)$/)
      end
      
      count += 1
    end
    
    raise "Expected 2 rows but got #{count}" if count != 2
  end
  
  it "should be able to read mixed CSV" do
    cont = "1;\"2\";3;\"4\";5\n6;7;8;9;10"
    
    count = 0
    Csv_lazy.new(:io => StringIO.new(cont)) do |csv|
      raise "Expected count of 5 but it wasnt: #{csv.length} (#{csv})" if csv.length != 5
      
      csv.each do |csv_ele|
        raise "Expected numeric value but it wasnt: '#{csv_ele}'." if !csv_ele.to_s.match(/^(\d+)$/)
      end
      
      count += 1
    end
    
    raise "Expected 2 rows but got #{count}" if count != 2
  end
  
  it "should be able to handle ending whitespaces" do
    cont = "1;2;3;4;\"5\"     \n6;7;8;9;\"10\""
    
    count = 0
    Csv_lazy.new(:io => StringIO.new(cont)) do |csv|
      raise "Expected count of 5 but it wasnt: #{csv.length} (#{csv})" if csv.length != 5
      
      csv.each do |csv_ele|
        raise "Expected numeric value but it wasnt: '#{csv_ele}'." if !csv_ele.to_s.match(/^(\d+)$/)
      end
      
      count += 1
    end
    
    raise "Expected 2 rows but got #{count}" if count != 2
  end
  
  it "should read sample 1" do
    require "zlib"
    
    count = 0
    Zlib::GzipReader.open("#{File.dirname(__FILE__)}/test1.csv.gz") do |gz|
      Csv_lazy.new(:io => gz, :col_sep => ",", :row_sep => "\r\n") do |row|
        raise "Expected length of 32 but it wasnt: #{row.length}" if row.length != 32
        raise "Expected C-format or 'contract_id' column as the first but it wasnt: #{row[0]}" if !row[0].to_s.match(/^C(\d+)$/) and row[0] != "contract_id"
        count += 1
      end
    end
    
    raise "Expected 23 rows but got #{count}" if count != 23
  end
  
  it "should be able to use a whitespace as col-sep" do
    cont = "1\t2\t\"3\"\t4\n"
    
    expect = 0
    lines_found = 0
    Csv_lazy.new(:col_sep => "\t", :io => StringIO.new(cont)) do |csv|
      lines_found += 1
      
      csv.each do |key|
        expect += 1
        key.should eql(expect.to_s)
      end
    end
    
    lines_found.should eql(1)
  end
  
  it "should be able to use headers and return hashes instead" do
    cont = "\"name\",age\r\n"
    cont << "\"Kasper Johansen\",27\r\n"
    cont << "\"Christina Stoeckel\",\"25\"\r\n"
    
    line = 0
    Csv_lazy.new(:col_sep => ",", :io => StringIO.new(cont), :headers => true, :row_sep => "\r\n") do |csv|
      csv.class.should eql(Hash)
      line += 1
      csv.keys.length.should eql(2)
      csv.length.should eql(2)
      
      if line == 1
        csv[:name].should eql("Kasper Johansen")
        csv[:age].should eql("27")
      elsif line == 2
        csv[:name].should eql("Christina Stoeckel")
        csv[:age].should eql("25")
      else
        raise "Wrong line: #{line}"
      end
    end
    
    line.should eql(2)
  end
  
  it "should be able to encode incoming strings from weird files without crashing" do
    File.open("#{File.dirname(__FILE__)}/test2.csv", "rb", :encoding => "UTF-16LE") do |fp|
      #Remove invalid UTF content.
      fp.read(2)
      
      Csv_lazy.new(:col_sep => ",", :io => fp, :headers => true, :row_sep => "\r\n", :quote_char => '"', :encode => "US-ASCII", :debug => false) do |csv|
        csv.keys[0].should eql(:legacy_user_id)
        csv.keys[1].should eql(:savings_percentage)
        csv.keys[2].should eql(:active)
        csv.keys.length.should eql(3)
      end
    end
  end
  
  it "should do proper escaping" do
    cont = "\"Test1\";\"Test2 \\\"Wee\\\"\"\r\n"
    cont << "\"Test3\";\"Test4 \\\"Wee\\\"\";\"Test5 \\\"Wee\\\"\"\r\n"
    
    csv = Csv_lazy.new(:col_sep => ";", :io => StringIO.new(cont), :row_sep => "\r\n")
    
    row = csv.read_row
    row[0].should eql("Test1")
    row[1].should eql("Test2 \"Wee\"")
    row.length.should eql(2)
    
    row = csv.read_row
    row[0].should eql("Test3")
    row[1].should eql("Test4 \"Wee\"")
    row[2].should eql("Test5 \"Wee\"")
    row.length.should eql(3)
    
    row = csv.read_row
    row.should eql(false)
  end
end
