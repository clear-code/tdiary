#!/usr/bin/env ruby
# -* indent-tabs-mode: nil -*-
#
# Copyright (C) 2020  Sutou Kouhei <kou@clear-code.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "English"
require "cgi/util"
require "date"
require "fileutils"
require "optparse"
require "pathname"
require "yaml"

require "commonmarker"
require "rd/rdfmt"
require "rd/rdvisitor"

module TitleParsable
  def parse_title(title)
    tags = []
    while /\A\[(.+?)\]/ =~ title
      tags << normalize_tag($1)
      title = $POSTMATCH.strip
    end
    [title, tags]
  end

  def normalize_tag(tag)
    case tag
    when "テスト"
      "test"
    when "会社"
      "company"
    when "インターンシップ"
      "internship"
    when "クリアなコード"
      "clear-code"
    when "フィードバック"
      "feedback"
    when "ノータブルコード"
      "notable-code"
    when "milter manager"
      "milter-manager"
    else
      tag.downcase
    end
  end
end

class PluginCall < BasicObject
  attr_reader :name
  attr_reader :args
  def initialize(plugin_call)
    instance_eval(plugin_call)
  end

  def method_missing(name, *args)
    @name = name
    @args = args
  end
end

class ImageFormatter
  def initialize(context)
    @context = context
  end

  def format(index, alt, thumbnail_index, size=nil)
    image_url = resolve_image_url(index)
    # TODO: Support size
    if thumbnail_index
      thumbnail_url = resolve_image_url(thumbnail_index)
      "[" +
        "![#{alt}]({{ \"#{thumbnail_url}\" | relative_url }} \"#{alt}\")" +
        "]({{ \"#{image_url}\" | relative_url }})"
    else
      "![#{alt}]({{ \"#{image_url}\" | relative_url }} \"#{alt}\")"
    end
  end

  private
  def resolve_image_url(index)
    image_path_glob = @context.date.strftime("%Y%m%d_#{index}.*")
    image_path =
      Pathname.glob(@context.images_output_dir + image_path_glob).first
    "#{@context.images_path}/#{image_path.basename}"
  end
end

class ISBNFormatter
  def format(isbn, label=nil)
    url = "https://amazon.co.jp/dp/#{isbn}"
    "[#{label || url}](#{url})"
  end
end

class YouTubeFormatter
  def format(id)
    <<-HTML
<div class="youtube-4x3">
  <iframe width="425"
          height="350"
          src="https://www.youtube.com/embed/#{id}"
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen></iframe>
</div>
    HTML
  end
end

module TextProcessable
  def prepend(target, prefix)
    case target
    when Array
      target.collect do |t|
        prepend(t, prefix)
      end
    else
      "#{prefix}#{target}"
    end
  end

  def around(target, prefix, postfix)
    case target
    when Array
      target.collect do |t|
        around(t, prefix, postfix)
      end
    else
      "#{prefix}#{target}#{postfix}"
    end
  end

  def flatten(contents)
    contents.collect do |content|
      case content
      when Array
        content.flatten.join("\n")
      else
        content
      end
    end
  end
end

