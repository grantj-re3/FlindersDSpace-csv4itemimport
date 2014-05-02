#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 

require 'faster_csv'
require 'item'
require 'object_extra'
require 'fileutils'

##############################################################################
# A class to store information regarding a group of DSpace items for the
# purpose of importing that group into DSpace using the Simple Archive Format.
class Items
  # SAF item-directory shall be named as CHILD_DIR_PREFIX plus a zero-padded
  # numeric suffix of MIN_ITEM_NUMBER_WIDTH digits (or more digits if needed).
  CHILD_DIR_PREFIX = 'item'
  MIN_ITEM_NUMBER_WIDTH = 4

  DC_FILENAME = 'dublin_core.xml'
  CONTENTS_FILENAME = 'contents'

  attr_reader :parent_dir_name

  ############################################################################
  # Create an aggregation of items.
  def initialize(parent_dir_name, bitstream_source_dir, cleanup_config_filename)
    @parent_dir_name = parent_dir_name
    @bitstream_source_dir = bitstream_source_dir
    @cleanup_config_filename = cleanup_config_filename
    DublinCoreValue.cleanup_config_filename = @cleanup_config_filename
    @items = []
  end

  ############################################################################
  # Return the number of items in this object.
  def length
    @items.length
  end

  ############################################################################
  # Load/populate this aggregation of items from the specified CSV file.
  def load_csv(fname, faster_csv_options={})
    opts = {
      :col_sep => ',',
      # It is not advisible to override the values below with those
      # from faster_csv_options (as this method assume these values)
      :headers => true,
      :header_converters => nil,	# CSV header names are a string (not a symbol)
    }.merge!(faster_csv_options)

    count = 0
    FasterCSV.foreach(fname, opts) {|line|
      count += 1
      puts "\n#{count} <<#{line.to_s.chomp}>>" if MDEBUG.include?(__method__)

      item_hash = {}
      line.each{|key, value|
        unless key
          STDERR.puts "\nERROR: One of the CSV header fields is empty (ie. nil)."
          STDERR.puts "Header fields: #{line.headers.inspect}"
          exit 7
        end
        item_hash[key] = value if key.match(/^dc\./) 
      }

      @items << Item.new(item_hash, line['dspace.files']) unless item_hash.empty?
    }
    warn_if_filenames_repeated
  end

  ############################################################################
  # Issue warning if any filenames have been referenced more than once.
  ############################################################################
  def warn_if_filenames_repeated
    all_files = @items.inject([]){|a,item| a += item.filenames}
    dup_files = all_files.find_all{|f| all_files.count(f) > 1}.uniq

    if dup_files.length > 0
      STDERR.puts "\nWARNING: A reference to one or more 'dspace.files' has been repeated."
      dup_files.sort.each{|f| STDERR.puts "- 'dspace.files' filename:  #{f}"}
    end
  end

  ############################################################################
  # Populate the specified folder with a structure representing this
  # aggregation of items.
  def populate_folder
    # Make parent dir
    if File.exists? @parent_dir_name
      STDERR.puts "ERROR: Cannot create directory '#{@parent_dir_name}'."
      STDERR.puts "Directory or file already exists"
      exit 5
    else
      FileUtils.mkdir_p @parent_dir_name
    end

    # Make and populate child dirs
    width = [MIN_ITEM_NUMBER_WIDTH, (@items.length - 1).to_s.length].max
    print_format = "%s/%s%0#{width}d"

    @items.each_with_index{|item, i|
      child_dir = sprintf print_format, @parent_dir_name, CHILD_DIR_PREFIX, i
      child_dc_path = "#{child_dir}/#{DC_FILENAME}"
      child_contents_path = "#{child_dir}/#{CONTENTS_FILENAME}"
      FileUtils.mkdir child_dir

      # Write item.to_xml to child_dc_path
      File.write_string(child_dc_path, item.to_xml)

      # Write to child_contents_path
      if item.filenames.empty?
        # Write an empty contents file
        FileUtils.touch child_contents_path
      else
        item.filenames.each{|fname|
          # Copy each file into the child dir
          fpath = "#{@bitstream_source_dir}/#{fname}"
          unless File.file?(fpath)
            STDERR.puts "ERROR: File '#{fpath}' not found."
            exit 6
          end
          FileUtils.copy(fpath, child_dir)
        }
        # Write the filenames to the contents file
        filenames_str = item.filenames.join(Item::NEWLINE) + Item::NEWLINE
        File.write_string(child_contents_path, filenames_str)
      end
    }
  end

  ############################################################################
  # Returns a string which contains a human-friendly portrayal of the object.
  def inspect
    "#{@parent_dir_name} -- #{@items.inspect}"
  end

end

