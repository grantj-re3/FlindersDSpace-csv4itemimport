FlindersDSpace-csv4itemimport
=============================

Description
-----------
Converts rows in a CSV file (plus optional bitstreams/files)
into a directory and file structure suitable for batch importing as items
into DSpace 3.x using the Simple Archive Format (SAF). The resulting
structure can then be imported into DSpace with a command like:
```
  /path/to/dspace import -a -s OUT_DIR -c COLLECTION_ID -m NEW_MAP_FILE -e USER_EMAIL [--test]
```
where OUT_DIR is the is the top directory of the output structure
created by this program (ie. typically "results/to_import" - defined
by SAF_DEST_FOLDER within bin/csv4itemimport.rb).

**Note that all items will be imported into the same collection.**

The input CSV file is mostly compatible with the
DSpace Batch Metadata Editing CSV file. Similarities include:
- RFC4180 CSV format
- Most columns contain the dublin core metadata fields
- If you want to store multiple values for a given metadata element,
  they must be separated with a double-pipe "||"

Differences include:
- The "id" column is not mandatory and will be ignored.
- The "collection" column is not required and will be ignored.
  All lines in the CSV file will be imported into the *same* collection
  which shall be specified on the "dspace import" command line
  via the -c or --collection option (see the example above).
- A new column "dspace.files" is required if one or more items (ie. CSV lines) has
  corresponding files to be ingested into DSpace via the CSV import
  process. If more than one file needs to be ingested for a single
  item, the list of files must be separated with "||"

In summary, only the following 2 column types shall be recognised:
- dublin core columns starting with "dc."
- the new (but optional) column "dspace.files"

All other column names shall be ignored.

CSV file example
----------------
```
  id,collection,dc.contributor.author,dc.description.abstract[en_US],dc.subject[en_US],dc.title[en_US],Status,Editor,dspace.files
  14,123456789/0,Test Contrib Author1,This is the wonderful abstract,subj001||subj002b,Test title #001,Blah..,Blah..,file1.pdf||file2.txt||file3.csv
  15,123456789/0,Test Contrib Author2,This is the wonderful abstract,subj003a||subj004,Test title #002,Blah..,Blah..,
```
Interpretation:
- Columns id, collection, Status and Editor shall be ignored.
- If populated, Dublin Core metadata for the following columns shall be
  ingested into DSpace:
  * dc.contributor.author
  * dc.description.abstract (with language set to "en_US")
  * dc.subject (with language set to "en_US")
  * dc.title (with language set to "en_US")
- In the example above, each item will have 2 values for dc.subject.
- In the example above, there will be 3 bitstreams/files ingested for
  the first item, whereas there will not be any bitstreams/files
  ingested for the second item.

Cleaning the CSV file metadata
------------------------------
If you have good compatibility between the character set used in the
input CSV file and the character set used by DSpace then no cleaning
of CSV metadata will be needed. In this case you can set the "cleanup_mode"
property to "none" within etc/conf/dublin_core_value_cleanup.yaml and
no cleaning will be performed.

However, I found that the Microsoft Excel spreadsheet (from which the
CSV input file was derived) was created from pasting text from various
sources (eg. Microsoft Word or Adobe Acrobat Reader) and contained several
characters which were unsuitable for our DSpace instance. In particular,
the CSV rows contained metadata text which was outside the printable ASCII
text code range 32-254 (ie. 0x20-0x7e hexadecimal). Appropriate configuration
of etc/conf/dublin_core_value_cleanup.yaml allowed this issue to be overcome.
In particular:
- the "cleanup_mode" property was set to "fromLookup_toLookupString"
- the hexadecimal-string pairs listed under the "lookup" section allowed
  the 1-byte character specified by the hexadecimal key to be replaced
  by the corresponding string

Although not all characters can be represented by a single byte in most
modern character encodings (eg. utf-8) this work-around allowed a
semi-automated solution for the author of the batch import metadata. I
regard this solution as semi-automated rather than fully-automated
because some investigation is needed into:
- which characters used within the CSV file cause a problem for your
  DSpace instance
- a suitable replacement string for each such character