class RDParser
  class Visitor < RD::Visitor
    include TitleParsable
    include TextProcessable

    def initialize(context)
      @context = context
      @first_paragraph = true
      @title = nil
      @tags = []
      @footnotes = []
      @foottexts = []
      super()
    end

    def metadata
      {
        "tags" => @tags,
        "title" => @title,
      }
    end

    def apply_to_DocumentElement(element, contents)
      contents = flatten(contents)
      (contents + @foottexts).join("\n\n")
    end

    def apply_to_Headline(element, contents)
      marks = "#" * (element.level + 1)
      headline = contents.join("").strip
      if element.level == 1
        @title, @tags = parse_title(headline)
        ""
      else
        "#{marks} #{headline}"
      end
    end

    def apply_to_StringElement(element)
      escape(element.content)
    end

    def apply_to_Reference_with_RDLabel(element, contents)
      if element.label.filename
        "TODO: #{__method__}: filename #{element.label.filename}"
      else
        label = element.to_label
        prefix, option = label.split(/:/, 2)
        case prefix
        when "wikipedia"
          "[#{option}](https://ja.wikipedia.org/wiki/#{CGI.escape(option)})"
        when "wikipedia-en"
          "[#{option}](https://en.wikipedia.org/wiki/#{CGI.escape(option)})"
        when /\A(\d{4})(\d{2})(\d{2})\z/
          year = $1
          month = $2
          day = $3
          if option.nil?
            title = contents.join("").strip
            "[#{title}]({% post_url #{year}-#{month}-#{day}-index %})"
          else
            "TODO: #{__method__}: #{label}"
          end
        else
          "TODO: #{__method__}: #{label}"
        end
      end
    end

    def apply_to_Reference_with_URL(element, contents)
      title = contents.join("").strip
      url = element.label.url
      "[#{title}](#{url})"
    end

    def apply_to_TextBlock(element, contents)
      paragraph = contents.join("")
      paragraph = paragraph.strip
      if @first_paragraph
        paragraph << "\n#{@context.excerpt_separator}\n"
        @first_paragraph = false
      end
      paragraph
    end

    def apply_to_Verbatim(element)
      case element.content.first.chomp
      when /\A#\s*html\z/
        return element.content[1..-1].join("")
      when /\A#\s*html-demo\z/
        language = "html"
        content = element.content[1..-1].join("")
      when /\A#\s*source:\s*(.+?)\z/
        language = $1
        content = element.content[1..-1].join("")
      else
        language = ""
        content = element.content.join("")
      end
      language = normalize_lanaguage(language)
      "{% raw %}\n```#{language}\n#{content}```\n{% endraw %}"
    end

    def apply_to_Keyboard(element, contents)
      plugin_call = PluginCall.new(contents.join(""))
      case plugin_call.name
      when :image
        ImageFormatter.new(@context).format(*plugin_call.args)
      when :isbn, :isbn_detail
        ISBNFormatter.new.format(*plugin_call.args)
      when :bugzilla
        format_bugzilla(*plugin_call.args)
      when :youtube_div
        YouTubeFormatter.new.format(*plugin_call.args)
      when :nicovideo
        format_nicovideo(*plugin_call.args)
      when :ustream
        ""
      when :bq
        format_block_quote(*plugin_call.args)
      else
        "TODO: #{__method__}: #{plugin_call.name} #{plugin_call.args.inspect}"
      end
    end

    def format_bugzilla(id)
      "[#{id}](https://bugzilla.mozilla.org/show_bug.cgi?id=#{id})"
    end

    def format_nicovideo(id)
      <<-HTML
<div class="nicovideo-thumbnail">
  <iframe width="312"
          height="176"
          src="https://ext.nicovideo.jp/thumb/#{id}"
          scrolling="no"
          style="border:solid 1px #ccc;"
          frameborder="0"></iframe>
