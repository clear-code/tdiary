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

add_header_proc do
	<<-HTML
  <meta property="fb:admins"
        content="#{h(@conf['social_widgets.facebook_user_id'])}" />
  <meta property="fb:app_id"
        content="#{h(@conf['social_widgets.facebook_application_id'])}" />
  <script type="text/javascript"
          src="http://b.st-hatena.com/js/bookmark_button.js"
          charset="utf-8"
          async="async"></script>
  <script src="http://platform.twitter.com/widgets.js"
          type="text/javascript"></script>
  <script src="http://connect.facebook.net/ja_JP/all.js"></script>
  <script>
  window.fbAsyncInit = function() {
	 FB.init({
		appId  : '#{h(@conf['social_widgets.facebook_application_id'])}',
		status : true, // check login status
		cookie : true, // enable cookies to allow the server to access the session
		xfbml  : true  // parse XFBML
	 });
  };
  </script>
   HTML
end

fb_root = '<div id="fb-root"></div>'
unless @conf.header.include?(fb_root)
	@conf.header << fb_root
end

add_section_enter_proc do |date, index|
	@subtitles = {date => {}}
	''
end

subtitle_proc = Proc.new do |date, index, subtitle|
	@subtitles[date][index] = subtitle.gsub(/(?:\[.*?\])/, '').strip
	""
end
@subtitle_procs.unshift(subtitle_proc)

add_section_leave_proc do |date, index|
	date_ymd = date.strftime('%Y%m%d')
	url = h("#{@conf.base_url}#{anchor(date_ymd)}")
	subtitle = @subtitles[date][index]
	entry_title = h("#{subtitle} - #{@html_title}(#{date_ymd})")
	widgets = "<div class=\"social-widgets\">\n"
	widgets << "  <div class=\"inline-social-widgets\">\n"
	widgets << <<-HATENA
<a href="http://b.hatena.ne.jp/entry/#{url}"
   class="hatena-bookmark-button"
   data-hatena-bookmark-layout="standard"
   title="このエントリーをはてなブックマークに追加"
   ><img src="http://b.st-hatena.com/images/entry-button/button-only.gif"
         width="20"
         height="20"
         style="border: none;"
         alt="このエントリーをはてなブックマークに追加" /></a>
HATENA
	widgets << <<-TWITTER
<a href="http://twitter.com/share"
   class="twitter-share-button"
   data-lang="ja"
   data-url="#{url}"
   data-text="#{entry_title}">ツイートする</a>
TWITTER
	widgets << "  </div>\n"
	widgets << <<-FACEBOOK_LIKE
<fb:like layout="standard"
         width="#{@conf["social_widgets.facebook_like_width"]}"
         href="#{url}"></fb:like>
FACEBOOK_LIKE
	widgets << <<-FACEBOOK_COMMENTS
<fb:comments href="#{url}"
             width="#{@conf["social_widgets.facebook_comments_width"]}"></fb:comments>
FACEBOOK_COMMENTS
	widgets << "</div>\n"
	widgets
end
