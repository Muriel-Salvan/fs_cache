describe FsCache do

  it 'checks a missing file\'s existence' do
    expect_ops_to_be_cached do
      expect(@fs_cache.exist?("#{@dir}/missing_file")).to eq(false)
      [{ class: :File, method: :exist?, args: ["#{@dir}/missing_file"] }]
    end
  end

  it 'checks an existing file\'s existence' do
    expect_ops_to_be_cached(create_files: %w[existing_file]) do
      expect(@fs_cache.exist?("#{@dir}/existing_file")).to eq(true)
      [{ class: :File, method: :exist?, args: ["#{@dir}/existing_file"] }]
    end
  end

  it 'gets files of a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      expect(@fs_cache.files_in("#{@dir}/dir").sort).to eq(%w[file1 file2].sort)
      [{ class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] }]
    end
  end

  it 'gets files of a directory recursively' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      expect(@fs_cache.files_from("#{@dir}/dir").sort).to eq(["#{@dir}/dir/file1", "#{@dir}/dir/file2", "#{@dir}/dir/subdir/file3"].sort)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'gets directories of a directory recursively' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir1/file3
      dir/subdir2/file4
    ]) do
      expect(@fs_cache.dirs_from("#{@dir}/dir").sort).to eq(["#{@dir}/dir/subdir1", "#{@dir}/dir/subdir2"].sort)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir1/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir2/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows which files are present when reading a directory before' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.files_in("#{@dir}/dir")
      expect(@fs_cache.exist?("#{@dir}/dir/file1")).to eq(true)
      [{ class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] }]
    end
  end

  it 'knows which files are missing when reading a directory before' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.files_in("#{@dir}/dir")
      expect(@fs_cache.exist?("#{@dir}/dir/missing_file")).to eq(false)
      [{ class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] }]
    end
  end

  it 'knows which files are present when reading a directory recursively before' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.files_from("#{@dir}/dir")
      expect(@fs_cache.exist?("#{@dir}/dir/subdir/file3")).to eq(true)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows which files are missing when reading a directory recursively before' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.files_from("#{@dir}/dir")
      expect(@fs_cache.exist?("#{@dir}/dir/subdir/missing_file")).to eq(false)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows which files are missing when scanning a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.scan(["#{@dir}/dir"], include_attributes: [])
      expect(@fs_cache.exist?("#{@dir}/dir/subdir/missing_file")).to eq(false)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows which files are present when scanning a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.scan(["#{@dir}/dir"], include_attributes: [])
      expect(@fs_cache.exist?("#{@dir}/dir/subdir/file3")).to eq(true)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows files lists of a directory after scanning a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
      dir/subdir/file4
    ]) do
      @fs_cache.scan(["#{@dir}/dir"], include_attributes: [])
      expect(@fs_cache.files_in("#{@dir}/dir/subdir").sort).to eq(%w[file3 file4].sort)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows recursive files lists of a directory after scanning a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir/file3
    ]) do
      @fs_cache.scan(["#{@dir}/dir"], include_attributes: [])
      expect(@fs_cache.files_from("#{@dir}/dir").sort).to eq(["#{@dir}/dir/file1", "#{@dir}/dir/file2", "#{@dir}/dir/subdir/file3"].sort)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir/*", File::FNM_DOTMATCH] }
      ]
    end
  end

  it 'knows recursive direcotry lists of a directory after scanning a directory' do
    expect_ops_to_be_cached(create_files: %w[
      dir/file1
      dir/file2
      dir/subdir1/file3
      dir/subdir2/file3
    ]) do
      @fs_cache.scan(["#{@dir}/dir"], include_attributes: [])
      expect(@fs_cache.dirs_from("#{@dir}/dir").sort).to eq(["#{@dir}/dir/subdir1", "#{@dir}/dir/subdir2"].sort)
      [
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir1/*", File::FNM_DOTMATCH] },
        { class: :Dir, method: :glob, args: ["#{@dir}/dir/subdir2/*", File::FNM_DOTMATCH] }
      ]
    end
  end

end
