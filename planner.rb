#!/usr/bin/env ruby

require 'prawn'
require 'prawn/measurement_extensions'
require 'pry'
require 'date'
require 'i18n'

FULL_WEEKENDS = false
WEEKS = 27
HOUR_LABELS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
HOUR_COUNT = HOUR_LABELS.length
COLUMN_COUNT = 4
LIGHT_COLOR = 'AAAAAA'
MEDIUM_COLOR = '888888'
DARK_COLOR   = '000000'
DATE_LONG = "%B %-d, %Y"
OSX_FONT_PATH = "/System/Library/Fonts/HelveticaNeue.ttc"
FILE_NAME = "time_block_pages.pdf"
PAGE_SIZE = "A5"
# Order is top, right, bottom, left
LEFT_PAGE_MARGINS = [36, 52, 36, 36]
RIGHT_PAGE_MARGINS = [36, 36, 36, 52]


I18n.load_path += Dir[File.join(__dir__, 'config', 'locales', '*.{rb,yml}')]
I18n.available_locales = [:de, :en]
I18n.default_locale = :en

# From https://stackoverflow.com/a/24753003/203673
#
# Calculates the number of business days in range (start_date, end_date]
#
# @param start_date [Date]
# @param end_date [Date]
#
# @return [Fixnum]
def business_days_between(start_date, end_date)
  days_between = (end_date - start_date).to_i
  return 0 unless days_between > 0

  # Assuming we need to calculate days from 9th to 25th, 10-23 are covered
  # by whole weeks, and 24-25 are extra days.
  #
  # Su Mo Tu We Th Fr Sa    # Su Mo Tu We Th Fr Sa
  #        1  2  3  4  5    #        1  2  3  4  5
  #  6  7  8  9 10 11 12    #  6  7  8  9 ww ww ww
  # 13 14 15 16 17 18 19    # ww ww ww ww ww ww ww
  # 20 21 22 23 24 25 26    # ww ww ww ww ed ed 26
  # 27 28 29 30 31          # 27 28 29 30 31
  whole_weeks, extra_days = days_between.divmod(7)

  unless extra_days.zero?
    # Extra days start from the week day next to start_day,
    # and end on end_date's week date. The position of the
    # start date in a week can be either before (the left calendar)
    # or after (the right one) the end date.
    #
    # Su Mo Tu We Th Fr Sa    # Su Mo Tu We Th Fr Sa
    #        1  2  3  4  5    #        1  2  3  4  5
    #  6  7  8  9 10 11 12    #  6  7  8  9 10 11 12
    # ## ## ## ## 17 18 19    # 13 14 15 16 ## ## ##
    # 20 21 22 23 24 25 26    # ## 21 22 23 24 25 26
    # 27 28 29 30 31          # 27 28 29 30 31
    #
    # If some of the extra_days fall on a weekend, they need to be subtracted.
    # In the first case only corner days can be days off,
    # and in the second case there are indeed two such days.
    tomorrow = start_date.next_day(1)
    extra_days -= if tomorrow.wday <= end_date.wday
                    [tomorrow.sunday?, end_date.saturday?].count(true)
                  else
                    2
                  end
  end

  (whole_weeks * 5) + extra_days
end

def business_days_left_in_year(date)
  days = business_days_between(date, Date.new(date.year, 12, 31))
  case days
  when 0
    #"letzter Arbeitstag im Jahr"
    I18n.t('last_business_day_of_year')
  when 1
    #"1 weiterer Arbeitstag im Jahr"
    I18n.t('one_more_business_day_in_year')
  else
    #"#{days} Arbeitstage im Jahr"
    I18n.t('business_days_in_year', count: days)
  end
end

def business_days_left_in_sprint(date)
  sprint_end =
    if date.mday <= 15
      Date.new(date.year, date.month, 15)
    else
      Date.new(date.year, date.month, -1)
    end
  days = business_days_between(date, sprint_end)
  case days
  when 0
    #"last day of sprint"
    I18n.t('last_sprint_day')
  when 1
    #"1 day left in sprint"
    I18n.t('one_day_left_in_sprint')
  else
    #"#{days} days left in sprint"
    I18n.t('days_left_in_sprint', count: days)
  end
end

def quarter(date)
  (date.month / 3.0).ceil
end

def semester_year(date)
  if date.month >= 4 && date.month <= 9
    res = I18n.l(date, format: :year)
  else
    res = I18n.l(date, format: :year) << " / " << I18n.l(date.next_year, format: :year)
  end
  res
