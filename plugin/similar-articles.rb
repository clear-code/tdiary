# -*- coding: utf-8 -*-

def similar_articles
	html = ''
	similar_articles = @conf["similar_articles"]
	if similar_articles and not(similar_articles.empty?)
		html << "<div class=\"similar-articles\">\n"
		html << "<h3>関連記事</h3>\n"
		html << "<ul>\n"
		similar_articles.each do |article|
			label = h(article["title"])
			path = anchor(article["_key"])
			html << "<li><a href=\"#{path}\">#{label}</a></li>\n"
		end
		html << "</ul>\n"
		html << "</div>\n"
	end
	html
end