</div>
      HTML
    end

    def format_block_quote(source, title=nil, url=nil)
      markdown = source.gsub(/^/, "> ")
      if url or title
        markdown << "\n"
        markdown << "<p class=\"source\">\n"
        markdown << "  <cite>"
        if url
          markdown << "<a href=\"#{CGI.escapeHTML(url)}\">"
        end
        if title
          markdown << CGI.escape(title)
        end
        if url
          markdown << "</a>"
        end
        markdown << "</cite>\n"
        markdown << "</p>"
        markdown << "\n"
      end
      markdown
    end

    def apply_to_Emphasis(element, contents)
      content = contents.join("")
      "*#{content}*"
    end

    def apply_to_Var(element, contents)
      variable = contents.join("")
      "<var>#{CGI.escapeHTML(variable)}</var>"
    end

    def apply_to_Index(element, contents)
      contents
    end

    def apply_to_ItemList(element, contents)
      prepend(contents, "  ")
    end

    def apply_to_ItemListItem(element, contents)
      [prepend(contents.first, "* "), *contents[1..-1]]
    end

    def apply_to_EnumList(element, contents)
      prepend(contents, "  ")
    end

    def apply_to_EnumListItem(element, contents)
      [
        around(contents.first, "1. ", "\n"),
        *prepend(contents[1..-1], "   "),
      ]
    end

    def apply_to_DescList(element, contents)
      ["<dl>", *contents, "</dl>"]
    end

    def apply_to_DescListItem(element, term, description)
      [*term, "<dd>", *description, "</dd>"].inject(["\n"]) do |result, item|
        result << item
        result << "\n"
        result
      end
    end

    def apply_to_DescListItemTerm(element, contents)
      ["<dt>", *contents, "</dt>"].inject(["\n"]) do |result, item|
        result << item
        result << "\n"
        result
      end
    end

    def apply_to_Footnote(element, contents)
      index = @footnotes.index(element)
      if index.nil?
        index = @footnotes.size
        @footnotes << element
        @foottexts << "[^#{index}]: #{contents.join("")}"
      end
      "[^#{index}]"
    end

    def apply_to_Code(element, contents)
      "`#{contents.join("")}`"
    end

    private
    def escape(content)
      content.gsub(/[{}]/x) do |text|
        escaped_characters = text.codepoints.collect do |codepoint|
          "&##{codepoint};"
        end
        escaped_characters.join("")
      end
    end

    def normalize_lanaguage(language)
      case language
      when "glibc", "C"
        "c"
      when "xhtml"
        "html"
      when "Makefile"
        "makefile"
      else
        language
      end
    end
  end

  def initialize(context, headers, body)
    @context = context
    @headers = headers
    @body = body
  end

  def parse
    source = "=begin\n#{@body}\n=end\n"
    tree = RD::RDTree.new(source)
    visitor = Visitor.new(@context)
    markdown = visitor.visit(tree)
    [visitor.metadata, markdown]
  end
end