end

def draw_checkbox checkbox_size, checkbox_padding
  original_color = stroke_color
  stroke_color(LIGHT_COLOR)
  dash [1, 2], phase: 0.5
  rectangle [bounds.top_left[0] + checkbox_padding, bounds.top_left[1] - checkbox_padding], checkbox_size, checkbox_size
  stroke
  undash
  stroke_color(original_color)
end

def begin_new_page side
  margin = side == :left ? LEFT_PAGE_MARGINS : RIGHT_PAGE_MARGINS
  start_new_page size: PAGE_SIZE, layout: :portrait, margin: margin
  if side == :right
    #hole_punches
  end
end

def hole_punches
  canvas do
    x = 25
    # Should be [(1.25).in, (5.5).in, (9.75).in] but there's some scaling
    # that's skewing it so I just did some trial and error to get the points
    # at the right spots
    [(1.25).in, (5.5).in, (9.75).in].each do |y|
    #[72, 392, 710].each do |y|
      horizontal_line x - 5, x + 5, at: y
      vertical_line y - 5, y + 5, at: x
    end
  end
end

# * * *

def week_ahead_page first_day, last_day
  # We don't start our own page since we don't know if this is the first week or one
  # of several weeks in a file.
  #hole_punches

  header_row_count = 2
  body_row_count = HOUR_COUNT * 2
  first_column = 0
  last_column = COLUMN_COUNT - 1
  first_row = header_row_count
  last_row = header_row_count + body_row_count - 1

  define_grid(columns: COLUMN_COUNT, rows: header_row_count + body_row_count, gutter: 0)
  # grid.show_all

  # Header Left
  grid([0, first_column],[0, last_column]).bounding_box do
    text I18n.t('upcoming_week'), inline_format: true, size: 12, character_spacing: -0.75, style: :bold, align: :left
  end
  grid([1, first_column],[1, last_column]).bounding_box do
    range = "#{I18n.l(first_day, format: :left_range)} — #{I18n.l(last_day, format: :right_range)}"
    text range, color: MEDIUM_COLOR, character_spacing: -0.25, align: :left
  end
  # Header Right
  grid([0, 3],[0, last_column]).bounding_box do
    week_str = I18n.t('week')
    text first_day.strftime("#{week_str} %W"), inline_format: true, size: 12, character_spacing: -0.75, style: :bold, align: :right
  end
  grid([1, 3],[1, last_column]).bounding_box do
    quarter_str = I18n.t('quarter')
    text "#{quarter_str} #{quarter(first_day)}", color: MEDIUM_COLOR, character_spacing: -0.25, align: :right
  end

  # Horizontal lines
  (first_row..last_row).each do |row|
    grid([row, first_column], [row, last_column]).bounding_box do
      stroke_line bounds.bottom_left, bounds.bottom_right
    end
  end

  # Checkboxes
  checkbox_padding = 6
  checkbox_size = grid.row_height - (2 * checkbox_padding)
  ((first_row + 1)..last_row).each do |row|
    grid(row, 0).bounding_box do
      draw_checkbox checkbox_size, checkbox_padding
    end
  end


end


def semester_ahead first_day, last_day, semester_type
  # this is very hacky and should be refactored
  # We don't start our own page since we don't know if this is the first week or one
  # of several weeks in a file.
  #hole_punches

  header_row_count = 2
  body_row_count = HOUR_COUNT * 2
  first_column = 0
  last_column = COLUMN_COUNT - 1
  first_row = header_row_count
  last_row = header_row_count + body_row_count - 1

  define_grid(columns: COLUMN_COUNT, rows: header_row_count + body_row_count, gutter: 0)
  # grid.show_all

  # Header Left
  grid([0, first_column],[0, last_column]).bounding_box do
    text I18n.t('semester_plan'), inline_format: true, size: 12, character_spacing: -0.75, style: :bold, align: :left
  end
  grid([1, first_column],[1, last_column]).bounding_box do
    range = "#{I18n.l(first_day, format: :right_range)} — #{I18n.l(last_day, format: :right_range)}"
    text range, color: MEDIUM_COLOR, character_spacing: -0.25, align: :left
  end
  # Header Right
  grid([0, 3],[0, last_column]).bounding_box do
    semester_str = I18n.t("#{semester_type}")
    text "#{semester_str}", inline_format: true, size: 12, character_spacing: -0.75, style: :bold, align: :right
  end
  grid([1, 3],[1, last_column]).bounding_box do

    semester_year_str = semester_year(first_day)
    text "#{semester_year_str}", color: MEDIUM_COLOR, character_spacing: -0.25, align: :right
  end

  # Horizontal lines
  (first_row..last_row).each do |row|
    grid([row, first_column], [row, last_column]).bounding_box do
      stroke_line bounds.bottom_left, bounds.bottom_right
    end
  end

  # Checkboxes
  checkbox_padding = 6
  checkbox_size = grid.row_height - (2 * checkbox_padding)
  ((first_row + 1)..last_row).each do |row|
    grid(row, 0).bounding_box do
      draw_checkbox checkbox_size, checkbox_padding
    end
  end


