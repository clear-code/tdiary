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
	tags = ""
  if @conf['social_widgets.facebook_user_id']
    tags << <<-HTML
  <meta property="fb:admins"
        content="#{h(@conf['social_widgets.facebook_user_id'])}" />
	  HTML
  end
  if @conf['social_widgets.facebook_application_id']
    tags << <<-HTML
    <meta property="fb:app_id"
          content="#{h(@conf['social_widgets.facebook_application_id'])}" />
	  HTML
  end
  tags << <<-HTML
  <meta property="og:locale" content="ja_JP" />
	HTML
  tags
end

def section_footer_social_widgets_footer_scripts
	<<-HTML
  <script type="text/javascript"
          src="http://b.st-hatena.com/js/bookmark_button.js"
          charset="utf-8"
          async="async"></script>
  <script type="text/javascript"
          src="http://b.hatena.ne.jp/js/widget.js"
          charset="utf-8"></script>
  <script src="http://platform.twitter.com/widgets.js"
          type="text/javascript"></script>
  <script type="text/javascript" src="http://apis.google.com/js/plusone.js">
    {lang: 'ja'}
  </script>
   HTML
end

fb_root = '<div id="fb-root"></div>'
unless @conf.header.include?(fb_root)
  options = {"xfbml" => 1}
  if @conf['social_widgets.facebook_application_id']
    options = {"appId" => @conf['social_widgets.facebook_application_id']}
  end
  escaped_options = options.collect do |key, value|
    "#{key}=#{h(value)}"
  end
  options_in_url = escaped_options.join("&")
	fb_header = <<-END_OF_FB_JS_SDK
#{fb_root}
<script>(function(d, s, id) {
  var js, fjs = d.getElementsByTagName(s)[0];
  if (d.getElementById(id)) return;
  js = d.createElement(s); js.id = id;
  js.src = "//connect.facebook.net/ja_JP/all.js\##{options_in_url}";
  fjs.parentNode.insertBefore(js, fjs);
}(document, 'script', 'facebook-jssdk'));</script>
END_OF_FB_JS_SDK
	@conf.header = "#{fb_header}\n#{@conf.header}"
end

add_section_enter_proc do |date, index|
	@subtitles = {date => {}}
	''
end

subtitle_proc = Proc.new do |date, index, subtitle|
	@subtitles[date][index] = subtitle.gsub(/(?:\[.*?\])/, '').strip
	subtitle
end
@subtitle_procs.unshift(subtitle_proc)

add_section_leave_proc do |date, index|
	date_ymd = date.strftime('%Y%m%d')
	url = h("#{@conf.base_url}#{anchor(date_ymd)}")
	subtitle = @subtitles[date][index]
	date_label = date.strftime('%Y-%m-%d')
	entry_title = h("#{subtitle} - #{@html_title}(#{date_label})")
	widgets = "<div class=\"social-widgets\">\n"
	widgets << "  <div class=\"inline-social-widgets\">\n"
	widgets << <<-GOOGLE_PLUSONE
<g:plusone href="#{url}" size="medium"></g:plusone>
GOOGLE_PLUSONE
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
	widgets << <<-TWITTER_SHARE
<a href="http://twitter.com/share"
   class="twitter-share-button"
   data-lang="ja"
   data-url="#{url}"
   data-via="#{h(@conf['twitter.user'])}"
   data-text="#{entry_title}">ツイートする</a>
TWITTER_SHARE
	widgets << "  </div>\n"
	widgets << <<-TWITTER_FOLLOW
<div class="social-widget-twitter-follow">
  <a href="http://twitter.com/#{h(@conf['twitter.user'])}"
	  class="twitter-follow-button"
	  data-lang="ja">フォローする</a>
</div>
TWITTER_FOLLOW
	widgets << <<-FACEBOOK_LIKE
<div class="social-widget-facebook">
  <div class="fb-like"
		 data-send="true"
		 data-href="#{url}"
		 data-width="#{@conf["social_widgets.facebook_like_width"]}"
		 data-show-faces="true"></div>
</div>
FACEBOOK_LIKE
	widgets << <<-FACEBOOK_COMMENTS
<div class="social-widget-facebook">
  <div class="fb-comments"
		 data-href="#{url}"
		 data-width="#{@conf["social_widgets.facebook_comments_width"]}"></div>
</div>
FACEBOOK_COMMENTS
	widgets << "</div>\n"
	widgets
end
