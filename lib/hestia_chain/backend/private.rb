# frozen_string_literal: true

require_relative 'base'
require 'json'
require 'fileutils'

module HestiaChain
  module Backend
    # Private backend stores anchors in a local JSON file.
    #
    # This backend is designed for:
    # - Stage 1 deployment (private/local storage)
    # - Small to medium scale deployments
    # - Situations where blockchain costs are not justified
    #
    # The storage format is a JSON file with the following structure:
    # {
    #   "metadata": { "version": "1.0", "created_at": "...", ... },
    #   "anchors": { "anchor_hash": { ... }, ... }
    # }
    #
    # @example Configuration
    #   config:
    #     backend: private
    #     private:
    #       storage_path: storage/hestia_anchors.json
    #       max_anchors: 100000
    #
    class Private < Base
      DEFAULT_STORAGE_PATH = 'storage/hestia_anchors.json'
      DEFAULT_MAX_ANCHORS = 100_000
      STORAGE_VERSION = '1.0'

      def initialize(config)
        super
        @storage_path = config.backend_config['storage_path'] || DEFAULT_STORAGE_PATH
        @max_anchors = config.backend_config['max_anchors'] || DEFAULT_MAX_ANCHORS
        @mutex = Mutex.new
        @data = nil
        load_storage
      end

      # Submit an anchor to the JSON file
      #
      # @param anchor [HestiaChain::Core::Anchor] Anchor to submit
      # @return [Hash] Result with status and anchor_hash
      #
      def submit_anchor(anchor)
        validate_anchor!(anchor)
        hash = normalize_hash(anchor.anchor_hash)

        @mutex.synchronize do
          if @data['anchors'].key?(hash)
            return {
              status: 'exists',
              anchor_hash: hash,
              message: 'Anchor already exists'
            }
          end

          # Check max anchors limit
          if @data['anchors'].size >= @max_anchors
            return {
              status: 'error',
              anchor_hash: hash,
              message: "Maximum anchor limit reached (#{@max_anchors})"
            }
          end

          @data['anchors'][hash] = {
            'anchor_hash' => hash,
            'anchor_type' => anchor.anchor_type,
            'source_id' => anchor.source_id,
            'data_hash' => anchor.data_hash,
            'participants' => anchor.participants,
            'metadata' => anchor.metadata,
            'timestamp' => anchor.timestamp,
            'previous_anchor_ref' => anchor.previous_anchor_ref,
            'stored_at' => Time.now.utc.iso8601
          }

          @data['metadata']['updated_at'] = Time.now.utc.iso8601
          @data['metadata']['anchor_count'] = @data['anchors'].size

          save_storage
        end

        {
          status: 'submitted',
          anchor_hash: hash,
          backend: 'private',
          storage_path: @storage_path
        }
      end

      # Verify an anchor exists
      #
      # @param anchor_hash [String] Anchor hash to verify
      # @return [Hash] Verification result
      #
      def verify_anchor(anchor_hash)
        hash = normalize_hash(anchor_hash)

        @mutex.synchronize do
          anchor = @data['anchors'][hash]

          if anchor
            {
              exists: true,
              anchor_hash: hash,
              anchor_type: anchor['anchor_type'],
              timestamp: anchor['timestamp'],
              stored_at: anchor['stored_at']
            }
          else
            {
              exists: false,
              anchor_hash: hash
            }
          end
        end
      end

      # Get an anchor by hash
      #
      # @param anchor_hash [String] Anchor hash
      # @return [Hash, nil] Anchor data or nil
      #
      def get_anchor(anchor_hash)
        hash = normalize_hash(anchor_hash)

        @mutex.synchronize do
          anchor = @data['anchors'][hash]
          return nil unless anchor

          # Convert to symbol keys for consistency with other backends
          symbolize_keys(anchor)
        end
      end

      # List anchors with filtering
      #
      # @param limit [Integer] Maximum number of anchors
      # @param anchor_type [String, nil] Filter by type
      # @param since [String, nil] Filter by timestamp
      # @return [Array<Hash>] List of anchors
      #
      def list_anchors(limit: 100, anchor_type: nil, since: nil)
        @mutex.synchronize do
          anchors = @data['anchors'].values

          # Filter by type
          anchors = anchors.select { |a| a['anchor_type'] == anchor_type } if anchor_type

          # Filter by timestamp
          if since
            since_time = Time.parse(since)
            anchors = anchors.select { |a| Time.parse(a['timestamp']) >= since_time }
          end

          # Sort by timestamp (newest first) and limit
          anchors
            .sort_by { |a| a['timestamp'] }
            .reverse
            .first(limit)
            .map { |a| symbolize_keys(a) }
        end
      end

      # Get backend type
      #
      # @return [Symbol] :private
      #
      def backend_type
        :private
      end

      # Check if backend is ready
      #
      # @return [Boolean] True if storage file is accessible
      #
      def ready?
        @data && @data['anchors'].is_a?(Hash)
      end

      # Get statistics
      #
      # @return [Hash] Backend statistics
      #
      def stats
        @mutex.synchronize do
          types = @data['anchors'].values.group_by { |a| a['anchor_type'] }

          super.merge(
            total_anchors: @data['anchors'].size,
            max_anchors: @max_anchors,
            storage_path: @storage_path,
            anchors_by_type: types.transform_values(&:count),
            storage_version: @data['metadata']['version'],
            created_at: @data['metadata']['created_at'],
            updated_at: @data['metadata']['updated_at']
          )
        end
      end

      # Get anchor count
      #
      # @return [Integer] Number of anchors stored
      #
      def count
        @mutex.synchronize { @data['anchors'].size }
      end

      # Export all anchors to a hash (for migration)
      #
      # @return [Hash] All anchors
      #
      def export_all
        @mutex.synchronize do
          @data['anchors'].transform_values { |a| symbolize_keys(a) }
        end
      end

      # Import anchors from another backend (for migration)
      #
      # @param anchors [Hash] Anchors to import (hash => data)
      # @param overwrite [Boolean] Overwrite existing anchors
      # @return [Hash] Import result
      #
      def import_anchors(anchors, overwrite: false)
        imported = 0
        skipped = 0

        @mutex.synchronize do
          anchors.each do |hash, data|
            hash = normalize_hash(hash)

            if @data['anchors'].key?(hash) && !overwrite
              skipped += 1
              next
            end

            @data['anchors'][hash] = stringify_keys(data)
            imported += 1
          end

          @data['metadata']['updated_at'] = Time.now.utc.iso8601
          @data['metadata']['anchor_count'] = @data['anchors'].size

          save_storage
        end

        {
          status: 'completed',
          imported: imported,
          skipped: skipped,
          total: @data['anchors'].size
        }
      end

      # Compact the storage file (remove any formatting)
      #
      # @return [Integer] File size after compaction
      #
      def compact!
        @mutex.synchronize do
          save_storage(compact: true)
          File.size(@storage_path)
        end
      end

      private

      # Load storage from file
      #
      def load_storage
        @mutex.synchronize do
          if File.exist?(@storage_path)
            content = File.read(@storage_path)
            @data = JSON.parse(content)
            migrate_storage_if_needed
          else
            initialize_storage
          end
        end
      rescue JSON::ParserError => e
        warn "[HestiaChain::Private] Error loading storage: #{e.message}"
        initialize_storage
      end

      # Initialize empty storage
      #
      def initialize_storage
        @data = {
          'metadata' => {
            'version' => STORAGE_VERSION,
            'created_at' => Time.now.utc.iso8601,
            'updated_at' => Time.now.utc.iso8601,
            'anchor_count' => 0
          },
          'anchors' => {}
        }
        save_storage
      end

      # Save storage to file
      #
      # @param compact [Boolean] If true, don't pretty-print
      #
      def save_storage(compact: false)
        FileUtils.mkdir_p(File.dirname(@storage_path))

        content = if compact
                    JSON.generate(@data)
                  else
                    JSON.pretty_generate(@data)
                  end

        # Write atomically
        temp_path = "#{@storage_path}.tmp"
        File.write(temp_path, content)
        File.rename(temp_path, @storage_path)
      end

      # Migrate storage format if needed
      #
      def migrate_storage_if_needed
        version = @data.dig('metadata', 'version')
        return if version == STORAGE_VERSION

        # Future migrations would go here
        @data['metadata']['version'] = STORAGE_VERSION
        save_storage
      end

      # Convert string keys to symbols
      #
      # @param hash [Hash] Hash with string keys
      # @return [Hash] Hash with symbol keys
      #
      def symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
        end
      end

      # Convert symbol keys to strings
      #
      # @param hash [Hash] Hash with symbol keys
      # @return [Hash] Hash with string keys
      #
      def stringify_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          result[key.to_s] = value.is_a?(Hash) ? stringify_keys(value) : value
        end
      end
    end
  end
end