end



def daily_tasks_page date
  begin_new_page :left

  header_row_count = 2
  body_row_count = HOUR_COUNT * 2
  last_row = header_row_count + body_row_count - 1

  define_grid(columns: COLUMN_COUNT, rows: header_row_count + body_row_count, gutter: 0)
  # grid.show_all

  # Header
  left_header = I18n.l(date, format: :long) # date.strftime("Week %W")
  right_header = I18n.l(date, format: :weekday) # date.strftime("Day %j")
  grid([0, 0],[1, 2]).bounding_box do
    text left_header, size: 12, character_spacing: -0.75, style: :bold, align: :left
  end
  grid([0, 2],[1, 3]).bounding_box do
    text right_header, size: 12, character_spacing: -0.75, style: :bold, align: :right
  end

  # Daily metrics
  grid([1, 0], [4, 3]).bounding_box do
    dash [1, 2]
    stroke_bounds
    undash

    translate 10, -10 do
      text I18n.t('daily_metrics'), color: MEDIUM_COLOR, character_spacing: -0.25
    end

    stroke do
      rectangle [bounds.bottom_right[0] - 20, bounds.bottom_right[1] + 20], 10, 10
    end

    translate -26, 10 do
      text I18n.t('shutdown_complete'), color: MEDIUM_COLOR, size: 9, character_spacing: -0.25, align: :right, valign: :bottom
    end
  end

  # Tasks / Notes
  grid([5, 0], [5, 1]).bounding_box do
    translate 6, 0 do
      text I18n.t('tasks'), color: DARK_COLOR, character_spacing: -0.25, style: :bold, valign: :center
    end
  end
  grid([5, 2], [5, 3]).bounding_box do
    translate 6, 0 do
      text I18n.t('ideas'), color: DARK_COLOR, character_spacing: -0.25, style: :bold, valign: :center
    end
  end

  # Horizontal lines
  (5..last_row).each do |row|
    grid([row, 0], [row, 3]).bounding_box do
      stroke_line bounds.bottom_left, bounds.bottom_right
    end
  end

  # Vertical line
  grid([6, 1], [last_row, 1]).bounding_box do
    dash [1, 2], phase: 2
    stroke_line(bounds.top_right, bounds.bottom_right)
    undash
  end

  # Checkboxes
  checkbox_padding = 6
  checkbox_size = grid.row_height - (2 * checkbox_padding)
  (6..last_row).each do |row|
    grid(row, 0).bounding_box do
      draw_checkbox checkbox_size, checkbox_padding
    end
  end
end

