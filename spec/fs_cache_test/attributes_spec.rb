describe FsCache do

  it 'does not read the plugin\'s attribute when asked for a missing file' do
    expect_ops_to_be_cached(register_plugins: { test_attr: FsCacheTest::TestAttribute.new }) do
      expect(@fs_cache.test_attr_for("#{@dir}/missing_file")).to eq(nil)
      [{ class: :File, method: :exist?, args: ["#{@dir}/missing_file"] }]
    end
  end

  it 'reads the plugin\'s attribute when asked for an existing file' do
    expect_ops_to_be_cached(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[existing_file]
    ) do
      expect(@fs_cache.test_attr_for("#{@dir}/existing_file")).to eq('Sample attribute value')
      [
        { class: :File, method: :exist?, args: ["#{@dir}/existing_file"] },
        { class: :TestAttribute, method: :attribute_for, args: ["#{@dir}/existing_file"] }
      ]
    end
  end

  it 'can use a plugin\'s helper directly on the fs_cache instance' do
    with_cache(register_plugins: { test_attr: FsCacheTest::TestAttribute.new }) do |fs_cache|
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.test_attr_helper).to eq('Sample helper value')
      end).to eq([{ class: :FsCache, method: :test_attr_helper, args: [] }])
    end
  end

  it 'scans the plugins attributes specified' do
    expect_ops_to_be_cached(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[file1]
    ) do
      @fs_cache.scan([@dir], include_attributes: %i[test_attr])
      expect(@fs_cache.test_attr_for("#{@dir}/file1")).to eq('Sample attribute value')
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/*", File::FNM_DOTMATCH] },
        { class: :TestAttribute, method: :attribute_for, args: ["#{@dir}/file1"] }
      ]
    end
  end

  it 'scans the plugins without excluded attributes' do
    with_cache(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[file1]
    ) do |fs_cache, dir|
      fs_cache.scan([dir], include_attributes: %i[test_attr], exclude_attributes: %i[test_attr])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
      end).to eq([{ class: :TestAttribute, method: :attribute_for, args: ["#{dir}/file1"] }])
    end
  end

end
