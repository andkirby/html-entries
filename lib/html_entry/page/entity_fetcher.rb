require 'nokogiri'
require_relative '../error'
require_relative 'values_collector'
require_relative '../page'

module HtmlEntry
  module Page
    ##
    # This entity-html_entry class designed for reading data from HTML/XML block
    # according to instructions
    #
    # @see tests/html_entry/page/test_entity_fetcher.rb
    #
    class EntityFetcher
      ##
      # Cache fetched XML elements
      # @type [Hash]

      @selector_cache = {}

      # Get instructions
      #
      # @return [Array]
      #
      attr_reader :instructions

      ##
      # Init
      #
      def initialize
        @selector_cache ||= {}
      end

      ##
      # Set instructions
      #
      # Example for reading simple text by CSS selector:
      # {
      #   :name1 => {
      #     :type     => :instruction,
      #     :selector => '.test-block a.deep-in',
      #   }
      # }
      # There are filters allowed for type :instruction :
      # - :node_text, returns XML of found node
      # - :node, returns object Nokogiri::XML::Element of found node
      # - :no_strip, returns non-stripped text
      # - by default it use .strip for found text
      # Example for calculating instruction according to fetch fields:
      # {
      #   :vote_up   => {
      #     :type     => :instruction,
      #     :selector => '.vote-up',
      #   },
      #     :vote_down => {
      #     :type     => :instruction,
      #     :selector => '.vote-down',
      #   },
      #     :vote_diff => {
      #     :type     => :function,
      #     :function => Proc.new { |info, name, document, instruction|
      #       info[:vote_up].to_i - info[:vote_down].to_i
      #     },
      #   }
      # }
      #
      # @param [Array] instructions
      # @return [self]

      def instructions=(instructions)
        instructions = [instructions] unless instructions.instance_of? Array

        @instructions = instructions
      end

      ##
      # Fetch data from document
      #
      # @param [Nokogiri::HTML::Document, Nokogiri::XML::Element] document
      # @param [TrueClass, FalseClass] plenty Get plenty of elements
      #                                       or the only one
      # @return [Hash, Array]

      def fetch(document:, plenty: false)
        if plenty
          fetch_plenty(document)
        else
          fetch_single(document)
        end
      end

      ##
      # Fetch single data from document
      #
      # @param [Nokogiri::HTML::Document, Nokogiri::XML::Element] document
      # @return [Hash]

      def fetch_single(document)
        collector = get_values_collector(document)

        instructions.each do |instruction|
          node = Page.fetch_node(document, instruction)

          next unless instruction[:data]
          instruction[:data].each do |name, data_instruction|
            collector.fetch name, data_instruction, node
          end
        end

        collector.data
      end

      ##
      # Get value collector
      #
      # @param [Nokogiri::HTML::Document, Nokogiri::XML::Element] document
      # @return [Page::ValuesCollector]

      def get_values_collector(document)
        Page::ValuesCollector.new document:     document,
                                  instructions: instructions
      end

      ##
      # Fetch collection data from document
      #
      # @param [Nokogiri::HTML::Document, Nokogiri::XML::Element] document
      # @return [Hash]
      def fetch_plenty(document)
        unless instructions.instance_of? Array
          raise 'Instructions must be an array.'
        end

        collectors, data = process_instructions(document)

        collectors.each do |_i, collector|
          # @type [HtmlEntry::Page::ValuesCollector] collector
          data.push collector.data
        end

        data
      end

      protected

      def process_instructions(document)
        data = []
        # @type [HtmlEntry::Page::ValuesCollector[]] collectors
        collectors = {}
        instructions.each do |instruction|
          raise 'Instruction must be Hash.' unless instruction.instance_of? Hash
          nodes = retrieve_nodes(document, instruction)
          nodes.each_with_index do |node, i|
            process_node(document, node, instruction, collectors, i)
          end
        end
        [collectors, data]
      end

      # @param [Array, Nil] instruction
      def retrieve_nodes(document, instruction)
        nodes = Page.fetch_nodes(document, instruction)
        if nodes.nil? || instruction[:allow_empty] && nodes.count.zero?
          nodes = [nil]
        end
        nodes
      end

      def process_node(document, node, instruction, collectors, index)
        if instruction[:merge]
          # gather items under the same collector
          index = 0
        end

        unless collectors.key? index
          collectors[index] = get_values_collector(document)
        end

        return unless instruction[:data]

        instruction[:data].each do |name, data_instruction|
          collectors[index].fetch name, data_instruction, node
        end
      end

      ##
      # Check if merge nodes data must disabled
      #
      def data_has_option?(instruction, option:, value:)
        return false if instruction.key :merge

        !instruction[:data].select! do |_k, el|
          (el.is_a?(Hash) && (el[option] == value))
        end.nil?
      end
    end
  end
end
