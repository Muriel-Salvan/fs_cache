describe FsCache do

  context 'testing the crc attribute' do

    it 'returns file\'s crc properly' do
      with_cache(create_files: { 'file' => '123456' }) do |fs_cache, dir|
        expect(fs_cache.crc_for("#{dir}/file")).to eq('8890E6E0')
      end
    end

    it 'adds the diff_dirs helper' do
      expect_ops_to_be_cached(create_files: {
        'dir1/file1' => 'Content 1',
        'dir1/file2' => 'Content 2',
        'dir1/file4' => 'Content 4',
        'dir1/file6' => 'Content 6.1',
        'dir2/file2' => 'Content 2',
        'dir2/file3' => 'Content 1',
        'dir2/file5' => 'Content 5',
        'dir2/file6' => 'Content 6.2'
      }, strict_ops_order: false) do
        expect(@fs_cache.diff_dirs("#{@dir}/dir1", "#{@dir}/dir2")).to eq({
          added: %w[file5],
          deleted: %w[file4],
          different: %w[file6],
          renamed: [%w[file1 file3]],
          same: %w[file2]
        })
        [
          { class: :Dir, method: :glob, args: ["#{@dir}/dir1/*", File::FNM_DOTMATCH] },
          { class: :Dir, method: :glob, args: ["#{@dir}/dir2/*", File::FNM_DOTMATCH] },
          { class: :File, method: :open, args: ["#{@dir}/dir1/file1", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir1/file2", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir1/file4", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir1/file6", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir2/file2", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir2/file3", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir2/file5", 'rb'] },
          { class: :File, method: :open, args: ["#{@dir}/dir2/file6", 'rb'] }
        ]
      end
    end

  end

end
