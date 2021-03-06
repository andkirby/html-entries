require_relative 'page/entity_fetcher'

module HtmlEntry
  ##
  # Page fetcher
  #
  class PageFetcher
    ##
    # Set instructions
    #
    # @param [Hash] instructions
    # @return [self]

    attr_writer :instructions

    # Get instructions
    #
    # @return [Hash]

    attr_reader :instructions

    # Fetch entities from document
    #
    # @param [Nokogiri::HTML::Document] document
    # @return [Hash]

    def fetch(document)
      items = []
      if instructions[:block].nil?
        # "block" instructions is not defined
        block_document = if document.instance_of?(Nokogiri::HTML::Document)
                           fetch_block_document(
                               document,
                               type:     :selector,
                               selector: 'body'
                           ).first
                         else
                           document
                         end

        fetch_data(block_document, instructions[:entity]).each do |element|
          items.push element
        end
      else
        # fetch each "block" and process entities
        fetch_block_document(document, instructions[:block]).each do |block_document|
          fetch_data(block_document, instructions[:entity]).each do |element|
            items.push element
          end
        end
      end
      items
    end

    ##
    # Check if it's a last page
    #
    # @param [Nokogiri::HTML::Document] document
    # @return [TrueClass, FalseClass]

    def last_page?(document)
      if instructions[:last_page][:type] == :function
        !!call_function(document, instructions[:last_page])
      else
        Page.fetch_nodes(document, instructions[:last_page]).count > 0
      end
    end

    protected

    ##
    # Fetch entity data
    #
    # @param [Nokogiri::XML::Element] entity_document
    # @param [Hash] instructions
    # @return [Hash]

    def fetch_data(entity_document, instructions)
      fetcher              = Page::EntityFetcher.new
      fetcher.instructions = instructions
      fetcher.fetch(document: entity_document, plenty: true)
    end

    ##
    # Fetch entities on a page
    #
    # @param [Nokogiri::HTML::Document] document
    # @return [Nokogiri::XML::NodeSet]

    def fetch_block_document(document, instructions)
      raise 'Instructions are not set.' if instructions.nil?

      return call_function(document, instructions) if instructions[:type] == :function

      Page.fetch_nodes(document, instructions)
    end

    ##
    # Call custom function
    #
    # @param [Nokogiri::HTML::Document] document
    # @param [Hash] instruction
    # @return [*]

    def call_function(document, instruction)
      instruction[:function].call document, instruction
    end
  end
end
