@my_sequel_default_hash[:label][:default] = 'この記事の続き'
@my_sequel_default_hash[:inner_css][:default] = 'font-size: medium; text-align: left;'

class MySequel
  attr_accessor :articles_db

  def html(dst_anchor, date_format, label)
    anchors = srcs(dst_anchor)
    if anchors and not anchors.empty? then
      r = %Q|<div class="sequel"><h4>#{h label}</h4><ul><li>|
      r += anchors.map{|src_anchor|
        articles_db = self.articles_db
        article_title = articles_db && articles_db.title(src_anchor)
        label = Time.local(*(src_anchor.scan(/(\d{4,4})(\d\d)(\d\d)/)[0])).strftime(date_format)
        label = "#{label}: #{article_title}" if article_title
        yield(src_anchor, label)
      }.join('</li><li>')
      r += "</li></ul></div>\n"
      return r
    else
      return ''
    end
  end
end

add_header_proc do
  if not(bot?) and @my_sequel
    @my_sequel.articles_db = @conf["articles_db"]
  end
  ''
end
