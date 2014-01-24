# Copyright (C) 2008-2013  Kouhei Sutou <kou@clear-code.com>
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

require 'tdiary/io/default'

module TDiary
	class GitIO < IO::Default
		def transaction( date, &block )
			dirty = TDiaryBase::DIRTY_NONE
			result = super( date ) do |diaries|
				dirty = block.call( diaries )
				diaries = diaries.reject {|_, diary| /\A\s*\Z/ =~ diary.to_src}
				dirty
			end
			unless (dirty & TDiaryBase::DIRTY_DIARY).zero?
				Dir.chdir(@data_path) do
					run( "git", "add", @dfile )
					run( "git", "commit", "-m", "Update #{date.strftime('%Y-%m-%d')}" )
					run( "git", "push" )
				end
			end
			result
		end

		private
		def run( *command )
			command = command.collect {|arg| escape_arg( arg )}.join(' ')
			result = `#{command} 2>&1`
			unless $?.success?
				raise "Failed to run #{command}: #{result}"
			end
			result
		end

		def escape_arg( arg )
			"'#{arg.gsub( /'/, '\\\'' )}'"
		end
	end
end

# Local Variables:
# ruby-indent-level: 3
# tab-width: 3
# indent-tabs-mode: t
# End:
