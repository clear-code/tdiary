#!/usr/bin/env ruby
# -*- coding: utf-8; ruby-indent-level: 3; tab-width: 3; indent-tabs-mode: t -*-
#
# Copyright (C) 2008-2015  Kouhei Sutou <kou@clear-code.com>
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

require 'uri'
require 'cgi'
require 'fileutils'
require 'pathname'
require 'optparse'
require 'ostruct'
require 'enumerator'
require 'rss'

options = OpenStruct.new
options.tdiary_path = "./"
options.conf_dir = "./"
opts = OptionParser.new do |opts|
	opts.banner += " OUTPUT_DIR"

	opts.on("-t", "--tdiary=TDIARY_DIRECTORY",
			  "a directory that has tdiary.rb") do |path|
		options.tdiary_path = path
	end

	opts.on("-c", "--conf=TDIARY_CONF_DIRECTORY",
			  "a directory that has tdiary.conf") do |conf|
		options.conf_dir = conf
	end
end
opts.parse!

output_dir = ARGV.shift

$LOAD_PATH.unshift(File.expand_path(File.join(options.tdiary_path, "lib")))
require "tdiary"

module HTMLArchiver
	class CGI < ::CGI
		def referer
			nil
		end

		def html_archiver?
			true
		end

		private
		def env_table
			{"REQUEST_METHOD" => "GET", "QUERY_STRING" => ""}
		end
	end

	module Image
		def init_image_dir
			@image_dest_dir = @dest + "images"
		end
	end

	module Base
		include Image

		def initialize(rhtml, dest, conf)
			@ignore_parser_cache = true

			cgi = CGI.new
			setup_cgi(cgi, conf)
			@dest = dest
			init_image_dir
			super(cgi, rhtml, conf)
		end

		def eval_rhtml(*args)
			fix_link(super) do |link_attribute, prefix, link|
				uri = nil
				begin
					uri = URI(link)
				rescue URI::Error
					puts "#{$!.class}: #{$!.message}"
					puts $@
				end
				if uri.nil? or uri.absolute? or link[0] == ?/ or link[0] == ?#
					link_attribute
				else
					%Q[#{prefix}="#{relative_path}#{link}"]
				end
			end
		end

		def save
			return false unless can_save?
			filename = output_filename
			if !filename.exist? or filename.mtime != last_modified
				filename.open('w') {|f| f.print(normalize_output(eval_rhtml))}
				filename.utime(last_modified, last_modified) if set_last_modified?
			end
			true
		end

		protected
		def output_component_name
			dir = @dest + output_component_dir
			name = output_component_base
			FileUtils.mkdir_p(dir.to_s, :mode => 0755)
			filename = dir + "#{name}.html"
			[dir, name, filename]
		end

		def mode
			self.class.to_s.split(/::/).last.downcase
		end

		def cookie_name; ''; end
		def cookie_mail; ''; end

		def load_plugins
			result = super
			@plugin.instance_eval(<<-EOS, __FILE__, __LINE__ + 1)
				def anchor( s )
					case s
					when /\\A(\\d+)#?([pct]\\d*)?\\z/
						day = $1
						anchor = $2
						if /\\A(\\d{4})(\\d{2})(\\d{2})?\\z/ =~ day
							day = [$1, $2, $3].compact
							day = day.collect {|component| component.to_i.to_s}
							day = day.join("/")
						end
						if anchor then
							"\#{day}.html#\#{anchor}"
						else
							"\#{day}.html"
						end
					when /\\A(\\d{8})-\\d+\\z/
						@conf['latest.path'][$1]
					else
						""
					end
				end

				def category_anchor(category)
					href = ::HTMLArchiver::Category.path(@conf, category)
					if @category_icon[category] and !@conf.mobile_agent?
						%Q|<a href="\#{href}" title="\#{h category}"><img class="category" src="\#{h @category_icon_url}\#{h @category_icon[category]}" alt="\#{h category}"></a>|
					else
						%Q|[<a href="\#{href}" title="\#{h category}">\#{h category}</a>]|
					end
				end

				def navi_admin
					""
				end

				@image_dir = #{@image_dest_dir.to_s.dump}
				@image_url = "#{@conf.base_url}#{@image_dest_dir.basename}"
			EOS
			result
		end

		private
		def setup_cgi(cgi, conf)
		end

		def fix_link(html)
			link_detect_re = /(<(?:a|link)\b.*?\bhref|<(?:img|script)\b.*?\bsrc)="(.*?)"/
			html.gsub(link_detect_re) do |link_attribute|
				prefix = $1
				link = $2
				yield(link_attribute, prefix, link)
			end
		end

		def normalize_output(output)
			html_to_html5(output)
		end

		def html_to_html5(html)
			html5 = html.sub(/\A<!DOCTYPE.+?>\n<html lang="(.+?)">\n/) do
				lang = $1
				<<-EOH
<!doctype html>
<html lang="#{lang}">
EOH
			end
		end

		def set_last_modified?
			set_last_modified = @conf["html_archiver.set_last_modified"]
			set_last_modified.nil? or set_last_modified
		end
	end

	class Day < TDiary::TDiaryDay
		include Base

		def initialize(diary, dest, conf)
			@target_date = diary.date
			@target_diaries = {@target_date.strftime("%Y%m%d") => diary}
			super("day.rhtml", dest, conf)
		end

		def can_save?
			not @diary.nil?
		end

		def output_filename
			dir, name, filename = output_component_name
			filename
		end

		def [](date)
			@target_diaries[date.strftime("%Y%m%d")] or super
		end

		def relative_path
			"../../"
		end

		private
		def output_component_dir
			Pathname(@target_date.strftime("%Y")) + @target_date.month.to_s
		end

		def output_component_base
			@target_date.day.to_s
		end

		def setup_cgi(cgi, conf)
			super
			cgi.params["date"] = [@target_date.strftime("%Y%m%d")]
		end
	end

	class Month < TDiary::TDiaryMonth
		include Base
		def initialize(date, dest, conf)
			@target_date = date
			super("month.rhtml", dest, conf)
		end

		def can_save?
			not @diary.nil?
		end

		def output_filename
			dir, name, filename = output_component_name
			filename
		end

		def relative_path
			"../"
		end

		private
		def output_component_dir
			@target_date.strftime("%Y")
		end

		def output_component_base
			@target_date.month.to_s
		end

		def setup_cgi(cgi, conf)
			super
			cgi.params["date"] = [@target_date.strftime("%Y%m")]
		end
	end

	class Category < TDiary::TDiaryView
		include Base

		class << self
			def normalize_name(conf, name)
				table = conf["html_archiver.category.normalize_table"] || {}
				table[name] || name.downcase.gsub(/[ _]/, "-")
			end

			def path(conf, name)
				normalized_category = normalize_name(conf, name)
				"#{directory_name}/#{ERB::Util.u normalized_category}.html"
			end

			def directory_name
				"category"
			end
		end

		def initialize(category, diaries, dest, conf)
			@category = category
			diaries = diaries.reject {|date, diary| diary.nil? or !diary.visible?}
			_, diary = diaries.sort_by {|date, diary| diary.last_modified}.last
			@target_date = diary.date
			super("latest.rhtml", dest, conf)
			@diaries = diaries
			@diary = diary
		end

		def can_save?
			not @diary.nil?
		end

		def output_directory
			category_dir = @dest + self.class.directory_name
			category_dir.mkpath
			category_dir
		end

		def output_filename
			output_directory + "#{normalized_name}.html"
		end

		def original_name
			@category
		end

		def normalized_name
			self.class.normalize_name(@conf, @category)
		end

		def relative_path
			"../"
		end

		def latest(limit=5)
			@diaries.keys.sort.reverse_each do |date|
				diary = @diaries[date]
				yield(diary)
			end
		end

		def load_plugins
			result = super
			@plugin.instance_eval(<<-EOS, __FILE__, __LINE__ + 1)
				def title_tag
					"<title>#{h( original_name )} - #{h( @conf.html_title )}</title>"
				end
			EOS
			result
		end

		protected
		def setup_cgi(cgi, conf)
			super
			cgi.params["date"] = [@target_date.strftime("%Y%m")]
			cgi.params["category"] = [@category]
		end
	end

	class Latest < TDiary::TDiaryLatest
		include Base

		def initialize(date, index, dest, conf)
			@target_date = date
			@index = index
			super("latest.rhtml", dest, conf)
		end

		def relative_path
			if @index.zero?
				""
			else
				"../"
			end
		end

		def can_save?
			true
		end

		def output_filename
			if @index.zero?
				@dest + "index.html"
			else
				latest_dir = @dest + "latest"
				FileUtils.mkdir_p(latest_dir.to_s, :mode => 0755)
				latest_dir + "#{@index}.html"
			end
		end

		protected
		def setup_cgi(cgi, conf)
			super
			return if @index.zero?
			date = @target_date.strftime("%Y%m%d") + "-#{conf.latest_limit}"
			cgi.params["date"] = [date]
		end
	end

	class RSS < TDiary::TDiaryLatest
		include Base

		def initialize(dest, conf)
			super("latest.rhtml", dest, conf)
		end

		def mode
			"latest"
		end

		def relative_path
			""
		end

		def can_save?
			true
		end

		def output_filename
			@dest + output_base_name
		end

		def output_base_name
			"index.rdf"
		end

		def do_eval_rhtml(prefix)
			load_plugins
			make_rss
		end

		private
		def make_rss
			base_uri = @conf['html_archiver.base_url'] || @conf.base_url
			rss_uri = base_uri + output_base_name

			@conf.options['apply_plugin'] = true
			feed = ::RSS::Maker.make("1.0") do |maker|
				setup_channel(maker.channel, rss_uri, base_uri)
				setup_image(maker.image, base_uri)

				i = 0
				@diaries.keys.sort.reverse_each do |date|
					diary = @diaries[date]
					next unless diary.visible?

					maker.items.new_item do |item|
						setup_item(item, diary, base_uri)
					end

					i += 1
					break if i > 15
				end
			end

			feed.to_s
		end

		def setup_channel(channel, rss_uri, base_uri)
			channel.about = rss_uri
			channel.link = base_uri
			channel.title = @conf.html_title
			description = @conf["html_archiver.rss.description"]
			description ||= @conf.description
			channel.description = description unless description.to_s.empty?
			channel.dc_creator = @conf.author_name
			channel.dc_rights = @conf.copyright
		end

		def setup_image(image, base_uri)
			return if @conf.banner.nil?
			return if @conf.banner.empty?

			if /^http/ =~ @conf.banner
				rdf_image = @conf.banner
			else
				rdf_image = base_uri + @conf.banner
			end

			maker.image.url = rdf_image
			maker.image.title = @conf.html_title
			maker.link = base_uri
		end

		def setup_item(item, diary, base_uri)
			section = nil
			diary.each_section do |_section|
				section = _section
				break if section
			end
			return if section.nil?

			item.link = base_uri + @plugin.anchor(diary.date.strftime("%Y%m%d"))
			item.dc_date = normalize_last_modified(diary.last_modified)
			@plugin.instance_variable_set("@makerss_in_feed", true)
			subtitle = section.subtitle_to_html
			body_enter = @plugin.send(:body_enter_proc, diary.date)
			body = @plugin.send(:apply_plugin, section.body_to_html)
			body_leave = @plugin.send(:body_leave_proc, diary.date)
			@plugin.instance_variable_set("@makerss_in_feed", false)

			subtitle = @plugin.send(:apply_plugin, subtitle, true).strip
			subtitle.sub!(/^(\[([^\]]+)\])+ */, '')
			description = @plugin.send(:remove_tag, body).strip
			subtitle = @conf.shorten(description, 20) if subtitle.empty?
			item.title = subtitle
			item.description = description
			item.content_encoded = fix_body_link(body, base_uri)
			item.dc_creator = @conf.author_name
			section.categories.each do |category|
				item.dc_subjects.new_subject do |subject|
					subject.content = category
				end
				category_path = Category.path(@conf, category)
				item.taxo_topics.resources << base_uri + category_path
			end
		end

		def fix_body_link(body, base_uri)
			host_uri = URI(base_uri)
			host_uri.path = ""
			host_uri.query = nil
			host_uri = host_uri.to_s
			fix_link(body) do |link_attribute, prefix, link|
				uri = URI(link)
				if uri.absolute? or link[0] == ?#
					link_attribute
				else
					if link[0] == ?/
						link = host_uri + link
					else
						link = base_uri + link
					end
					%Q[#{prefix}="#{link}"]
				end
			end
		end

		def normalize_last_modified(last_modified)
			return last_modified if (1..22).include?(Time.now.hour)
			next_day = last_modified + 60 * 60 * 24
			seconds, minutes, hours, *others = next_day.to_a
			if last_modified.utc?
				normalized_last_modified = Time.utc(0, 0, 0, *others)
			else
				normalized_last_modified = Time.local(0, 0, 0, *others)
			end
			normalized_last_modified - 1
		end

		def normalize_output(output)
			output
		end
	end

	class Main < TDiary::TDiaryBase
		include Image

		def initialize(cgi, dest, conf, src=nil)
			super(cgi, nil, conf)
			calendar
			@dest = dest
			@src = src || './'
			init_image_dir
		end

		def run
			@date = Time.now
			load_plugins
			copy_images

			all_days = archive_days
			archive_categories
			archive_latest(all_days)

 			make_rss
			copy_theme
			copy_js
		end

		private
		def copy_images
			image_src_dir = @plugin.instance_variable_get("@image_dir")
			image_src_dir = Pathname(image_src_dir)
			unless image_src_dir.absolute?
				image_src_dir = Pathname(@src) + image_src_dir
			end
			@image_dest_dir.rmtree if @image_dest_dir.exist?
			if image_src_dir.exist?
				copy_recursive(image_src_dir, @image_dest_dir)
			end
		end

		def archive_days
			all_days = []
			@years.keys.sort.each do |year|
				@years[year].sort.each do |month|
					month_time = Time.local(year.to_i, month.to_i)
					month = Month.new(month_time, @dest, conf)
 					month.save
					month.send(:each_day) do |diary|
						all_days << diary.date
 						Day.new(diary, @dest, conf).save
					end
				end
			end
			all_days
		end

		def archive_categories
			categories = []
			cache = @plugin.instance_variable_get("@category_cache")
			cache.recreate(@years)
			cache.categorize([], @years).each do |name, diaries|
				next if name.empty?
				categorized_diaries = {}
				diaries.keys.each do |date|
					date_time = Time.local(*date.scan(/^(\d{4})(\d\d)(\d\d)$/)[0])
					@io.transaction(date_time) do |diaries|
						categorized_diaries[date] = diaries[date]
						DIRTY_NONE
					end
				end
				category = Category.new(name, categorized_diaries, @dest, conf)
 				categories << category if category.save
			end

			return if categories.empty?
			htaccess = categories.first.output_directory + ".htaccess"
			htaccess.open("w") do |f|
				categories.each do |category|
					original_name_page = "#{category.original_name}.html"
					normalized_name_page = "#{category.normalized_name}.html"
					next if original_name_page == normalized_name_page
					f.puts("RedirectMatch permanent " +
							 "\"(.*)/#{Regexp.escape(original_name_page)}$\" " +
							 "\"$1/#{normalized_name_page}\"")
				end
			end
		end

		def archive_latest(all_days)
			conf["latest.path"] = {}

			latest_days = []
			all_days.reverse.each_slice(conf.latest_limit) do |days|
				latest_days << days
			end

			latest_days.each_with_index do |days, i|
				date = days.first.strftime("%Y%m%d")
				if i.zero?
					latest_path = "./"
				else
					latest_path = "latest/#{i}.html"
				end
				conf["latest.path"][date] = latest_path
			end
			latest_days.each_with_index do |days, i|
				latest = Latest.new(days.first, i, @dest, conf)
				latest.save
				conf["ndays.prev"] = nil
				conf["ndays.next"] = nil
			end
		end

		def make_rss
			RSS.new(@dest, conf).save
		end

		def copy_theme
			theme_dir = @dest + "theme"
			theme_dir.rmtree if theme_dir.exist?
			theme_dir.mkpath
			tdiary_theme_dir = Pathname(File.join(TDiary::PATH, "theme"))
			base_css = tdiary_theme_dir + "base.css"
			dest_base_css = theme_dir + "base.css"
			FileUtils.cp(base_css.to_s, dest_base_css.to_s)
			FileUtils.touch(dest_base_css.to_s, :mtime => base_css.mtime)
			if @conf.theme
				copy_recursive(tdiary_theme_dir + @conf.theme,
									theme_dir + @conf.theme)
			end
		end

		def copy_js
			js_dir = @dest + "js"
			js_dir.rmtree if js_dir.exist?
			js_dir.mkpath
			tdiary_js_dirs = [
				Pathname(File.join(TDiary::PATH, "js")),
				Pathname(File.join(TDiary::PATH, "contrib", "js")),
			]
			tdiary_js_dirs.each do |tdiary_js_dir|
				copy_recursive(tdiary_js_dir, js_dir)
			end
		end

		def copy_recursive(source, destination)
			destination.mkdir unless destination.exist?
			source.each_entry do |entry|
				next if entry.to_s == "." or entry.to_s == ".."
				full_source_path = source + entry
				if full_source_path.directory?
					next if entry.to_s == ".svn"
					sub_directory = destination + entry
					sub_directory.mkdir unless sub_directory.exist?
					copy_recursive(full_source_path, sub_directory)
				else
					FileUtils.cp(full_source_path.to_s, destination.to_s)
					FileUtils.touch((destination + entry).to_s,
										 :mtime => full_source_path.mtime)
				end
			end
		end
	end
end

cgi = HTMLArchiver::CGI.new
conf = nil
Dir.chdir(options.conf_dir) do
	begin
		original_program_name = $PROGRAM_NAME
		$PROGRAM_NAME = File.basename($PROGRAM_NAME)
		request = TDiary::Request.new({}, cgi)
		conf = TDiary::Config.new(nil, request)
	ensure
		$PROGRAM_NAME = original_program_name
	end
end
conf.show_comment = true
conf.hide_comment_form = true
def conf.bot?; false; end
output_dir ||= Pathname(conf.data_path) + "cache" + "html"
output_dir = Pathname(output_dir).expand_path
output_dir.mkpath
Dir.chdir(options.conf_dir) do
	HTMLArchiver::Main.new(cgi, output_dir, conf, options.conf_dir).run
end
