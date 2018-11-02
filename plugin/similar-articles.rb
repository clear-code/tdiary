# -*- coding: utf-8 -*-

add_section_leave_proc do |date, index|
	searcher = @conf["similar_articles_searcher"]
	break '' unless searcher

	articles = searcher.similar_articles(date.strftime("%Y%m%d"))
	break '' if articles.empty?

	html = "<div class=\"similar-articles\">\n"
	html << "<h3>関連記事</h3>\n"
	html << "<ul>\n"
	articles.each do |article|
		label = h(article["title"])
		path = anchor(article["_key"])
		html << "<li><a href=\"#{path}\">#{label}</a></li>\n"
	end
	html << "</ul>\n"
	html << "</div>\n"

	html
end
