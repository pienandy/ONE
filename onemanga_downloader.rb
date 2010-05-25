#!/usr/bin/env ruby
#
# Put this script in your PATH and download from onemanga.com like this:
#   onemanga_downloader.rb Bleach [chapter number]
#
# You will find the downloaded chapters under $HOME/Documents/OneManga/Bleach
#
# If you run this script without arguments, it will check your local manga downloads
# and check if there are any new chapters
#
# Updates
# 05/24 - taking into account redirection to 1000manga.com and age verification cookie
require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'open-uri'

manga_root = "http://www.onemanga.com/"
manga_download_folder = File.join(ENV['HOME'],"/Documents/OneManga/")
agent = Mechanize.new { |agent| agent.user_agent_alias = 'Mac Safari' }

if ARGV.size == 0
  # no args means just to check for new chapters
  mangas = Dir.glob(File.join(manga_download_folder, "*")).map do |f| 
      f.gsub(manga_download_folder, '')
    end
  mangas.each do |manga_name|
    downloaded_chapters = Dir.glob(File.join(manga_download_folder, manga_name, "*")).map do |f| 
        f.gsub(File.join(manga_download_folder, manga_name, "/"), "").to_i
      end.sort
    last_chapter = downloaded_chapters.last
    # index page
    agent.get(manga_root + manga_name)

    # find chapter
    chapters = agent.page.links.map do |l| 
      $1.to_i if l.href =~ /#{manga_name}\/(\d+)/
    end.compact.sort
    most_recent_chapter = chapters.last
    puts "#{last_chapter}/#{most_recent_chapter} - #{manga_name}"
  end
  exit 0 # go away
end

manga_name = ARGV.first || "Bakuman"
start_from_chapter = ARGV.size > 1 ? ARGV[1] : nil

manga_folder = File.join(manga_download_folder, manga_name)
puts "Creating #{manga_folder}"
FileUtils.mkdir_p(manga_folder)

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

another_site = agent.page.link_with(:text => "Read this series at 1000manga.com")
if another_site
  agent.get :url => another_site.href, :referer => agent.page, :headers => { "cookie" => "age_verified=30" }
end

# first time in a chapter starts with "Begin reading ..."
agent.get :url => agent.page.links.select { |l| l.text =~ /Begin/ }.first.href, :referer => agent.page, :headers => { "cookie" => "age_verified=30" }
  
chapter_number = nil
chapter_folder = ""

# go all the way. the navigation stop in the last chapter with a bookmark link
while (agent.page / "#id_bookmark_click").empty?
  break if agent.page.forms.empty?
  
  # create the chapter folder if it changes
  current_chapter_number = agent.page.uri.to_s.split("/")[-2] # /[manga]/[chapter]/[page]
  if chapter_number != current_chapter_number
    chapter_number = current_chapter_number
    chapter_folder = File.join(manga_download_folder, manga_name, chapter_number)
    puts "Creating #{chapter_folder}"
    FileUtils.mkdir_p(chapter_folder)
  end
  
  # download image file
  img_uri = agent.page.search("//img[@class='manga-page']").first["src"]
  image_file = File.join(chapter_folder, img_uri.split("/").last)
  open(image_file, 'wb') do |file|
    puts "Downloading #{img_uri} to #{image_file}"
    file.write(open(img_uri).read)
  end
  
  # next page
  agent.get :url => agent.page.links.select { |link| link.text.strip.empty? }.first.href, :referer => agent.page, :headers => { "cookie" => "age_verified=30" }
end
