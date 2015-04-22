[![Build Status](https://api.shippable.com/projects/540e7b9a3479c5ea8f9ec209/badge?branchName=master)](https://app.shippable.com/projects/540e7b9a3479c5ea8f9ec209/builds/latest)
[![Code Climate](https://codeclimate.com/github/kaspernj/csv_lazy/badges/gpa.svg)](https://codeclimate.com/github/kaspernj/csv_lazy)
[![Test Coverage](https://codeclimate.com/github/kaspernj/csv_lazy/badges/coverage.svg)](https://codeclimate.com/github/kaspernj/csv_lazy)

# csv_lazy

## Install

Add to your Gemfile and bundle

```ruby
gem "csv_lazy"
```

## Usage

### Example

```ruby
CsvLazy.new(io: StringIO.new(csv_content)) do |row|
  puts "Row: #{row}" #=> [1, 2, 3]
end
```

### With a lot of options

```ruby
CsvLazy.new(io: some_io, col_sep: ",", row_sep: "\r\n", headers: true, quote_char: "'", encoding: "ISO8859-1", debug: false) do |row|
end
```

Description goes here.

## Contributing to csv_lazy

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Kasper Johansen. See LICENSE.txt for
further details.
