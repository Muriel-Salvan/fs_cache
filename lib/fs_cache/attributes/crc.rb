require 'zlib'

class FsCache

  module Attributes

    # CRC attribute. Can be:
    # * String: Internal CRC computed from files by blocks
    class Crc < Attribute

      # Size of blocks to compute CRCs in bytes. Changing this value will invalidate previously computed CRCs.
      CRC_BLOCK_SIZE = 32 * 1024 * 1024 # 32 MB

      # Get the attribute for a given file
      #
      # Parameters::
      # * *file* (String): File to get the attribute for
      # Result::
      # * Object: Corresponding attribute value
      def attribute_for(file)
        blocks_crc = ''
        File.open(file, 'rb') do |file_io|
          buffer = nil
          while (buffer = file_io.read(CRC_BLOCK_SIZE))
            blocks_crc << Zlib.crc32(buffer, 0).to_s(16).upcase
          end
        end
        Zlib.crc32(blocks_crc, 0).to_s(16).upcase
      end

      # Get the list of other attributes that invalidate this one.
      # If any of those attributes is chaning on a file, then reset our attribute for the file.
      #
      # Result::
      # * Array<Symbol>: List of dependent attributes
      def invalidated_on_change_of
        [:size]
      end

      # Add helpers to the cache
      module Helpers

        # Provide info on the differences between 2 directories.
        #
        # Parameters::
        # * *dir1* (String): First directory
        # * *dir2* (String): Second directory
        # Result::
        # * Hash<Symbol,Object>: Difference between the 2 directories (dir2 - dir1):
        #   * *same* (Array<String>): Same files
        #   * *renamed* (Array<[String,String]>): Renamed files (from dir1 to dir2: [file_base1, file_base2])
        #   * *added* (Array<String>): Added files
        #   * *deleted* (Array<String>): Deleted files
        #   * *different* (Array<String>): Different files
        def diff_dirs(dir1, dir2)
          files1 = Hash[files_in(dir1).map { |file| [file, "#{dir1}/#{file}"] }]
          files2 = Hash[files_in(dir2).map { |file| [file, "#{dir2}/#{file}"] }]
          same = []
          different = []
          renamed = []
          # First process files having the same names
          files1.delete_if do |file_base1, file1|
            if files2.key?(file_base1)
              # A file with same name exists in dir2
              if crc_for(files2[file_base1]) == crc_for(file1)
                same << file_base1
              else
                different << file_base1
              end
              files2.delete(file_base1)
              true
            else
              false
            end
          end
          # Then process files having the same CRC among the remaining ones
          files1.delete_if do |file_base1, file1|
            crc1 = crc_for(file1)
            found_file_base2, _found_file2 = files2.find { |_file_base2, file2| crc_for(file2) == crc1 }
            if found_file_base2.nil?
              false
            else
              renamed << [file_base1, found_file_base2]
              files2.delete(found_file_base2)
              true
            end
          end
          remaining_files1 = files1.keys
          remaining_files2 = files2.keys
          {
            same: same,
            renamed: renamed,
            added: remaining_files2 - remaining_files1,
            deleted: remaining_files1 - remaining_files2,
            different: different
          }
        end

      end

    end

  end

end
