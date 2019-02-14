
@my_sequel_default_hash[:inner_css][:default] = <<'_END',
font-size: medium;
text-align: left;
_END

class MySequel
  def html(dst_anchor, date_format, label)
    anchors = srcs(dst_anchor)
    if anchors and not anchors.empty? then
      r = %Q|<div class="sequel"><h4>#{h label}</h4><ul><li>|
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
