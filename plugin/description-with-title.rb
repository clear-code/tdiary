# -*- indent-tabs-mode: t; ruby-indent-level: 3; tab-width: 3 -*-
#
# Copyright (C) 2009  Kouhei Sutou <kou@clear-code.com>
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

def description_tag
	if @mode == "day"
		_date = @date.strftime("%Y%m%d")
		diaries = [@diaries.find {|date, diary| _date == date}].compact
	else
		diaries = @diaries
	end
	diary_titles = diaries.collect do |date, diary|
		title = diary.title
		subtitles = []
		diary.each_section do |section|
			subtitles << section.subtitle
		end
		[title, subtitles.join(", ")].reject do |string|
			string.empty?
		end.join(": ")
	end.reject do |string|
		string.empty?
	end.join(", ")

	description = [@conf.description || '', diary_titles].reject do |string|
		string.empty?
	end.join(": ")

	if description.empty?
		""
	else
		%Q[<meta name="description" content="#{h description}">]
	end
end
