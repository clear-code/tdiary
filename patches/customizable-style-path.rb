require 'tdiary/io/base'

module TDiary
	class IOBase
		def load_styles_with_customizable_path
			load_styles_without_customizable_path
			paths = @tdiary.conf.options['style.path'] || []
			paths = [paths] if paths.is_a?( String )
			["#{TDiary::PATH}/tdiary", *paths].each do |path|
				path = path.sub( /\/+$/, '' )
				Dir::glob( "#{path}/**/*_style.rb" ) do |style_file|
					require style_file.untaint
					style = File::basename( style_file ).sub( /_style\.rb$/, '' )
					@styles[style] ||= TDiary::const_get( "#{style.capitalize}Diary" )
				end
			end
		end
		alias_method :load_styles_without_customizable_path, :load_styles
		alias_method :load_styles, :load_styles_with_customizable_path
	end
end

# Local Variables:
# ruby-indent-level: 3
# tab-width: 3
# indent-tabs-mode: t
# End:
