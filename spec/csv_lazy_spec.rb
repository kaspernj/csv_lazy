require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "CsvLazy" do
  it "should be able to read CSV" do
    cont = "1;2;3;4;5\n6;7;8;9;10"

    count = 0
    CsvLazy.new(io: StringIO.new(cont)) do |csv|
      expect(csv.length).to eq 5

      csv.each do |csv_ele|
        expect(csv_ele.to_s).to match /^(\d+)$/
      end

      count += 1
    end

    expect(count).to eq 2
  end

  it "should be able to read mixed CSV" do
    cont = "1;\"2\";3;\"4\";5\n6;7;8;9;10"

    count = 0
    CsvLazy.new(io: StringIO.new(cont)) do |csv|
      expect(csv.length).to eq 5

      csv.each do |csv_ele|
        expect(csv_ele.to_s).to match /^(\d+)$/
      end

      count += 1
    end

    expect(count).to eq 2
  end

  it "should be able to handle ending whitespaces" do
    cont = "1;2;3;4;\"5\"     \n6;7;8;9;\"10\""

    count = 0
    CsvLazy.new(io: StringIO.new(cont)) do |csv|
      expect(csv.length).to eq 5

      csv.each do |csv_ele|
        expect(csv_ele.to_s).to match /^(\d+)$/
      end

      count += 1
    end

    expect(count).to eq 2
  end

  it "reads sample 1" do
    require "zlib"

    count = 0
    Zlib::GzipReader.open("#{File.dirname(__FILE__)}/test1.csv.gz") do |gz|
      CsvLazy.new(io: gz, col_sep: ",", row_sep: "\r\n") do |row|
        expect(row.length).to eq 32
        raise "Expected C-format or 'contract_id' column as the first but it wasnt: #{row[0]}" if !row[0].to_s.match(/^C(\d+)$/) and row[0] != "contract_id"
        expect(row[0].to_s).to match /^C(\d+)$/ if row[0] != "contract_id"
        count += 1
      end
    end

    expect(count).to eq 23
  end

  it "is able to use a whitespace as col-sep" do
    cont = "1\t2\t\"3\"\t4\n"

    expect = 0
    lines_found = 0
    CsvLazy.new(col_sep: "\t", io: StringIO.new(cont)) do |csv|
      lines_found += 1

      csv.each do |key|
        expect += 1
        expect(key).to eq expect.to_s
      end
    end

    expect(lines_found).to eq 1
  end

  it "is able to use headers and return hashes instead" do
    cont = "\"name\",age\r\n"
    cont << "\"Kasper Johansen\",27\r\n"
    cont << "\"Christina Stoeckel\",\"25\"\r\n"

    line = 0
    CsvLazy.new(col_sep: ",", io: StringIO.new(cont), headers: true, row_sep: "\r\n") do |csv|
      expect(csv.class).to eq Hash
      line += 1
      expect(csv.keys.length).to eq 2
      expect(csv.length).to eq 2

      if line == 1
        expect(csv[:name]).to eq "Kasper Johansen"
        expect(csv[:age]).to eq "27"
      elsif line == 2
        expect(csv[:name]).to eq "Christina Stoeckel"
        expect(csv[:age]).to eq "25"
      else
        raise "Wrong line: #{line}"
      end
    end

    expect(line).to eq 2
  end

  it "should be able to encode incoming strings from weird files without crashing" do
    File.open("#{File.dirname(__FILE__)}/test2.csv", "rb", encoding: "UTF-16LE") do |fp|
      #Remove invalid UTF content.
      fp.read(2)

      CsvLazy.new(col_sep: ",", io: fp, headers: true, row_sep: "\r\n", quote_char: '"', encode: "US-ASCII", debug: false) do |csv|
        expect(csv.keys[0]).to eq :legacy_user_id
        expect(csv.keys[1]).to eq :savings_percentage
        expect(csv.keys[2]).to eq :active
        expect(csv.keys.length).to eq 3
      end
    end
  end

  it "should do proper escaping" do
    cont = "\"Test1\";\"Test2 \\\"Wee\\\"\"\r\n"
    cont << "\"Test3\";\"Test4 \\\"Wee\\\"\";\"Test5 \\\"Wee\\\"\"\r\n"

    csv = CsvLazy.new(col_sep: ";", io: StringIO.new(cont), row_sep: "\r\n")

    row = csv.read_row
    expect(row[0]).to eq "Test1"
    expect(row[1]).to eq "Test2 \"Wee\""
    expect(row.length).to eq 2

    row = csv.read_row
    expect(row[0]).to eq "Test3"
    expect(row[1]).to eq "Test4 \"Wee\""
    expect(row[2]).to eq "Test5 \"Wee\""
    expect(row.length).to eq 3

    row = csv.read_row
    expect(row).to eq false
  end
end
