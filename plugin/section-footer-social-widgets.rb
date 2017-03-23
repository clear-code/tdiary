# -*- coding: utf-8; indent-tabs-mode: t; ruby-indent-level: 3; tab-width: 3 -*-
#
# Copyright (C) 2011-2015  Kouhei Sutou <kou@clear-code.com>
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

facebook_use_iframe = false

add_header_proc do
	tags = ""
  if @conf['social_widgets.facebook_user_id']
    tags << <<-HTML
  <meta property="fb:admins"
        content="#{h(@conf['social_widgets.facebook_user_id'])}">
	  HTML
  end
  if @conf['social_widgets.facebook_application_id']
    tags << <<-HTML
    <meta property="fb:app_id"
          content="#{h(@conf['social_widgets.facebook_application_id'])}">
	  HTML
  end
  tags << <<-HTML
  <meta property="og:locale" content="ja_JP">
	HTML
  tags
end

def section_footer_social_widgets_footer_scripts
	<<-HTML
  <script type="text/javascript"
          src="//b.st-hatena.com/js/bookmark_button.js"
          charset="utf-8"
          async="async"></script>
  <script type="text/javascript"
          src="//b.hatena.ne.jp/js/widget.js"
          charset="utf-8"></script>
  <script src="//platform.twitter.com/widgets.js"
          type="text/javascript">
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
	unescaped_url = "#{@conf.base_url}#{anchor(date_ymd)}"
	url = h(unescaped_url)
	subtitle = @subtitles[date][index]
	date_label = date.strftime('%Y-%m-%d')
	entry_title = h("#{subtitle} - #{@html_title}(#{date_label})")
	widgets = "<div class=\"social-widgets\">\n"
	widgets << "  <div class=\"inline-social-widgets\">\n"
	widgets << <<-HATENA
<a href="//b.hatena.ne.jp/entry/#{url}"
   class="hatena-bookmark-button"
   data-hatena-bookmark-layout="standard"
   title="このエントリーをはてなブックマークに追加"
   ><img src="//b.st-hatena.com/images/entry-button/button-only.gif"
         width="20"
         height="20"
         style="border: none;"
         alt="このエントリーをはてなブックマークに追加"></a>
HATENA
	widgets << <<-TWITTER_SHARE
<a href="//twitter.com/share"
   class="twitter-share-button"
   data-lang="ja"
   data-url="#{url}"
   data-via="#{h(@conf['twitter.user'])}"
   data-text="#{entry_title}">ツイートする</a>
TWITTER_SHARE
	widgets << "  </div>\n"
	widgets << <<-TWITTER_FOLLOW
<div class="social-widget-twitter-follow">
  <a href="//twitter.com/#{h(@conf['twitter.user'])}"
	  class="twitter-follow-button"
	  data-lang="ja">フォローする</a>
</div>
TWITTER_FOLLOW

	facebook_like_parameters = {
		:href => unescaped_url,
		:send => "true",
		:width => @conf["social_widgets.facebook_like_width"],
		:show_faces => "true",
	}
	if facebook_use_iframe
		html_parameters = facebook_like_parameters.collect do |key, value|
			"#{h(key)}=#{h(value)}"
		end.join("&amp;")
		widgets << <<-FACEBOOK_LIKE
<iframe src="//www.facebook.com/plugins/like.php?#{html_parameters}"
        scrolling="no"
        frameborder="0"
        style="border:none;
               overflow:hidden;
               width:#{facebook_like_parameters[:width]}px;"
        allowTransparency="true"></iframe>
FACEBOOK_LIKE
	else
      attributes = facebook_like_parameters.collect do |key, value|
			"data-#{key.to_s.gsub(/_/, '-')}=\"#{h(value)}\""
		end.join("    \n")
		widgets << <<-FACEBOOK_LIKE
<div class="social-widget-facebook">
  <div class="fb-like"
       #{attributes}></div>
</div>
FACEBOOK_LIKE
	end

	facebook_comments_parameters = {
		:href => unescaped_url,
		:width => @conf["social_widgets.facebook_comments_width"],
	}
	if facebook_use_iframe
		html_parameters = facebook_comments_parameters.collect do |key, value|
			"#{h(key)}=#{h(value)}"
		end.join("&amp;")
		widgets << <<-FACEBOOK_COMMENTS
<iframe src="//www.facebook.com/plugins/comments.php?#{html_parameters}"
        scrolling="no"
        frameborder="0"
        style="border:none; overflow:hidden; width:#{facebook_comments_parameters[:width]}px;"
        allowTransparency="true"></iframe>
FACEBOOK_COMMENTS
	else
      attributes = facebook_like_parameters.collect do |key, value|
			"data-#{key.to_s.gsub(/_/, '-')}=\"#{h(value)}\""
		end.join("    \n")
		widgets << <<-FACEBOOK_COMMENTS
<div class="social-widget-facebook">
  <div class="fb-comments"
		 #{attributes}></div>
</div>
FACEBOOK_COMMENTS
	end

	widgets << "</div>\n"
	widgets
end
