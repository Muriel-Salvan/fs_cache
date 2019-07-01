describe FsCache do

  context 'testing the size attribute' do

    it 'returns file\'s size properly' do
      with_cache(create_files: { 'file' => '123456' }) do |fs_cache, dir|
        expect(fs_cache.size_for("#{dir}/file")).to eq(6)
      end
    end

    it 'adds the empty? helper' do
      expect_ops_to_be_cached(create_files: {
        'file' => '123456',
        'empty_file' => ''
      }) do
        expect(@fs_cache.empty?("#{@dir}/file")).to eq(false)
        expect(@fs_cache.empty?("#{@dir}/empty_file")).to eq(true)
        [
          { class: :File, method: :exist?, args: ["#{@dir}/file"] },
          { class: :File, method: :stat, args: ["#{@dir}/file"] },
          { class: :File, method: :exist?, args: ["#{@dir}/empty_file"] },
          { class: :File, method: :stat, args: ["#{@dir}/empty_file"] }
        ]
      end
    end

  end

end
