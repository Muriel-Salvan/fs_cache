describe FsCache do

  context 'invalidating the cache on purpose' do

    it 'invalidates a file\'s attribute when asked' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.invalidate(["#{dir}/file1"], include_attributes: [:test_attr])
        end).to eq([])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([{ class: :TestAttribute, method: :attribute_for, args: ["#{dir}/file1"] }])
      end
    end

    it 'doesn\'t invalidate an excluded file\'s attribute' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.invalidate(["#{dir}/file1"], include_attributes: [:test_attr], exclude_attributes: [:test_attr])
        end).to eq([])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([])
      end
    end

    it 'does nothing when invalidating a file\'s attributes that has not been cached' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir], exclude_attributes: [:test_attr])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.invalidate(["#{dir}/file1"], include_attributes: [:test_attr])
        end).to eq([])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([{ class: :TestAttribute, method: :attribute_for, args: ["#{dir}/file1"] }])
      end
    end

  end

end
