require 'progressbar'
require 'fs_cache/attribute'

# Implement a cache of the file system: directories and files presence.
# Plugins can be used to also cache attributes of the files, like crc, size...
class FsCache

  ATTRIBUTE_PLUGINS_MODULE = FsCache::Attributes

  # Constructor
  #
  # Parameters::
  # * *attribute_plugins_dirs* (Array<String>): List of directories containing possible attribute plugins [default = []]
  def initialize(attribute_plugins_dirs: [])
    # List of possible attribute plugins, per attribute name
    # Hash<Symbol, Attribute>
    @attribute_plugins = {}
    # Tree of dependent attributes: for each attribute in this tree, the list of attributes to be invalidated if this attribute changes.
    # Hash<Symbol, Array<Symbol> >
    @dependent_attributes = {}
    # Big database of files information
    # Hash<String, Hash<Symbol,Object> >: For each file name, the file info (can be incomplete if it was never fetched):
    # * *exist* (Boolean): Does the file exist?
    # * *size* (Integer): File size.
    # * *crc* (String): File CRC.
    # * *corruption* (false or Object): Info about this file's corruption, or false if sane.
    @files = Hash.new { |h, k| h[k] = {} }
    # Directories information
    # Hash<String, Hash<Symbol,Object> >: For each directory name, the dir info (can be incomplete if it was never fetched):
    # * *files* (Hash<String,nil>): Set of files (base names)
    # * *dirs* (Hash<String,nil>): Set of directories (base names)
    # * *recursive_dirs* (Hash<String,nil>): Set of recursive sub-directories (full paths)
    # * *recursive_files* (Hash<String,nil>): Set of recursive files (full paths)
    @dirs = Hash.new { |h, k| h[k] = {} }

    # Automatically register attributes from the plugins dirs
    (["#{__dir__}/fs_cache/attributes"] + attribute_plugins_dirs).each do |attribute_plugins_dir|
      Dir.glob("#{attribute_plugins_dir}/*.rb") do |attribute_plugin_file|
        attribute = File.basename(attribute_plugin_file)[0..-4].to_sym
        require attribute_plugin_file
        class_name = attribute.to_s.split('_').collect(&:capitalize).join.to_sym
        if ATTRIBUTE_PLUGINS_MODULE.const_defined?(class_name)
          plugin_class = ATTRIBUTE_PLUGINS_MODULE.const_get(class_name)
          register_attribute_plugin(attribute, plugin_class.new)
        else
          raise "Attributes plugin #{attribute_plugin_file} does not define the class #{class_name} inside #{ATTRIBUTE_PLUGINS_MODULE}" if plugin_class.nil?
        end
      end
    end
  end

  # Register a new attributes' plugin.
  # The constructor already registers all plugins found in the plugins directories.
  # This method exists in order to register plugins that could be dynamically instantiated.
  #
  # Parameters::
  # * *attribute* (Symbol): The attribute
  # * *plugin* (Attribute): The attribute plugin
  def register_attribute_plugin(attribute, plugin)
    puts "Registering attribute plugin #{attribute}..."
    raise "Attributes plugin #{attribute} is already defined (by class #{@attribute_plugins[attribute].class.name})." if @attribute_plugins.key?(attribute)
    @attribute_plugins[attribute] = plugin
    # Define the getter methods for this attribute, directly in the base class for performance purposes

    # Get the attribute for a given file.
    # Use the cache if possible.
    #
    # Parameters::
    # * *file* (String): File path for which we look for the attribute
    # Result::
    # * Object: Corresponding attribute value, or nil if the file does not exist
    define_singleton_method("#{attribute}_for".to_sym) do |file|
      @files[file][attribute] = plugin.attribute_for(file) if !@files[file].key?(attribute) && exist?(file)
      @files[file][attribute]
    end

    # If there are some helpers, register them too
    if plugin.class.const_defined?(:Helpers)
      helpers_module = plugin.class.const_get(:Helpers)
      self.class.include helpers_module unless helpers_module.nil?
    end
    # If this attribute is dependent on others, remember it too
    plugin.invalidated_on_change_of.each do |parent_attribute|
      @dependent_attributes[parent_attribute] = [] unless @dependent_attributes.key?(parent_attribute)
      @dependent_attributes[parent_attribute] << attribute
    end
  end

  # Is a file existing?
  #
  # Parameters::
  # * *file* (String): File name
  # Result::
  # * String: Is the file existing?
  def exist?(file)
    # If there is at least 1 attribute for this file it means that it exists
    unless @files[file].key?(:exist)
      @files[file][:exist] =
        # If we have an attribute for this file, it means it exist
        if @files[file].size > 0
          true
        else
          dir = File.dirname(file)
          if @dirs.key?(dir)
            # We know about its directory, so we should know if it is there
            @dirs[dir][:files].key?(File.basename(file))
          else
            File.exist?(file)
          end
        end
    end
    @files[file][:exist]
  end

  # Get list of files from a directory (base names)
  #
  # Parameters::
  # * *dir* (String): The directory to get files from
  # Result::
  # * Array<String>: List of file base names
  def files_in(dir)
    ensure_dir_data(dir)
    @dirs[dir][:files].keys
  end

  # Get recursive list of directories from a directory
  #
  # Parameters::
  # * *dir* (String): The directory to get other directories from
  # Result::
  # * Array<String>: List of directories
  def dirs_from(dir)
    unless @dirs[dir].key?(:recursive_dirs)
      ensure_dir_data(dir)
      recursive_dirs = {}
      @dirs[dir][:dirs].keys.each do |subdir|
        full_subdir = "#{dir}/#{subdir}"
        recursive_dirs[full_subdir] = nil
        recursive_dirs.merge!(Hash[dirs_from(full_subdir).map { |subsubdir| [subsubdir, nil] }])
      end
      @dirs[dir][:recursive_dirs] = recursive_dirs
    end
    @dirs[dir][:recursive_dirs].keys
  end

  # Get recursive list of files from a directory
  #
  # Parameters::
  # * *dir* (String): The directory to get other directories from
  # Result::
  # * Array<String>: List of files
  def files_from(dir)
    unless @dirs[dir].key?(:recursive_files)
      ensure_dir_data(dir)
      recursive_files = Hash[@dirs[dir][:files].keys.map { |file| ["#{dir}/#{file}", nil] }]
      @dirs[dir][:dirs].keys.each do |subdir|
        recursive_files.merge!(Hash[files_from("#{dir}/#{subdir}").map { |file| [file, nil] }])
      end
      @dirs[dir][:recursive_files] = recursive_files
    end
    @dirs[dir][:recursive_files].keys
  end

  # Scan files and directories from a list of directories.
  # Use a progress bar.
  #
  # Parameters::
  # * *dirs* (Array<String>): List of directories to preload
  # * *include_attributes* (Array<Symbol> or nil): List of attributes to scan, or nil for all [default = nil]
  # * *exclude_attributes* (Array<Symbol>): List of attributes to ignore while scanning [default = []]
  def scan(dirs, include_attributes: nil, exclude_attributes: [])
    progressbar = ProgressBar.create(title: 'Indexing files')
    attributes_to_scan = (include_attributes.nil? ? @attribute_plugins.keys : include_attributes) - exclude_attributes
    files = dirs.
      map do |dir|
        dirs_from(dir)
        files_from(dir)
      end.
      flatten
    progressbar.total = files.size
    files.each do |file|
      exist?(file)
      attributes_to_scan.each do |attribute|
        self.send "#{attribute}_for", file
      end
      progressbar.increment
    end
  end

  # Serialize into JSON.
  #
  # Result::
  # * Object: JSON object
  def to_json
    {
      files: @files,
      dirs: @dirs
    }
  end

  # Get data from JSON.
  #
  # Parameters::
  # * *json* (Object): JSON object
  def from_json(json)
    json = json.transform_keys(&:to_sym)
    @files = Hash[json[:files].map { |file, file_info| [file, file_info.transform_keys(&:to_sym)] }]
    @files.default_proc = proc { |h, k| h[k] = {} }
    @dirs = Hash[json[:dirs].map { |dir, dir_info| [dir, dir_info.transform_keys(&:to_sym)] }]
    @dirs.default_proc = proc { |h, k| h[k] = {} }
  end

  # Notify the file system that a given file has been deleted
  #
  # Parameters::
  # * *file* (String): File being deleted
  def notify_file_rm(file)
    @files[file] = { exist: false }
    unregister_file_from_dirs(file)
  end

  # Notify the file system of a file copy
  #
  # Parameters::
  # * *src* (String): Origin file
  # * *dst* (String): Destination file
  def notify_file_cp(src, dst)
    if @files.key?(src)
      @files[dst] = @files[src].clone
    else
      @files[src] = { exist: true }
      @files[dst] = { exist: true }
    end
    register_file_in_dirs(dst)
  end

  # Notify the file system of a file move
  #
  # Parameters::
  # * *src* (String): Origin file
  # * *dst* (String): Destination file
  def notify_file_mv(src, dst)
    notify_file_cp(src, dst)
    notify_file_rm(src)
  end

  # Check our info against file system changes.
  # This detects
  # * files that have been deleted,
  # * any change in the directories structure,
  # * any change in the attributes that are already part of the cache and that are not ignored explicitely.
  #
  # Parameters::
  # * *include_attributes* (Array<Symbol> or nil): List of attributes to scan, or nil for all [default = nil]
  # * *exclude_attributes* (Array<Symbol>): List of attributes to ignore while scanning [default = []]
  def check(include_attributes: nil, exclude_attributes: [])
    progressbar = ProgressBar.create(title: 'Refreshing files info')
    attributes_to_scan = (include_attributes.nil? ? @attribute_plugins.keys : include_attributes) - exclude_attributes
    progressbar.total = @files.size
    @files.each do |file, file_info|
      if File.exist?(file)
        if file_info.key?(:exist) && !file_info[:exist]
          # This file has been added when we thought it was missing
          file_info.replace(exist: true)
        else
          # Check attributes that are already present
          (file_info.keys & attributes_to_scan).each do |attribute|
            current_attribute = file_info[attribute]
            new_attribute = @attribute_plugins[attribute].attribute_for(file)
            if current_attribute != new_attribute
              # Attribute has changed
              file_info[attribute] = new_attribute
              # If some other attributes were depending on this one, invalidate them
              if @dependent_attributes.key?(attribute)
                @dependent_attributes[attribute].each do |dependent_attribute|
                  file_info.delete(dependent_attribute)
                end
              end
            end
          end
        end
      elsif !file_info.key?(:exist) || file_info[:exist]
        # This file has been removed when we thought it was there
        file_info.replace(exist: false)
      end
      progressbar.increment
    end
    # Rebuilding @dirs structure needs to make the Dir.glob commands once again. Therefore there is no need to check it. Removing it will rebuild it anyway.
    @dirs.clear
  end

  # Remove attributes for a list of files
  #
  # Parameters::
  # * *files* (Array<String>): The list of files to invalidate attributes for
  # * *include_attributes* (Array<Symbol> or nil): List of attributes to scan, or nil for all [default = nil]
  # * *exclude_attributes* (Array<Symbol>): List of attributes to ignore while scanning [default = []]
  def invalidate(files, include_attributes: nil, exclude_attributes: [])
    attributes_to_invalidate = ((include_attributes.nil? ? @attribute_plugins.keys : include_attributes) - exclude_attributes)
    files.each do |file|
      if @files.key?(file)
        attributes_to_invalidate.each do |attribute|
          @files[file].delete(attribute)
        end
      end
    end
  end

  private

  # Register a file in the @dirs structure
  #
  # Parameters::
  # * *file* (String): File to register in @dirs
  def register_file_in_dirs(file)
    file_dir = File.dirname(file)
    split_dir = file_dir.split('/')
    split_dir.size.times do |idx|
      dir = split_dir[0..idx].join('/')
      @dirs[dir][:recursive_files][file] = nil if @dirs.key?(dir) && @dirs[dir].key?(:recursive_files) && !@dirs[dir][:recursive_files].key?(file)
    end
    base_name = File.basename(file)
    @dirs[file_dir][:files][base_name] = nil if @dirs.key?(file_dir) && @dirs[file_dir].key?(:files) && !@dirs[file_dir][:files].key?(base_name)
  end

  # Unregister a file in the @dirs structure
  #
  # Parameters::
  # * *file* (String): File to unregister from @dirs
  def unregister_file_from_dirs(file)
    file_dir = File.dirname(file)
    split_dir = file_dir.split('/')
    split_dir.size.times do |idx|
      dir = split_dir[0..idx].join('/')
      # Remove any reference of our file to this dir info
      @dirs[dir][:recursive_files].delete(file) if @dirs.key?(dir) && @dirs[dir].key?(:recursive_files)
    end
    @dirs[file_dir][:files].delete(File.basename(file)) if @dirs.key?(file_dir) && @dirs[file_dir].key?(:files)
  end

  # Populate a given directory data (files and dirs)
  #
  # Parameters::
  # * *dir* (String): Directory to get data from
  def ensure_dir_data(dir)
    unless @dirs[dir].key?(:files)
      files = {}
      dirs = {}
      Dir.glob("#{dir}/*", File::FNM_DOTMATCH).each do |file|
        base_name = File.basename(file)
        if File.directory?(file)
          dirs[base_name] = nil if base_name != '.' && base_name != '..'
        else
          files[base_name] = nil
        end
      end
      @dirs[dir] = {
        files: files,
        dirs: dirs
      }
    end
  end

end
