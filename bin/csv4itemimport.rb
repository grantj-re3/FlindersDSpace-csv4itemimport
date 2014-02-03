#!/usr/bin/ruby
# dspace_import_items_csv2saf.rb
#
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
# DESCRIPTION
#
# Converts information in a CSV file (plus optional bitstreams/files)
# into a directory and file structure suitable for importing into
# DSpace 3.x using the Simple Archive Format (SAF). The resulting
# structure can then be imported into DSpace with a command like:
#
#   /path/to/dspace import -a -s OUT_DIR -c COLLECTION_ID -m NEW_MAP_FILE -e USER_EMAIL [--test]
#
# where OUT_DIR is the is the top directory of the output structure
# created by this program (ie. SAF_DEST_FOLDER below).
#
# The input CSV file (CSV_PATH below) is mostly compatible with the
# DSpace Batch Metadata Editing CSV file. Similarities include:
# - RFC4180 CSV format
# - Most columns contain the dublin core metadata fields
# - If you want to store multiple values for a given metadata element,
#   they can be separated with the double-pipe '||'
#
# Differences include:
# - The "id" column is not mandatory and will be ignored.
# - The "collection" column is not required and will be ignored.
#   All lines in the CSV file will be imported into the *same* collection
#   which shall be specified on the "dspace import" command line
#   via the -c or --collection option (see the example above).
# - A new column "dspace.files" is required if one or more items (ie. CSV lines) has
#   corresponding files to be ingested into DSpace via the CSV import
#   process. If more than one file needs to be ingested for a single
#   item, the list of files must be separated with "||"
#
# In summary, only the following 2 column types shall be recognised:
# - dublin core columns starting with "dc."
# - the new (but optional) column "dspace.files"
# All other column names shall be ignored.
#
# CSV FILE EXAMPLE
#
#   id,collection,dc.contributor.author,dc.description.abstract[en_US],dc.subject[en_US],dc.title[en_US],Status,Editor,dspace.files
#   14,123456789/0,Test Contrib Author1,This is the wonderful abstract,subj001||subj002b,Test title #001,Blah..,Blah..,file1.pdf||file2.txt||file3.csv
#   15,123456789/0,Test Contrib Author2,This is the wonderful abstract,subj003a||subj004,Test title #002,Blah..,Blah..,
#
# Interpretation:
# - Columns id, collection, Status and Editor shall be ignored.
# - If populated, Dublin Core metadata for the following columns shall be
#   ingested into DSpace:
#   * dc.contributor.author
#   * dc.description.abstract (with language set to "en_US")
#   * dc.subject (with language set to "en_US")
#   * dc.title (with language set to "en_US")
# - In the example above, each item will have 2 values for dc.subject.
# - In the example above, there will be 3 bitstreams/files ingested for
#   the first item, whereas there will not be any bitstreams/files
#   ingested for the second item.
#
# Note:
# - We can verify the XML result with the xmllint tool.
##############################################################################

# Add dirs to the library path
$: << "../lib"
$: << "../lib/libext"


require 'items'
require 'item'
require 'dublin_core_value'

# Method-debug: List method-name symbols for which you want to show debug info
MDEBUG = [
  #:load_csv,
]

##############################################################################
class DSpaceImportItems_CSV2SAF

  CONFIG_DIR = "../etc"
  CSV_PATH             = "#{CONFIG_DIR}/itemsCharTest1.csv"
  BITSTREAM_SOURCE_DIR = "#{CONFIG_DIR}/files"
  CLEANUP_CONFIG_PATH  = "#{CONFIG_DIR}/conf/dublin_core_value_cleanup.yaml"

  CSV_DELIMITER = ','
  SAF_DEST_FOLDER = '../results/to_import02'

  ############################################################################
  # Test DublinCoreValue
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
  # Test Item
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
  # The main method for this program
  def self.main
    puts "\nCreate DSpace Simple Archive Format for import (from a CSV)"
    puts   "-----------------------------------------------------------"
    items = Items.new(SAF_DEST_FOLDER, BITSTREAM_SOURCE_DIR, CLEANUP_CONFIG_PATH)

    puts "CSV file being loaded:            '#{CSV_PATH}'"
    puts "Cleanup config-file:              '#{CLEANUP_CONFIG_PATH}'"
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
DSpaceImportItems_CSV2SAF.main
exit 0

