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

require "rubygems"
require "coderay"

module TDiary
	module RDSyntaxHighlight
		def apply_to_Verbatim(element)
			content = []
			element.each_line do |line|
				content << line
			end
			first_line = content.shift
			case first_line
			when /\A\#\s*source[:\s]\s*(\w+)\s*\z/
				result = highlight_syntax(content.join(""), $1)
				return result unless result.empty?
			end
			super
		end

		private
		def highlight_syntax(source, lang)
			tokens = CodeRay.scan(source, lang)
			tokens.html(:line_numbers => :table,
					      :css => :style)
		end

		BaseIO.after_load_styles do |io|
			RD::RD2tDiaryVisitor.class_eval do
				include TDiary::RDSyntaxHighlight
			end
		end
	end
end

# Local Variables:
# ruby-indent-level: 3
# tab-width: 3
# indent-tabs-mode: t
# End:
