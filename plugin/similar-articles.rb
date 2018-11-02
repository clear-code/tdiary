# -*- coding: utf-8 -*-

add_section_leave_proc do |date, index|
	searcher = @conf["similar_articles_searcher"]
	next '' unless searcher

	articles = searcher.similar_articles(date.strftime("%Y%m%d"))
	next '' if articles.empty?

	html = "<div class=\"similar-articles\">\n"
	html << "<h4>関連記事</h4>\n"
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