class MarkdownParser
  include TitleParsable
  include TextProcessable

  def initialize(context, headers, body)
    @context = context
    @headers = headers
    @body = body
    @tags = []
    @title = nil
    @first_paragraph = true
    @indent = 0
    @foottexts = []
  end

  def parse
    prepared_body = process_plugin(@body)
    doc = CommonMarker.render_doc(prepared_body)
    markdown = visit(doc)
    [
      {
        "tags" => @tags,
        "title" => @title,
      },
      markdown,
    ]
  end

  private
  def process_plugin(text)
    processed_text = ""
    in_code_block = false
    text.each_line do |line|
      case line
      when /\A(?:```|~~~)/
        in_code_block = !in_code_block
        processed_text << line
      else
        if in_code_block
          processed_text << line
        else
          processed_text << line.gsub(/{{(.+?)}}/) do
            plugin_call_text = $1
            case plugin_call_text
            when /\A#/, /\A\//, /\A\s*matrix/
              "{% raw %}{{#{plugin_call_text}}}{% endraw %}"
            else
              plugin_call = PluginCall.new(plugin_call_text)
              case plugin_call.name
              when :fn
                format_footnote(*plugin_call.args)
              when :image
                ImageFormatter.new(@context).format(*plugin_call.args)
              when :isbn, :isbn_detail
                ISBNFormatter.new.format(*plugin_call.args)
              when :youtube_div
                YouTubeFormatter.new.format(*plugin_call.args)
              else
                raise "TODO: #{__method__}: #{plugin_call.name} #{plugin_call.args.inspect}"
              end
            end
          end
        end
      end
    end
    processed_text
  end

  def format_footnote(text)
    index = @foottexts.size
    @foottexts << "[^#{index}]: #{text}"
    "[^#{index}]"
  end

  def visit(node)
    contents = node.each.collect do |child|
      visit(child)
    end
    __send__("visit_#{node.type}", node, contents)
  end

  def visit_text(node, contents)
    node.string_content
  end

  def visit_header(node, contents)
    if node.header_level == 1
      @title, @tags = parse_title(contents.join("").strip)
      ""
    else
      markup = "#" * (node.header_level + 1)
      "#{markup} #{contents.join("")}"
    end
  end

  def visit_link(node, contents)
    url = node.url.force_encoding("UTF-8")
    label = flatten(contents).join("")
    case url
    when /\A(\d{4})(\d{2})(\d{2})\z/
      year = $1
      month = $2
      day = $3
      "[#{label}]({% post_url #{year}-#{month}-#{day}-index %})"
    else
      "[#{label}](#{url})"
    end
  end

  def visit_paragraph(node, contents)
    paragraph = contents.join("")
    if @first_paragraph
      paragraph << "\n#{@context.excerpt_separator}\n"
      @first_paragraph = false
    end
    paragraph
  end

  def visit_list_item(node, contents)
    contents
  end

  def prepend_one_level(target, one_level_prefix, deeper_level_prefix)
    case target
    when Array
      target.collect do |t|
        case t
        when Array
          prepend(t, deeper_level_prefix)
        else
          # XXX: Ad-hoc fix
          if t.start_with?("```")
            t.gsub(/^/) {"#{deeper_level_prefix}  "}
          else
            "#{one_level_prefix}#{t}"
          end
        end
      end
    else
      "#{one_level_prefix}#{target}"
    end
  end

  def visit_list(node, contents)
    case node.list_type
    when :bullet_list
      contents.collect {|content| prepend_one_level(content, "  * ", "  ")}
    when :ordered_list
      contents.collect {|content| prepend_one_level(content, "  1. ", "   ")}
    else
      raise "unknown list type: #{node.list_type}"
    end
  end

  def visit_softbreak(node, contents)
    "\n"
  end

  def visit_linebreak(node, contents)
    "\n\n"
  end

  def visit_code_block(node, contents)
    markdown = <<-MARKDOWN
```#{node.fence_info.force_encoding("UTF-8")}
#{node.string_content}```
    MARKDOWN
    if node.string_content.include?("{{")
      markdown = "{% raw %}\n#{markdown}{% endraw %}\n"
    end
    markdown
  end

  def visit_code(node, contents)
    "`#{node.string_content}`"
  end

  def visit_blockquote(node, contents)
    contents.inject("") do |result, content|
      result << "> #{content}\n"
      result
    end
  end

  def visit_emph(node, contents)
    "*#{contents.join("")}*"
  end

  def visit_html(node, contents)
    node.string_content
  end

  def visit_inline_html(node, contents)
    node.string_content
  end

  def visit_hrule(node, contents)
    "---"
  end

  def visit_strong(node, contents)
    "**#{contents.join("")}**"
  end

  def visit_image(node, contents)
    if contents.empty?
      return "![#{node.title}](#{node.url})"
    end
    pp node
    pp contents
    raise
  end

  def visit_document(node, contents)
    (contents + @foottexts).flatten.join("\n\n")
  end
end

class JekyllExporter
  class Context
    attr_accessor :date
    attr_accessor :data_dir
    attr_accessor :posts_output_dir
    attr_accessor :images_output_dir
    attr_accessor :images_path
    attr_accessor :excerpt_separator
    def initialize
      @date = nil
      @data_dir = "data"
      @posts_output_dir = "_posts"
      @images_output_dir = "images/blog"
      @images_path = "/images/blog"
      @excerpt_separator = "<!--more-->"
    end
  end

  def initialize
    @context = Context.new
    @diaries = {}
  end

  def export(args)
    parse_args!(args)
    export_images
    export_posts
  end

  private
  def parse_args!(args)
    parser = OptionParser.new
    parser.on("--data-dir=DIR",
              "The directory that has tDiary data",
              "(#{@context.data_dir})") do |dir|
      @context.data_dir = dir
    end
    parser.on("--posts-output-dir=DIR",
              "The directory that holds exported diaries",
              "(#{@context.posts_output_dir})") do |dir|
      @context.posts_output_dir = dir
    end
    parser.on("--images-output-dir=DIR",
              "The directory that holds exported images",
              "(#{@context.images_output_dir})") do |dir|
      @context.images_output_dir = dir
    end
    parser.on("--images-path=PATH",
              "The path that refers exported images",
              "(#{@context.images_path})") do |path|
      @context.images_path = path
    end
    parser.on("--excerpt-separator=SEPARATOR",
              "The except separator",
              "(#{@context.excerpt_separator})") do |separator|
      @context.excerpt_separator = separator
    end
    parser.parse!(args)
  end

  def export_images
    images_dir = Pathname.new(File.join(@context.data_dir, "images"))
    Pathname.glob(images_dir + "**" + "*.*") do |image_path|
      relative_image_path = image_path.relative_path_from(images_dir)
      output_image_path =
        Pathname.new(@context.images_output_dir) + relative_image_path
      FileUtils.mkdir_p(output_image_path.parent.to_s)
      FileUtils.cp(image_path.to_s, output_image_path.to_s)
    end
  end

  def export_posts
    td2_paths = Dir.glob(File.join(@context.data_dir, "????", "*.td2"))
    # td2_paths = Dir.glob(File.join(@context.data_dir, "2020", "202009.td2"))
    td2_paths.sort.each do |td2_path|
      File.open(td2_path) do |td2_file|
        parse_td2(td2_file) do |headers, body|
          next unless headers["Visible"]
          parse_diary(headers, body)
        end
      end
    end

    FileUtils.mkdir_p(@context.posts_output_dir)
    @diaries.each do |date, diary|
      id = diary[:id]
      metadata = diary[:metadata]
      markdown = diary[:markdown]
      output_path = File.join(@context.posts_output_dir, "#{id}.md")
      File.open(output_path, "w") do |output|
        output.puts(<<-JEKYLL_MARKDOWN)
#{metadata.to_yaml.strip}
---
#{markdown.strip}
        JEKYLL_MARKDOWN
      end
    end
  end

  def parse_td2(td2_file)
    first_line = td2_file.gets.chomp
    unless first_line == "TDIARY2.01.00"
      raise "unsupported format: #{first_line}"
    end
    in_header = true
    headers = {}
    body = ""
    td2_file.each_line(chomp: true) do |line, i|
      if in_header
        if line.empty?
          in_header = false
        else
          key, value = line.split(/:\s*/, 2)
          headers[key] = normalize_header_value(key, value)
        end
      else
        if line == "."
          yield(headers, body)
          in_header = true
          headers = {}
          body = ""
        else
          line = line.sub(/\A\./, "")
          body << "#{line}\n"
        end
      end
    end
  end

  def normalize_header_value(key, value)
    case key
    when "Date"
      Date.parse(value)
    when "Last-Modified"
      Time.at(Integer(value, 10))
    when "Visible"
      value == "true"
    else
      value
    end
  end

  def parse_diary(headers, body)
    @context.date = headers["Date"]
    case headers["Format"]
    when "RD"
      metadata, markdown = parse_diary_rd(headers, body)
    when "Markdown"
      metadata, markdown = parse_diary_markdown(headers, body)
    end
    date = headers["Date"].strftime("%Y-%m-%d")
    slug = metadata["slug"] || "index"
    id = "#{date}-#{slug}"
    @diaries[date] = {
      id: id,
      headers: headers,
      metadata: metadata,
      markdown: markdown
    }
  end

  def parse_diary_rd(headers, body)
    parser = RDParser.new(@context, headers, body)
    parser.parse
  end

  def parse_diary_markdown(headers, body)
    parser = MarkdownParser.new(@context, headers, body)
    parser.parse
  end
end

exporter = JekyllExporter.new
exporter.export(ARGV)
