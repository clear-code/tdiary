# -*- indent-tabs-mode: t; ruby-indent-level: 3; tab-width: 3 -*-
#
# Copyright (C) 2008-2009  Kouhei Sutou <kou@clear-code.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

add_header_proc do
	if @date and defined?(NaviUserCGI)
		cgi = NaviUserCGI.new(@date.strftime('%Y%m%d'))
		@more_diaries = {}
		yms = []
		today = @date.strftime('%Y%m%d')
		this_month = @date.strftime('%Y%m')

		@years.keys.each do |y|
			yms += @years[y].collect {|m| y + m}
		end
		yms |= [this_month]
		yms.sort!
		yms.unshift(nil).push(nil)
		yms[yms.index(this_month) - 1, 3].each do |ym|
			next unless ym
			cgi.params['date'] = [ym]
			m = TDiaryMonth.new(cgi, '', @conf)
			m.diaries.delete_if {|date, diary| !diary.visible?}
			@more_diaries = @more_diaries.merge(m.diaries)
		end
	end
	''
end

def diary_title(date)
	key = date.strftime("%Y%m%d")
	searcher = @conf["similar_articles_searcher"]
	if searcher
	  article_title = searcher.get_article_title(key)
	  return article_title if article_title
	end
	diary = @diaries[key]
	diary ||= (@more_diaries || {})[key]
	if diary
		if @plugin_files.grep(/\/category.rb$/).empty?
			subtitles = diary.all_subtitles_to_html
		else
			subtitles = diary.all_stripped_subtitles_to_html
		end
		subtitles = subtitles.join(", ").strip if subtitles
	else
		subtitles = ""
	end

	if subtitles.empty?
		date.strftime(@date_format)
	else
		apply_plugin(subtitles, true)
	end
end

def navi_prev_diary(date)
  h("前の記事: #{diary_title(date)}")
end

def navi_next_diary(date)
  h("次の記事: #{diary_title(date)}")
end

def navi_latest; '最新記事'; end
