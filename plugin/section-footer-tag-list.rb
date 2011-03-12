# -*- coding: utf-8; indent-tabs-mode: t; ruby-indent-level: 3; tab-width: 3 -*-
#
# Copyright (C) 2011  Kouhei Sutou <kou@clear-code.com>
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

add_section_enter_proc do |date, index|
	@category_to_tag_list = {}
	''
end

subtitle_proc = Proc.new do |date, index, subtitle|
	if subtitle then
		subtitle.sub( /^(?:\[[^\[]+?\])+/ ) do
			$&.scan( /\[(.*?)\]/ ) do |tag|
				@category_to_tag_list[tag.shift] = false # false when diary
			end
		end
	end
	subtitle
end
@subtitle_procs.unshift(subtitle_proc)

add_section_leave_proc do |date, index|
	tag_list = ""
	if @category_to_tag_list and not @category_to_tag_list.empty? then
		tag_list << "<div class=\"tag-list\">\n"
		tag_list << "タグ: "
		tags = @category_to_tag_list.collect do |tag, blog|
			category_anchor("#{tag}").gsub(/(?:^\[|\]$)/, '')
		end
		tag_list << tags.join(" | ")
		tag_list << "</div>\n"
	end
	tag_list
end
