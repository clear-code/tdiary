require 'tdiary/defaultio'

module TDiary
	class SubversionIO < DefaultIO
		def transaction( date, &block )
			dirty = TDiaryBase::DIRTY_NONE
			result = super( date ) do |diaries|
				dirty = block.call( diaries )
				diaries = diaries.reject {|_, diary| /\A\s*\Z/ =~ diary.to_src}
				dirty
			end
			unless (dirty & TDiaryBase::DIRTY_DIARY).zero?
				run( "svn", "add", File.dirname( @dfile ) )
				run( "svn", "add", @dfile )
				Dir.chdir(@data_path) do
					run( "svn", "ci", "-m", "update #{date.strftime('%Y-%m-%d')}" )
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
