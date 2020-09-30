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
require "ostruct"
require "yaml"

require "rd/rdfmt"
require "rd/rdvisitor"

options = OpenStruct.new
options.data_dir = "data"
options.output_dir = "jekyll"
opts = OptionParser.new do |opts|
  opts.on("--data-dir=DIR",
          "The directory that has tDiary data") do |dir|
    options.data_dir = dir
  end

  opts.on("--output-dir=DIR",
          "The directory that holds exported data") do |dir|
    options.output_dir = dir
  end
end
opts.parse!

class RDParser
  class Visitor < RD::Visitor
    def initialize
      @title = nil
      @categories = []
      @footnotes = []
      @foottexts = []
      super
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
      title = contents.join("")
      while /\A\[(.+?)\]/ =~ title
        @categories << $1
        title = $POSTMATCH
      end
      @title = title.strip
      "#{marks} #{@title}"
    end

    def apply_to_StringElement(element)
      # TODO: escape
      element.content
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
      "TODO: #{__method__}"
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
      "TODO: #{__method__}"
    end

    def apply_to_EnumListItem(element, contents)
      "TODO: #{__method__}"
    end

    def apply_to_DescList(element, contents)
      "TODO: #{__method__}"
    end

    def apply_to_DescListItem(element, term, description)
      "TODO: #{__method__}"
    end

    def apply_to_DescListItemTerm(element, contents)
      "TODO: #{__method__}"
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
    def normalize_lanaguage(language)
      case language
      when "glibc"
        "c"
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
  end

  def initialize(headers, body)
    @headers = headers
    @body = body
  end

  def parse
    source = "=begin\n#{@body}\n=end\n"
    tree = RD::RDTree.new(source)
    visitor = Visitor.new
    markdown = visitor.visit(tree)
    [visitor.metadata, markdown]
  end
end

class JekyllExporter
  def initialize(data_dir, output_dir)
    @data_dir = data_dir
    @output_dir = output_dir
  end

  def export
    FileUtils.mkdir_p(@output_dir)
    td2_paths = Dir.glob(File.join(@data_dir, "????", "*.td2"))
    td2_paths.sort.each do |td2_path|
      File.open(td2_path) do |td2_file|
        parse_td2(td2_file) do |headers, body|
          parse_diary(headers, body)
        end
      end
    end
  end

  private
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
    case headers["Format"]
    when "RD"
      metadata, markdown = parse_diary_rd(headers, body)
    when "Markdown"
      metadata, markdown = parse_diary_markdown(headers, body)
    end
    date = headers["Date"].strftime("%Y-%m-%d")
    slug = metadata["slug"] || "index"
    output_path = File.join(@output_dir, "#{date}-#{slug}.md")
    File.open(output_path, "w") do |output|
      output.puts(<<-JEKYLL_MARKDOWN)
#{metadata.to_yaml.strip}
---
#{markdown.strip}
      JEKYLL_MARKDOWN
    end
  end

  def parse_diary_rd(headers, body)
    parser = RDParser.new(headers, body)
    parser.parse
  end

  def parse_diary_markdown(headers, body)
    [{}, ""]
  end
end

exporter = JekyllExporter.new(options.data_dir, options.output_dir)
exporter.export
