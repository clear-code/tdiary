# -*- indent-tabs-mode: t; ruby-indent-level: 3; tab-width: 3 -*-
#
# Copyright (C) 2009-2015  Kouhei Sutou <kou@clear-code.com>
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

def open_hub_detail(id)
	base = "https://www.openhub.net/accounts/#{u(id)}"
	"<a href='#{base}?ref=Detailed'>" +
		"<img alt='Open Hub profile for #{h(id)}' height='35' " +
		"src='#{base}/widgets/account_detailed.gif' width='230'>" +
		"</a>"
end
