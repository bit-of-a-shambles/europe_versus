require "base64"

module BrandFontsHelper
  BRAND_FONT_FILES = {
    instrument_serif_roman_latin_ext: "instrument-serif-roman-latin-ext.woff2",
    instrument_serif_roman_latin: "instrument-serif-roman-latin.woff2",
    instrument_serif_italic_latin_ext: "instrument-serif-italic-latin-ext.woff2",
    instrument_serif_italic_latin: "instrument-serif-italic-latin.woff2",
    public_sans_roman_latin_ext: "public-sans-roman-latin-ext-v21.woff2",
    public_sans_roman_latin: "public-sans-roman-latin-v21.woff2"
  }.freeze

  def embedded_brand_font(key)
    @embedded_brand_fonts ||= {}
    @embedded_brand_fonts[key] ||= begin
      filename = BRAND_FONT_FILES.fetch(key)
      bytes = Rails.root.join("app", "assets", "fonts", filename).binread
      "data:font/woff2;base64,#{Base64.strict_encode64(bytes)}"
    end
  end
end
