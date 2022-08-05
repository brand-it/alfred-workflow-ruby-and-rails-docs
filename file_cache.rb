# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'zlib'

# FileCache.new('special_cache').fetch do
#  JSON.parse(Net::HTTP.get(URI("#{HOST}/search.json?q=#{query}")))
# end
class FileCache
  class Error < StandardError; end
  MAX_EXPIRES_IN = 60 * 60 * 24 * 30 # 1 month
  CACHE_DIR = File.expand_path('./cache').tap { |path| FileUtils.mkdir_p(path) }
  attr_reader :key, :expires_in, :compress, :dir_path

  def initialize(key, expires_in: MAX_EXPIRES_IN, compress: true)
    key = key.reject { |k| k.to_s == '' } if key.is_a?(Array)
    @key = key.is_a?(Array) ? key.last : key
    @dir_path = key[0..-2].join('/') if key.is_a?(Array)
    @dir_path = nil if @dir_path.to_s == ''
    @expires_in = expires_in
    @compress = compress
  end

  def fetch(&block)
    create_dir_if_not_exist
    return read unless expired?

    call(&block).tap { |data| write!(data) }
  rescue StandardError => e
    delete!
    raise e
  end

  private

  def create_dir_if_not_exist
    return if exists?

    FileUtils.mkdir_p([CACHE_DIR, dir_path].compact.join('/'))
  end

  def call(&block)
    block.call
  rescue StandardError => e
    raise(
      e.class,
      e.message,
      e.backtrace.reject { |line| line.include?(__FILE__) }
    )
  ensure
    clear_expired_files
  end

  def write!(data)
    File.write(file_path, compress!(data))
  end

  def compress!(data)
    if compress
      Zlib::Deflate.deflate(Marshal.dump(data))
    else
      Marshal.dump(data)
    end
  end

  def read
    decompress! File.read(file_path)
  end

  def expired?
    !exists? || File.mtime(file_path) < Time.now - expires_in
  end

  def exists?
    File.exist?(file_path)
  end

  # rubocop:disable Security/MarshalLoad
  def decompress!(data)
    if compress
      Marshal.load(Zlib::Inflate.inflate(data))
    else
      Marshal.load(data)
    end
  end
  # rubocop:enable Security/MarshalLoad

  def file_path
    @file_path ||= [CACHE_DIR, dir_path, cache_key].compact.join('/')
  end

  def cache_key
    Base64.urlsafe_encode64(key)
  end

  def delete!
    return unless exists?

    File.delete(file_path)
  end

  def clear_expired_files
    Thread.new do
      Dir["#{CACHE_DIR}/**/*"].each do |file|
        File.delete(file) if File.mtime(file) < Time.now - MAX_EXPIRES_IN
      rescue Errno::EPERM
        FileUtils.rm_rf(file)
      end
    end.join
  end
end
