#!/usr/bin/env ruby
# encoding: utf-8
require "tw"
require "MeCab"
require "fast_blank"
require "groonga"
require "mojinizer"
require "uuid"

$tagger = MeCab::Tagger.new
$UUID   = UUID.new

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

def insert_word(word, vowel)
  return if word.blank? || vowel.blank? || word.length < 4
  puts "<<- #{word}: #{vowel}"
  words = Groonga["words"]
  record = words.add($UUID.generate)
  record['text']  = word
  record['vowel'] = vowel
end

def register_words(message)
  surfaces, vowels = tokenize message.text
  # Save vowels joined with window 1, 2, 3
  #
  # . . . . . .
  # 1 2 3 4 5 6
  #
  # - text
  # - vowel
  # - from
  surfaces.each_with_index do |word, i|
    if !word.blank? && !vowels[i].blank?
      insert_word(word, vowels[i])
      if i > 0 && !vowels[i-1].blank?
        insert_word(surfaces[i-1]+word,
                    vowels[i-1]+vowels[i])
        if !vowels[i+1].blank?
          insert_word(surfaces[i-1]+word+surfaces[i+1],
                      vowels[i-1]+vowels[i]+vowels[i+1])
        end
      end
    end
  end
end

def setup_db(path)
  Groonga::Database.create path: path

  Groonga::Schema.create_table("words", type: :hash) do |table|
    table.text("text")
    table.text("vowel")
    table.short_text("from_id")
  end

  Groonga::Schema.create_table("search_terms",
                                     type: :patricia_trie,
                               normalizer: :NormalizerAuto,
                        default_tokenizer: "TokenBigram") do |table|
                                 table.index("words.text")
                                 table.index("words.vowel")
  end
end

def init_db path
  Groonga::Context.default_options = {encoding: :utf8}
  if !FileTest.file?(path)
    setup_db path
  else
    Groonga::Database.open path
  end
end

def main
  init_db 'tmp/infume_db'
  client = Tw::Client::Stream.new()
  client.user_stream{|msg| register_words msg }
end

main
