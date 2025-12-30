
require 'nokogiri'

svg_path = '/Users/duartemartins/Code/europe_versus/app/assets/images/europe_map.svg'
doc = Nokogiri::XML(File.read(svg_path))

transcontinental_countries = [
  "Russia",
  "Turkey",
  "Azerbaijan"
]

doc.css('path').each do |path|
  name = path['data-name']
  if transcontinental_countries.include?(name)
    puts "Styling #{name}..."
    path['class'] = 'transcontinental'
    path['fill'] = '#93C5FD' # Lighter blue
  end
end

File.write(svg_path, doc.to_xml)
puts "Done!"
