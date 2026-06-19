def publit_width(url, w)
  url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
end

def publit_srcset(url, focal_point = nil)
  return nil if url.nil? || url.empty?
  widths = [400, 700, 1050, 1400]
  style  = focal_point ? %( style="object-position: #{focal_point}") : ''
  srcset = widths.map { |w| "#{publit_width(url, w)} #{w}w" }.join(",\n                    ")
  { src: publit_width(url, 1050), srcset: srcset, style: style }
end


def reading_time(html)
  words = html.gsub(/<[^>]+>/, '').split.length
  mins  = [(words / 200.0).ceil, 1].max
  "#{mins} min read"
end