
class MySequel
  def html(dst_anchor, date_format, label)
    anchors = srcs(dst_anchor)
    if anchors and not anchors.empty? then
      r = %Q|<div class="sequel"><h3>#{h label}</h3><ul><li>|
      r += anchors.map{|src_anchor|
        yield(src_anchor, Time.local(*(src_anchor.scan(/(\d{4,4})(\d\d)(\d\d)/)[0])).strftime(date_format))
      }.join('</li><li>')
      r += "</li></ul></div>\n"
      return r
    else
      return ''
    end
  end
end
