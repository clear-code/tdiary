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

require "rd/rdfmt"
require "rd/rdvisitor"

class RDParser
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

  class Visitor < RD::Visitor
    def initialize(context)
      @context = context
      @title = nil
      @categories = []
      @footnotes = []
      @foottexts = []
      super()
    end

    def metadata
      {
        "categories" => @categories,
        "title" => @title,
      }
    end

    def apply_to_DocumentElement(element, contents)
      contents = contents.collect do |content|
        case content
        when Array
          content.flatten.join("\n")
        else
          content
        end
      end
      (contents + @foottexts).join("\n\n")
    end

    def apply_to_Headline(element, contents)
      marks = "#" * (element.level + 1)
      headline = contents.join("")
      while /\A\[(.+?)\]/ =~ headline
        @categories << $1
        headline = $POSTMATCH
      end
      headline = headline.strip
      if element.level == 1
        @title = headline
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
      paragraph.strip
    end

    def apply_to_Verbatim(element)
      case element.content.first.chomp
      when /\A# source:\s*(.+?)\z/
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
        format_image(*plugin_call.args)
      when :isbn_detail
        format_isbn(*plugin_call.args)
      when :bugzilla
        format_bugzilla(*plugin_call.args)
      else
        "TODO: #{__method__}: #{plugin_call.name}"
      end
    end

    def resolve_image_url(index)
      image_path_glob = @context.date.strftime("%Y%m%d_#{index}.*")
      image_path =
        Pathname.glob(@context.images_output_dir + image_path_glob).first
      "#{@context.images_path}/#{image_path.basename}"
    end

    def format_image(index, alt, thumbnail_index, size=nil)
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

    def format_isbn(isbn)
      "https://amazon.co.jp/dp/#{isbn}"
    end

    def format_bugzilla(id)
      "[#{id}](https://bugzilla.mozilla.org/show_bug.cgi?id=#{id})"
    end

    def apply_to_Emphasis(element, contents)
      "TODO: #{__method__}"
    end

    def apply_to_Var(element, contents)
      "TODO: #{__method__}"
    end

    def apply_to_Index(element, contents)
      "TODO: #{__method__}"
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
      [*term, "\n<dd>\n", *description, "\n</dd>\n"]
    end

    def apply_to_DescListItemTerm(element, contents)
      ["\n<dt>\n", *contents, "\n</dt>\n"]
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
      else
        language
      end
    end

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

class JekyllExporter
  class Context
    attr_accessor :date
    attr_accessor :data_dir
    attr_accessor :posts_output_dir
    attr_accessor :images_output_dir
    attr_accessor :images_path
    def initialize
      @date = nil
      @data_dir = "data"
      @posts_output_dir = "_posts"
      @images_output_dir = "images/blog"
      @images_path = "/images/blog"
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
    [{}, ""]
  end
end

exporter = JekyllExporter.new
exporter.export(ARGV)
