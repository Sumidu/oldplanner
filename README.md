# Generate Time-Block Planner Pages

Forked from [drewish](https://github.com/drewish/planner) brilliant take on
[Cal Newport's Time-Block Planner](https://www.timeblockplanner.com). It generates a PDF
with a week's worth of A4 pages. You can take a look at a [sample](sample.pdf) and see
what you think.

## Installation

Assuming you've got [Ruby](http://www.ruby-lang.org/en/) and [Bundler](https://bundler.io)
installed you can just run:
```
git clone git@github.com:jlorenzetti/planner.git
cd planner
bundle install
```

## Usage

It assumes you want to generate pages for the next week so there are no options:
```
bundle exec planner.rb
```

## Limitations

Probably only works on a Mac since it hardcodes the font path.
