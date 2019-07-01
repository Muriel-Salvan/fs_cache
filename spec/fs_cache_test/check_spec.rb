describe FsCache do

  context 'checking divergences with the file system' do

    it 'invalidates a missing file\'s existence' do
      with_cache do |fs_cache, dir|
        fs_cache.exist?("#{dir}/missing_file")
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check
        end).to eq([{ class: :File, method: :exist?, args: ["#{dir}/missing_file"] }])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.exist?("#{dir}/missing_file")).to eq(false)
        end).to eq([])
      end
    end

    it 'invalidates an existing file\'s existence' do
      with_cache(create_files: %w[existing_file]) do |fs_cache, dir|
        fs_cache.exist?("#{dir}/existing_file")
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check
        end).to eq([{ class: :File, method: :exist?, args: ["#{dir}/existing_file"] }])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.exist?("#{dir}/existing_file")).to eq(true)
        end).to eq([])
      end
    end

    it 'invalidates a disappearing file\'s existence' do
      with_cache(create_files: %w[existing_file]) do |fs_cache, dir|
        fs_cache.exist?("#{dir}/existing_file")
        File.unlink "#{dir}/existing_file"
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check
        end).to eq([{ class: :File, method: :exist?, args: ["#{dir}/existing_file"] }])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.exist?("#{dir}/existing_file")).to eq(false)
        end).to eq([])
      end
    end

    it 'invalidates a directory\'s content with new files' do
      with_cache(create_files: %w[
        dir/file1
      ]) do |fs_cache, dir|
        fs_cache.scan(["#{dir}/dir"])
        FileUtils.touch "#{dir}/dir/file2"
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check(include_attributes: [])
        end).to eq([{ class: :File, method: :exist?, args: ["#{dir}/dir/file1"] }])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.exist?("#{dir}/dir/file2")).to eq(true)
        end).to eq([{ class: :File, method: :exist?, args: ["#{dir}/dir/file2"] }])
      end
    end

    it 'invalidates a directory\'s content with deleted files' do
      with_cache(create_files: %w[
        dir/file1
        dir/file2
      ]) do |fs_cache, dir|
        fs_cache.scan(["#{dir}/dir"])
        File.unlink "#{dir}/dir/file2"
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check(include_attributes: [])
        end).to eq([
          { class: :File, method: :exist?, args: ["#{dir}/dir/file1"] },
          { class: :File, method: :exist?, args: ["#{dir}/dir/file2"] }
        ])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.exist?("#{dir}/dir/file2")).to eq(false)
        end).to eq([])
      end
    end

    it 'invalidates a file\'s attribute when asked' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check(include_attributes: [:test_attr])
        end).to eq([
          { class: :File, method: :exist?, args: ["#{dir}/file1"] },
          { class: :TestAttribute, method: :attribute_for, args: ["#{dir}/file1"] }
        ])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([])
      end
    end

    it 'doesn\'t invalidate an excluded file\'s attribute' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check(include_attributes: [:test_attr], exclude_attributes: [:test_attr])
        end).to eq([
          { class: :File, method: :exist?, args: ["#{dir}/file1"] }
        ])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([])
      end
    end

    it 'only invalidates file\'s attributes that have been cached' do
      with_cache(
        register_plugins: { test_attr: FsCacheTest::TestAttribute.new },
        create_files: %w[file1]
      ) do |fs_cache, dir|
        fs_cache.scan([dir], exclude_attributes: [:test_attr])
        expect(FsCacheTest::OpsRecorder.record do
          fs_cache.check(include_attributes: [:test_attr])
        end).to eq([
          { class: :File, method: :exist?, args: ["#{dir}/file1"] }
        ])
        expect(FsCacheTest::OpsRecorder.record do
          expect(fs_cache.test_attr_for("#{dir}/file1")).to eq('Sample attribute value')
        end).to eq([{ class: :TestAttribute, method: :attribute_for, args: ["#{dir}/file1"] }])
      end
    end

  end

end
