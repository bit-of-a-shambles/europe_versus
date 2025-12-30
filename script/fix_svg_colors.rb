#!/usr/bin/env ruby
# Script to fix SVG colors for European countries
# - Armenia and Georgia should be fully European (dark blue #3B82F6)
# - Russia, Turkey, and Azerbaijan should be transcontinental (light blue #93C5FD)

require 'nokogiri'

svg_path = '/Users/duartemartins/Code/europe_versus/app/assets/images/europe_map.svg'
doc = Nokogiri::XML(File.read(svg_path))

# Countries that are fully European (dark blue)
FULLY_EUROPEAN_COLOR = '#3B82F6'

# Transcontinental countries (light blue)
TRANSCONTINENTAL_COLOR = '#93C5FD'
TRANSCONTINENTAL_COUNTRIES = [ "Russia", "Turkey", "Azerbaijan" ]

# Countries that should be fully European but might have wrong color
FULLY_EUROPEAN_COUNTRIES = [ "Armenia", "Georgia" ]

changes_made = 0

doc.css('path').each do |path|
  name = path['data-name']
  current_fill = path['fill']

  if TRANSCONTINENTAL_COUNTRIES.include?(name)
    if current_fill != TRANSCONTINENTAL_COLOR
      puts "#{name}: #{current_fill} -> #{TRANSCONTINENTAL_COLOR} (transcontinental)"
      path['fill'] = TRANSCONTINENTAL_COLOR
      path['class'] = 'transcontinental'
      changes_made += 1
    else
      puts "#{name}: Already correct (transcontinental)"
    end
  elsif FULLY_EUROPEAN_COUNTRIES.include?(name)
    if current_fill != FULLY_EUROPEAN_COLOR
      puts "#{name}: #{current_fill} -> #{FULLY_EUROPEAN_COLOR} (fully European)"
      path['fill'] = FULLY_EUROPEAN_COLOR
      path.delete('class') if path['class'] == 'transcontinental'
      changes_made += 1
    else
      puts "#{name}: Already correct (fully European)"
    end
  end
end

if changes_made > 0
  File.write(svg_path, doc.to_xml)
  puts "\nDone! Made #{changes_made} changes."
else
  puts "\nNo changes needed - all colors are correct."
end
