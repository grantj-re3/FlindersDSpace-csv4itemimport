#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 

require 'yaml'
require 'cgi'

##############################################################################
# A class to store information regarding a Dublin Core metadata line/object
# for use with the DSpace Simple Archive Format.
class DublinCoreValue
  include Comparable

  VERBOSE = true

  DEFAULT_CLEANUP_CONFIG_FILENAME = "../etc/conf/dublin_core_value_cleanup.yaml"

  NEWLINE = "\n"

  # Cleanup modes which are permitted within the YAML config file.
  CLEANUP_MODES = %w(
    fromAbove7f_toHtmlUnicode
    fromLookup_toHtmlUnicode
    fromLookup_toLookupString
    none
  )

  # Cleanup modes which use the list of hash-keys specified in the YAML config file.
  CLEANUP_MODES_WITH_KEY = CLEANUP_MODES.inject([]){|a,mode| a << mode if mode.match(/^fromLookup/); a}

  # Cleanup modes which use the list of hash-values specified in the YAML config file.
  CLEANUP_MODES_WITH_VALUE = CLEANUP_MODES.inject([]){|a,mode| a << mode if mode.match(/toLookupString$/); a}

  # HTML-Unicode-symbol format-string for printf(). Eg. "&#x0085;"
  HTML_UNICODE_FORMAT = "&#x%04x;"

  @@cleanup_config_yaml_filename = DEFAULT_CLEANUP_CONFIG_FILENAME
  @@cleanup_properties = nil
  @@cleanup_lookup = nil

  attr_reader :name, :value

  ############################################################################
  # Create a single Dublin Core Value object.
  #
  # Argument 'name' has format: 'dc.element_name.qualifier_name[language_abbreviation]'
  #
  # where
  # - the '.qualifier_name' is optional.
  # - the '[language_abbreviation]' is optional.
  # For example, the following are all valid for this program.
  # - dc.identifier.uri[en_US]
  # - dc.identifier[en_US]
  # - dc.identifier.uri
  # - dc.identifier
  #
  # Argument 'value' is the corresponding metadata text.
  def initialize(name, value)
    @name = name
    @value = value

    parts = @name.split('.')
    unless parts[0].match('^dc$')
      STDERR.puts "ERROR: '#{@name}' does not represent a Dublin Core element (must start with 'dc.')."
      exit 2
    end

    unless [2,3].include?(parts.length)
      STDERR.puts "ERROR: '#{@name}' does not represent a Dublin Core element."
      STDERR.puts "It must contain 1 or 2 dots."
      exit 3
    end

    # Extract element, qualifier & language
    subparts = parts.last.split(/[\[\]]/)

    @lang = subparts.length == 2 ? subparts[1] : nil
    @element = nil
    @qualifier = nil
    if parts.length == 3
      @element = parts[1]
      @qualifier = subparts[0]
    else  # parts.length == 2
      @element = subparts[0]
    end

    unless @@cleanup_properties
      self.class.load_cleanup_parameters unless @@cleanup_properties
      puts "#{self.class} cleanup mode:     #{@@cleanup_properties['cleanup_mode']}"
    end
  end

  ############################################################################
  # Comparison operator to allow objects of this class to be sorted, etc.
  def <=>(other)
    @name == other.name ? @value <=> other.value : @name <=> other.name
  end

  ############################################################################
  # Convert this object to an XML element (compatible with the DSpace
  # Simple Archive Format).
  def to_xml
    s = []
    s << "<dcvalue element=\"#{@element}\" "
    s << "qualifier=\"#{@qualifier}\" " if @qualifier
    s << "language=\"#{@lang}\" " if @lang
    s << ">#{to_s_value_cleanup}</dcvalue>"
    s.join
  end

  ############################################################################
  # Load parameters from the YAML cleanup config file.
  def self.load_cleanup_parameters
    fname = @@cleanup_config_yaml_filename
    nl = NEWLINE

    begin
      conf_hash = YAML.load_file(fname)

    rescue Exception => ex
      msgs = []
      msgs << "### #{ex}#{nl}"
      msgs << "### YAML file '#{fname}' cannot be loaded.#{nl}"
      msgs << "### WARNING: No #{self} text cleanup will be performed.#{nl}"
      self.set_default_cleanup_properties(msgs.join)
      return
    end

    begin
      @@cleanup_properties = conf_hash['properties']
      raise "'cleanup_mode' is not specified in file #{fname}" unless @@cleanup_properties['cleanup_mode']
      raise "Invalid 'cleanup_mode' specified in file #{fname}" unless CLEANUP_MODES.include?(@@cleanup_properties['cleanup_mode'])

    rescue Exception => ex
      msgs = []
      msgs << "### #{ex}#{nl}"
      msgs << "### WARNING: No #{self} text cleanup will be performed.#{nl}"
      self.set_default_cleanup_properties(msgs.join)
      return
    end

    if CLEANUP_MODES_WITH_KEY.include?(@@cleanup_properties['cleanup_mode'])
      begin
        @@cleanup_lookup = conf_hash['lookup']
        raise "'lookup' is not specified in file #{fname}" unless @@cleanup_lookup.class == Hash

        keys_ok = @@cleanup_lookup.all?{|(key,value)| key.kind_of?(Integer) && key >= 0 && key <= 0xff}
        raise "Not all lookup keys are integers in the range 0-255 (0x00-0xff) inclusive." unless keys_ok

        value_strings_ok = @@cleanup_lookup.all?{|(key,value)| value.kind_of?(String)}	# Or just check if the object has a to_s method?
        raise "Not all lookup values are strings" if CLEANUP_MODES_WITH_VALUE.include?(@@cleanup_properties['cleanup_mode']) && !value_strings_ok

      rescue Exception => ex
        msgs = []
        msgs << "### #{ex}#{nl}"
        msgs << "### WARNING: No #{self} text cleanup will be performed.#{nl}"
        self.set_default_cleanup_properties(msgs.join)
        return
      end
    end
  end

  ############################################################################
  # Set default cleanup properties.
  def self.set_default_cleanup_properties(msg=nil)
    STDERR.puts msg if msg
    @@cleanup_properties = {'cleanup_mode' => 'none'}
  end

  ############################################################################
  # Configure the cleanup-config filename.
  def self.cleanup_config_filename=(filename)
    @@cleanup_config_yaml_filename = filename
  end

  ############################################################################
  # Convert 'value' to a string by:
  # - escaping HTML special characters
  # - applying cleanup character conversions specified in the cleanup-config file
  def to_s_value_cleanup
    puts __method__ if VERBOSE
    fmt = HTML_UNICODE_FORMAT
    hvalue = CGI::escapeHTML(@value)

    case @@cleanup_properties['cleanup_mode']

    # Replace each byte from 128-255 (0x80-0xff) with its HTML Unicode symbol. Eg. "&#x0085;"
    when 'fromAbove7f_toHtmlUnicode'
      new_chars = []
      hvalue.each_byte{|b| new_chars << (b >= 0x80 && b <= 0xff ? sprintf(fmt, b) : b.chr) }
      new_chars.join

    # Use lookup table to replace each byte with its HTML Unicode symbol. Eg. "&#x0085;"
    when 'fromLookup_toHtmlUnicode'
      new_chars = []
      hvalue.each_byte{|b| new_chars << (@@cleanup_lookup[b] ? sprintf(fmt, b) : b.chr) }
      new_chars.join

    # Use lookup table to replace each byte with associated string (also from the table)
    when 'fromLookup_toLookupString'
      new_chars = []
      hvalue.each_byte{|b|
        new_char = (@@cleanup_lookup[b] ? @@cleanup_lookup[b] : b.chr)
        printf("=== CLEANUP (%3d, 0x%2x)  %s  %s%s\n", b, b, b.chr, new_char, @@cleanup_lookup[b] ? ' %%% Updated %%%' : '') if VERBOSE
        new_chars << new_char
      }
      new_chars.join

    # Do not apply any filter
    when 'none'
      hvalue

    # Should never reach here!
    else
      STD.puts "ERROR: Unrecognised cleanup mode #{@@cleanup_properties['cleanup_mode']}"
      exit 4
    end
  end

  ############################################################################
  alias to_s to_xml

end