def daily_calendar_page date
  begin_new_page :right

  header_row_count = 2
  body_row_count = HOUR_COUNT * 2
  first_column = 0
  last_column = COLUMN_COUNT - 1
  fist_hour_row = header_row_count
  last_hour_row = header_row_count + body_row_count - 1

  define_grid(columns: COLUMN_COUNT, rows: header_row_count + body_row_count, gutter: 0)

  # Header
  left_header = I18n.l(date, format: :long)
  # right_header = date.strftime("Day %j")
  right_header = I18n.l(date, format: :weekday)
  quarter_str = I18n.t('quarter')
  week_str = I18n.t('week')
  day_str = I18n.t('day')
  left_subhed = date.strftime("#{quarter_str} #{quarter(date)} #{week_str} %W #{day_str} %j")
  right_subhed = business_days_left_in_year(date)
  # right_subhed = business_days_left_in_sprint(date)
  grid([0, first_column],[1, 1]).bounding_box do
    text left_header, size: 12, character_spacing: -0.75, style: :bold, align: :left
  end
  grid([0, 2],[0, last_column]).bounding_box do
    text right_header, size: 12, character_spacing: -0.75, style: :bold, align: :right
  end
  grid([1, first_column],[1, last_column]).bounding_box do
    text left_subhed, color: MEDIUM_COLOR, character_spacing: -0.25, align: :left
  end
  grid([1, first_column],[1, last_column]).bounding_box do
    text right_subhed, color: MEDIUM_COLOR, character_spacing: -0.25, align: :right
  end

  # Hour labels
  (0...HOUR_COUNT).each do |hour|
    grid(hour * 2 + fist_hour_row, -1).bounding_box do
      if HOUR_LABELS[hour]
        translate(-4, 0) { text HOUR_LABELS[hour].to_s, character_spacing: -0.25, align: :right, valign: :center }
      end
    end
  end

  # Horizontal lines
  ## Top line
  stroke_color MEDIUM_COLOR
  overhang = 24
  grid([fist_hour_row, first_column], [fist_hour_row, last_column]).bounding_box do
    stroke_line([bounds.top_left[0] - overhang, bounds.top_left[1]], bounds.top_right)
  end
  (fist_hour_row..last_hour_row).step(2) do |row|
    ## Half hour lines
    dash [1, 2], phase: 2
    grid([row, first_column], [row, last_column]).bounding_box do
      stroke_line([bounds.bottom_left[0] - overhang, bounds.bottom_left[1]], bounds.bottom_right)
    end
    undash
    ## Hour lines
    grid([row + 1, first_column], [row + 1, last_column]).bounding_box do
      stroke_line([bounds.bottom_left[0] - overhang, bounds.bottom_left[1]], bounds.bottom_right)
    end
  end

  # Vertical lines
  (0..COLUMN_COUNT).each do |col|
    grid([header_row_count, col], [last_hour_row, col]).bounding_box do
      dash [1, 2], phase: 2
      stroke_line(bounds.top_left, bounds.bottom_left)
      undash
    end
  end
end


def weekend_page saturday, sunday
  begin_new_page :left

  header_row_count = 2
  hour_row_count = HOUR_COUNT
  # TODO should have one constant for grid's number of rows to use here.
  # instead we'll just assume it's always 2x hours. We print a row per hour
  # and one blank line as a divider.
  task_row_count = 2 * HOUR_COUNT - hour_row_count - 1
  body_row_count = header_row_count + task_row_count + hour_row_count

  # Use a grid to do the math to divide the page into two columns:
  define_grid(columns: 2, rows: 1, column_gutter: 24, row_gutter: 0)
  first = grid(0,0)
  second = grid(0,1)
  # Then use that to build a bounding box for each column and redefine the grid in there.
  work_areas = [
    [saturday, first.top_left, { width: first.width, height: first.height }],
    [sunday, second.top_left, { width: second.width, height: second.height }]
  ].each do |date, point, options|
    bounding_box(point, options) do
      define_grid(columns: 2, rows: body_row_count, gutter: 0)
      # grid.show_all

      # Header
      left_header = I18n.l(date, format: :weekday)
      left_sub_header = I18n.l(date, format: :short_date)
      grid([0, 0],[0, 1]).bounding_box do
        text left_header, size: 12, character_spacing: -0.25, style: :bold, align: :left
      end
      grid([1, 0],[1, 1]).bounding_box do
        text left_sub_header, color: MEDIUM_COLOR, character_spacing: -0.25, align: :left
      end

      task_start_row = header_row_count
      task_last_row = task_start_row + task_row_count - 1

      # Task lable
      grid([task_start_row, 0], [task_start_row, 1]).bounding_box do
        translate 6, 0 do
          text I18n.t('tasks'), color: DARK_COLOR, character_spacing: -0.25, style: :bold, valign: :center
        end
      end

      # Horizontal lines
      (task_start_row..task_last_row).each do |row|
        grid([row, 0], [row, 1]).bounding_box do
          stroke_line bounds.bottom_left, bounds.bottom_right
        end
      end

      # Checkboxes
      checkbox_padding = 6
      checkbox_size = grid.row_height - (2 * checkbox_padding)
      ((task_start_row + 1)..task_last_row).each do |row|
        grid(row, 0).bounding_box do
          draw_checkbox checkbox_size, checkbox_padding
        end
      end

      # Hour Grid
      hour_start_row = task_last_row + 1
      hour_last_row = hour_start_row + hour_row_count - 1

      # Horizontal Lines
      (hour_start_row..hour_last_row).each do |row|
        grid([row, 0], [row, 1]).bounding_box do
          stroke_line bounds.bottom_left, bounds.bottom_right
        end
      end

      # Vertical lines
      overhang = 24
      dash [1, 2]
      grid([hour_start_row + 1, 0], [hour_last_row, 0]).bounding_box do
        stroke_line([bounds.top_left[0] + overhang, bounds.top_left[1]], [bounds.bottom_left[0] + overhang, bounds.bottom_left[1]])
      end
      # half plus change
      grid([hour_start_row + 1, 0], [hour_last_row, 0]).bounding_box do
        stroke_line([bounds.top_right[0] + overhang * 0.5, bounds.top_right[1]], [bounds.bottom_right[0] + overhang * 0.5, bounds.bottom_right[1]])
      end
      grid([hour_start_row + 1, 1], [hour_last_row, 1]).bounding_box do
        stroke_line(bounds.top_right, bounds.bottom_right)
      end
      undash

      # Hour labels
      (0...HOUR_COUNT).each do |hour|
        grid(hour + hour_start_row + 1, -1).bounding_box do
          if HOUR_LABELS[hour]
            translate(20, 0) { text HOUR_LABELS[hour].to_s, character_spacing: -0.25, align: :right, valign: :center }
          end
        end
      end
    end
  end
