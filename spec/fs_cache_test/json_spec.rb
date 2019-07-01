describe FsCache do

  it 'stores the cache content and restores it correctly' do
    json = nil
    with_cache(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do |fs_cache, dir|
      fs_cache.scan(["#{dir}/dir"])
      json = fs_cache.to_json
      new_fs_cache = FsCache.new
      new_fs_cache.from_json(json)
      expect(FsCacheTest::OpsRecorder.record do
        expect(new_fs_cache.exist?("#{dir}/dir/missing_file")).to eq(false)
        expect(new_fs_cache.exist?("#{dir}/dir/file1")).to eq(true)
        expect(new_fs_cache.files_in("#{dir}/dir").sort).to eq(%w[file1 file2].sort)
        expect(new_fs_cache.dirs_from("#{dir}/dir").sort).to eq(["#{dir}/dir/subdir"].sort)
        expect(new_fs_cache.files_from("#{dir}/dir").sort).to eq(["#{dir}/dir/file1", "#{dir}/dir/file2", "#{dir}/dir/subdir/file3"].sort)
      end).to eq([])
    end
  end

  it 'stores the cache content with plugins attributes and restores it correctly' do
    json = nil
    with_cache(
      create_files: %w[file1],
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new }
    ) do |fs_cache, dir|
      fs_cache.test_attr_for("#{dir}/file1")
      json = fs_cache.to_json
      new_fs_cache = FsCache.new
      new_fs_cache.register_attribute_plugin(:test_attr, FsCacheTest::TestAttribute.new)
      new_fs_cache.from_json(json)
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
      end).to eq([])
    end
  end

end
