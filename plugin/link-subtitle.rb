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

alias subtitle_link_without_no_anchor subtitle_link
def subtitle_link(date, index, subtitle)
	subtitle_without_category = subtitle.sub(/^(?:\[.*?\])+/ , '').strip
	param = date.strftime("%Y%m%d")
	"<a href=\"#{h(@index)}#{anchor(param)}\">#{h(subtitle_without_category)}</a>"
end