end




# *** Program starts here

Prawn::Document.generate(FILE_NAME, margin: RIGHT_PAGE_MARGINS, print_scaling: :none) do
  font_families.update(
    'Helvetica Neue' => {
      normal: { file: OSX_FONT_PATH, font: 'Helvetica Neue Regular' },
      italic: { file: OSX_FONT_PATH, font: 'Helvetica Neue Italic' },
      bold: { file: OSX_FONT_PATH, font: 'Helvetica Neue Bold' },
    }
  )
  font("Helvetica Neue")
  stroke_color MEDIUM_COLOR
  line_width(0.5)

  sunday = if ARGV.empty?
      date = DateTime.now.to_date
      if date.wday > 2
        puts "Generating pages for the next week"
        date.next_day(7-date.wday)
      else
        puts "Generating pages for this week"
        date.prev_day(date.wday)
      end
    else
      date = DateTime.parse(ARGV.first).to_date
      puts "Parsed #{date.strftime('%A, %B %-d, %Y')} from arguments"
      date.prev_day(date.wday)
    end

  # ***  added semester planner here

  #determine if we are in summer or winter semester
  # if the current month is between april and september we are in the summer semester
  # if the current month is between october and march we are in the winter semester
  semester_type = if (date.month >= 4 && date.month <= 9)
    "summer"
  else
    "winter"
  end

  if semester_type == "summer"
    # find the first of april befor the sunday
    semester_start = Date.new(sunday.year, 4, 1)
    # find the last day of september after the sunday
    semester_end = Date.new(sunday.year, 9, 30)
  else

    # find the first of october before the sunday
    semester_start = Date.new(sunday.year, 10, 1)
    # find the last day of march after the sunday
    semester_end = Date.new(sunday.year + 1, 3, 31)
  end

  puts "Generate pages for the #{semester_type} semester, from #{semester_start.strftime('%A, %B %-d, %Y')} to #{semester_end.strftime('%A, %B %-d, %Y')} in #{FILE_NAME}"
  semester_ahead semester_start, semester_end, semester_type
  begin_new_page :right

  WEEKS.times do |week|
    unless week.zero?
      # ...then the page for the week
      begin_new_page :right
    end

    monday = sunday.next_day(1)
    friday = sunday.next_day(5)
    puts "Generate pages for week #{monday.strftime('%W')}: #{monday.strftime('%A, %B %-d, %Y')} through #{friday.strftime('%A, %B %-d, %Y')} in #{FILE_NAME}"
    week_ahead_page monday, friday

    day_limit = 5

    if FULL_WEEKENDS
      day_limit = 7
    end


    # I just want week days
    (1..day_limit).each do |i|
      day = sunday.next_day(i)
      daily_tasks_page day
      daily_calendar_page day
    end

    if !FULL_WEEKENDS
      weekend_page sunday.next_day(6), sunday.next_day(7)
    end

    sunday = sunday.next_day(7)
  end
end
