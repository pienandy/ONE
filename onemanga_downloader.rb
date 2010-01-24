#!/usr/bin/env ruby
#
# Put this script in your PATH and download from onemanga.com like this:
#   onemanga_downloader.rb Bleach [chapter number]
#
# You will find the downloaded chapters under /tmp/Bleach
#
require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'open-uri'

manga_root = "http://www.onemanga.com/"
manga_name = ARGV.first || "Bakuman"
start_from_chapter = ARGV.size > 1 ? ARGV[1] : nil

manga_folder = File.join("/tmp", manga_name)
puts "Creating #{manga_folder}"
FileUtils.mkdir_p(manga_folder)

agent = WWW::Mechanize.new { |agent| agent.user_agent_alias = 'Mac Safari' }

# index page
agent.get(manga_root + manga_name)

# find chapter
chapter_link = agent.page.links.select do |l| 
    if start_from_chapter
      l.href =~ /#{manga_name}\/#{start_from_chapter}\//
    else
      l.href =~ /#{manga_name}\/\d+/
    end
  end.reverse.first

# click the chapter link in the index page
agent.click chapter_link

# first time in a chapter starts with "Begin reading ..."
agent.click agent.page.links.select { |l| l.text =~ /Begin/ }.first
  
chapter_number = nil
chapter_folder = ""

# go all the way. the navigation stop in the last chapter with a bookmark link
while (agent.page / "#id_bookmark_click").empty?
  break if agent.page.forms.empty?
  
  # create the chapter folder if it changes
  current_chapter_number = agent.page.forms.last.fields.select { |f| f.name == 'chapter' }.first.value
  if chapter_number != current_chapter_number
    chapter_number = current_chapter_number
    chapter_folder = File.join("/tmp", manga_name, chapter_number)
    puts "Creating #{chapter_folder}"
    FileUtils.mkdir_p(chapter_folder)
  end
  
  # download image file
  img_uri = (agent.page / ".manga-page").first['src']
  image_file = File.join(chapter_folder, img_uri.split("/").last)
  open(image_file, 'wb') do |file|
    puts "Downloading #{img_uri} to #{image_file}"
    file.write(open(img_uri).read)
  end
  
  # next page
  agent.click agent.page.links.select { |link| link.text =~ /\n/ }.first
end