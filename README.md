# Generate Time-Block Planner Pages

Forked from [jlorenzetti](https://github.com/jlorenzetti/planner) and [drewish](https://github.com/drewish/planner)
for yet another take on [Cal Newport's Time-Block Planner](https://www.timeblockplanner.com). It generates a PDF
with a week's worth of A5 pages. You can take a look at a [sample](sample.pdf) and see
what you think.

Main changes are:

- Page size (A5)
- Margins (reduced for smaller page size)
- Font size (down from 20 to 12 to fit the minified page size)
- Removal of hole punches (I use [pre-punched](https://a.co/d/4zbLUnA) pages for my [A5 planner](https://www.amazon.com/gp/product/B07WJD165M/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1))
- Additional hours of the day (I plan outside of the workday so I needed further hours listed).

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
