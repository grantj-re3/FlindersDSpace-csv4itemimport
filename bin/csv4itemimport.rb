#!/usr/bin/ruby
# csv4itemimport.rb
#
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))

require 'items'
require 'item'
require 'dublin_core_value'

# Method-debug: List method-name symbols for which you want to show debug info
MDEBUG = [
  #:load_csv,
]

##############################################################################
# Converts information in a CSV file (plus optional bitstreams/files)
# into a directory and file structure suitable for batch importing as
# items into DSpace 3.x using the Simple Archive Format (SAF).
class Csv4ItemImport

  CONFIG_DIR = File.expand_path("../etc", File.dirname(__FILE__))
  CSV_PATH             = "#{CONFIG_DIR}/items.csv"
  BITSTREAM_SOURCE_DIR = "#{CONFIG_DIR}/files"
  CLEANUP_CONFIG_PATH  = "#{CONFIG_DIR}/conf/dublin_core_value_cleanup.yaml"

  CSV_DELIMITER = ','
  SAF_DEST_FOLDER = File.expand_path('../results/to_import', File.dirname(__FILE__))

  ############################################################################
  # Test DublinCoreValue object.
  def self.test_dc01
    puts "=== Start method '#{__method__}' ==="
    [
      "dc.type.other[en_US]",
      "dc.type[en_US]",
      "dc.type.other",
      "dc.type",
    ].each{|s|
      d = DublinCoreValue.new(s, "This is a thing")
      puts "\nString: #{s}"
      puts "XML: #{d}"
    }
  end

  ############################################################################
  # Test Item object.
  def self.test_item01
    puts "=== Start method '#{__method__}' ==="
    [
      {
        'dc.subject[en_US]'	=> 'my subject1||my subject2||my subj3',
        'dc.title.other'	=> '	my title || ',
      },
    ].each{|item_hash|
      puts "\nitem_hash: #{item_hash.inspect}"
      i = Item.new(item_hash)
      puts
      puts i.to_xml
    }

  end

  ############################################################################
  # The main method for this program.
  def self.main
    puts "\nCreate DSpace Simple Archive Format for batch import (from a CSV)"
    puts   "-----------------------------------------------------------------"
    puts "CSV file being loaded:            '#{CSV_PATH}'"
    puts "'dspace.files' source directory:  '#{BITSTREAM_SOURCE_DIR}'"
    puts "Cleanup config-file:              '#{CLEANUP_CONFIG_PATH}'"

    items = Items.new(SAF_DEST_FOLDER, BITSTREAM_SOURCE_DIR, CLEANUP_CONFIG_PATH)
    items.load_csv(CSV_PATH, :col_sep => CSV_DELIMITER)

    puts "Number of records (items) loaded: #{items.length}"
    puts "Populating the folder:            '#{items.parent_dir_name}'"

    items.populate_folder
    puts "Complete!"
  end

end

##############################################################################
# Main
##############################################################################
Csv4ItemImport.main
exit 0

