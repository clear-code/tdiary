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

module TDiary
	module IO
		class Base
		@@after_load_styles_hooks = []
		@@loaded_styles = false
		class << self
			def after_load_styles( block = Proc::new )
				@@after_load_styles_hooks << block
			end
		end

		def load_styles_with_after_hook
			load_styles_without_after_hook
			return if @@loaded_styles
			@@after_load_styles_hooks.each do |hook|
				hook.call(self)
			end
			@@loaded_styles = true
		end
		alias_method :load_styles_without_after_hook, :load_styles
		alias_method :load_styles, :load_styles_with_after_hook
		end
	end
end

# Local Variables:
# ruby-indent-level: 3
# tab-width: 3
# indent-tabs-mode: t
# End:
