#!/usr/bin/env ruby
# encoding: utf-8
require "tw"
require "MeCab"
require "fast_blank"
require "groonga"
require "mojinizer"
require "uuid"

$tagger = MeCab::Tagger.new

def tokenize text
  sentence_vowel, sentence_surface = [], []
  node = $tagger.parseToNode(text)
  while (node = node.next) do
    feat    = node.feature.split(",")
    yomi    = feat[-2].force_encoding("UTF-8")
    surface = node.surface.force_encoding("UTF-8")
    boin_array = yomi.split("").map {|char| char.romaji[-1] if char != "*" }
    sentence_surface << surface
    sentence_vowel   << boin_array.join()
  end
  return sentence_surface, sentence_vowel
end

def init_db path
  Groonga::Context.default_options = {encoding: :utf8}
  Groonga::Database.open path
end

def fumeru? input
  _, vowels = tokenize input
  vowel = vowels.join('')
  hits = Groonga["words"].select {|record| record.vowel =~ vowel}
  fumeru = hits.collect{|record| record.key['text'] } - [input]
  if fumeru.size > 0
    puts "\"#{input}\"と\"#{fumeru.sample}\"で踏める。"
  else
    puts "踏めない。"
  end
end

def main
  init_db 'tmp/infume_db'
  fumeru?(ARGV[0]) if !ARGV[0].nil?
end

main

