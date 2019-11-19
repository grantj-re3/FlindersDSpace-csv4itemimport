#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 

require 'dublin_core_value'

##############################################################################
# A class to store information regarding a DSpace item for the purposes of
# importing items into DSpace via the Simple Archive Format.
class Item
  # In a single CSV column, use this double-character delimiter to separate multiple values
  VALUE_DELIMITER = '||'
  # Beware of single (or odd number of) delimiter characters eg. '|'
  BAD_VALUE_DELIMITER = VALUE_DELIMITER[/^./]
  NEWLINE = "\n"

  XML_HEADER_LINES = [
    "<dublin_core>",
  ]

  XML_FOOTER_LINES = [
    "</dublin_core>",
  ]

  attr_reader :filenames, :filedescriptions

  ############################################################################
  # Create an Item object.
  #
  # If an item_hash value is nil or a sub-field of the value (by splitting
  # with VALUE_DELIMITER) is empty, we will not create a DublinCoreValue
  # object for that entity.
  def initialize(item_hash, filenames_str='', filedescriptions_str='')
    @item_hash = item_hash	# Hash of DC names (CSV column names) as keys with corresponding values
    @dc_list = []		# List of DublinCoreValue objects
    @filenames = []		# List of filenames (bitstreams) to be ingested
    @filedescriptions = []		# List of file descriptions corresponding to the above filenames

    @item_hash.each{|dc_name,dc_values|
      next unless dc_values

      # If dc_values string contains VALUE_DELIMITER, then we need to
      # split the string into fields (based on the delimiter) and
      # create a DublinCoreValue for each (value) field.
      has_bad_delim = false
      dc_values.split(VALUE_DELIMITER).each{|dc_value|
        stripped_dc_value = dc_value.strip
        next if stripped_dc_value.empty?
        d = DublinCoreValue.new(dc_name, stripped_dc_value)
        has_bad_delim ||= stripped_dc_value.include?(BAD_VALUE_DELIMITER)
        @dc_list << d
      }
      if has_bad_delim
        STDERR.puts <<-MSG_BAD_VALUE_DELIMITER.gsub(/^\t*/, '')
		WARNING: Possible bad delimiter (odd number of \"#{BAD_VALUE_DELIMITER}\") instead of \"#{VALUE_DELIMITER}\" in:
		  \"#{dc_values.strip}\"
		  for CSV column: \"#{dc_name}\"
        MSG_BAD_VALUE_DELIMITER
      end
    }

    if filenames_str
      # BAD_VALUE_DELIMITER here will be found later (as file-not-found)
      filenames_str.split(VALUE_DELIMITER).each{|fname|
        stripped_fname = fname.strip
        @filenames << stripped_fname unless stripped_fname.empty?
      }
    end

    has_bad_delim = false
    if filedescriptions_str
      filedescriptions_str.split(VALUE_DELIMITER).each{|descr|
        stripped_descr = descr.strip
        has_bad_delim ||= stripped_descr.include?(BAD_VALUE_DELIMITER)
        @filedescriptions << stripped_descr unless stripped_descr.empty?
      }
    end

    if has_bad_delim
      STDERR.puts <<-MSG_BAD_VALUE_DELIMITER2.gsub(/^\t*/, '')
		WARNING: Possible bad delimiter (odd number of \"#{BAD_VALUE_DELIMITER}\") instead of \"#{VALUE_DELIMITER}\" in:
		  \"#{filedescriptions_str}\"
		  for CSV column: \"#{Items::FILEDESCRIPTIONS_CSV_COLUMN}\"
      MSG_BAD_VALUE_DELIMITER2
    end
  end

  ############################################################################
  # Convert this object into a string representing the whole of a
  # Dublin Core XML file compatible with the DSpace Simple Archive Format.
  def to_xml
    puts "#{self.class}.#{__method__} invoked for object_id #{object_id}" if DublinCoreValue::VERBOSE
    s = XML_HEADER_LINES.join(NEWLINE)
    s += NEWLINE + @dc_list.sort.collect{|d| "  #{d}"}.join(NEWLINE)
    s += NEWLINE + XML_FOOTER_LINES.join(NEWLINE)
    s
  end

  ############################################################################
  alias to_s to_xml

end

