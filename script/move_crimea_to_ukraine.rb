#!/usr/bin/env ruby
# Script to move Crimea from Russia's path to Ukraine's path in the SVG map

require 'nokogiri'

svg_path = '/Users/duartemartins/Code/europe_versus/app/assets/images/europe_map.svg'
doc = Nokogiri::XML(File.read(svg_path))

# Get Russia and Ukraine paths
russia = doc.at_css('path[data-name="Russia"]')
ukraine = doc.at_css('path[data-name="Ukraine"]')

russia_d = russia['d']
ukraine_d = ukraine['d']

# Split Russia's path into sub-paths
subpaths = russia_d.split(/(?=M)/)
puts "Russia has #{subpaths.length} sub-paths"

# Find Crimea sub-path (index 2 based on our analysis)
# Crimea is roughly at x: 484-519, y: 461-484
crimea_index = nil
crimea_path = nil

subpaths.each_with_index do |path, i|
  coords = path.scan(/([\d.]+),([\d.]+)/)
  next if coords.empty?

  xs = coords.map { |c| c[0].to_f }
  ys = coords.map { |c| c[1].to_f }

  min_x, max_x = xs.min, xs.max
  min_y, max_y = ys.min, ys.max

  # Crimea peninsula criteria
  if min_x > 480 && max_x < 525 && min_y > 455 && max_y < 490 && coords.length > 100
    puts "Found Crimea at subpath ##{i}: x=#{min_x.round(1)}-#{max_x.round(1)}, y=#{min_y.round(1)}-#{max_y.round(1)} (#{coords.length} points)"
    crimea_index = i
    crimea_path = path
    break
  end
end

if crimea_path.nil?
  puts "Could not find Crimea sub-path!"
  exit 1
end

# Remove Crimea from Russia's path
subpaths.delete_at(crimea_index)
new_russia_d = subpaths.join('')
russia['d'] = new_russia_d

# Add Crimea to Ukraine's path
new_ukraine_d = ukraine_d + crimea_path
ukraine['d'] = new_ukraine_d

# Save the modified SVG
File.write(svg_path, doc.to_xml)

puts "\nDone! Crimea has been moved from Russia to Ukraine."
puts "Russia path: #{russia_d.length} -> #{new_russia_d.length} chars"
puts "Ukraine path: #{ukraine_d.length} -> #{new_ukraine_d.length} chars"
