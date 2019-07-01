describe FsCache do

  it 'notifies a file copy of a file not part of the cache' do
    with_cache(create_files: %w[file1]) do |fs_cache, dir|
      FileUtils.cp "#{dir}/file1", "#{dir}/file2"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_cp("#{dir}/file1", "#{dir}/file2")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.exist?("#{dir}/file1")).to eq(true)
        expect(fs_cache.exist?("#{dir}/file2")).to eq(true)
      end).to eq([])
    end
  end

  it 'notifies a file copy of a file that was part of the cache' do
    with_cache(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[file1 file3]
    ) do |fs_cache, dir|
      fs_cache.scan([dir])
      FileUtils.cp "#{dir}/file1", "#{dir}/file2"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_cp("#{dir}/file1", "#{dir}/file2")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        expect(fs_cache.test_attr_for("#{dir}/file2")).to eq('Sample attribute value')
        expect(fs_cache.test_attr_for("#{dir}/file3")).to eq('Sample attribute value')
        expect(fs_cache.files_in(dir).sort).to eq(%w[file1 file2 file3].sort)
      end).to eq([])
    end
  end

  it 'notifies a file move of a file not part of the cache' do
    with_cache(create_files: %w[file1]) do |fs_cache, dir|
      FileUtils.mv "#{dir}/file1", "#{dir}/file2"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_mv("#{dir}/file1", "#{dir}/file2")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.exist?("#{dir}/file1")).to eq(false)
        expect(fs_cache.exist?("#{dir}/file2")).to eq(true)
      end).to eq([])
    end
  end

  it 'notifies a file move of a file that was part of the cache' do
    with_cache(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[file1 file3]
    ) do |fs_cache, dir|
      fs_cache.scan([dir])
      FileUtils.mv "#{dir}/file1", "#{dir}/file2"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_mv("#{dir}/file1", "#{dir}/file2")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.exist?("#{dir}/file1")).to eq(false)
        expect(fs_cache.test_attr_for("#{dir}/file2")).to eq('Sample attribute value')
        expect(fs_cache.test_attr_for("#{dir}/file3")).to eq('Sample attribute value')
        expect(fs_cache.files_in(dir).sort).to eq(%w[file2 file3].sort)
      end).to eq([])
    end
  end

  it 'notifies a file removal of a file not part of the cache' do
    with_cache(create_files: %w[file1]) do |fs_cache, dir|
      FileUtils.rm "#{dir}/file1"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_rm("#{dir}/file1")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.exist?("#{dir}/file1")).to eq(false)
      end).to eq([])
    end
  end

  it 'notifies a file removal of a file that was part of the cache' do
    with_cache(
      register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
      create_files: %w[file1 file3]
    ) do |fs_cache, dir|
      fs_cache.scan([dir])
      FileUtils.rm "#{dir}/file1"
      expect(FsCacheTest::OpsRecorder.record do
        fs_cache.notify_file_rm("#{dir}/file1")
      end).to eq([])
      expect(FsCacheTest::OpsRecorder.record do
        expect(fs_cache.exist?("#{dir}/file1")).to eq(false)
        expect(fs_cache.test_attr_for("#{dir}/file3")).to eq('Sample attribute value')
        expect(fs_cache.files_in(dir).sort).to eq(%w[file3].sort)
      end).to eq([])
    end
  end

end
