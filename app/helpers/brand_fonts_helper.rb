require "base64"

module BrandFontsHelper
  BRAND_FONT_FILES = {
    besley_roman_latin_ext: "besley-roman-latin-ext-v22.woff2",
    besley_roman_latin: "besley-roman-latin-v22.woff2",
    besley_italic_latin_ext: "besley-italic-latin-ext-v22.woff2",
    besley_italic_latin: "besley-italic-latin-v22.woff2",
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
