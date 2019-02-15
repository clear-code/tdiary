# -*- coding: utf-8 -*-

add_section_leave_proc do |date, index|
	articles_db = @conf["articles_db"]
	next '' unless articles_db

	source_date = date.strftime("%Y%m%d")
	articles = articles_db.similar_articles(source_date)
	next '' if articles.empty?

	html = "<div class=\"similar-articles\">\n"
	html << "<h4>関連記事</h4>\n"
	html << "<ul>\n"
	articles.each do |article|
		label = h(article["title"])
		path = anchor(article["_key"])
		score = article["_score"]
		html << "<li data-score=\"#{score}\" data-source=\"#{source_date}\"><a href=\"#{path}\">#{label}</a></li>\n"
	end
	html << "</ul>\n"
	html << "</div>\n"

	html
end
