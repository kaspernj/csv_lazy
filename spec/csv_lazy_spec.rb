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
end
