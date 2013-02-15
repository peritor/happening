module Happening
  module Utils
    protected

    def symbolize_keys(hash)
      hash.inject({}) do |h, kv|
        h[kv[0].to_sym] = kv[1]
        h
      end
    end

    def assert_valid_keys(hash, *valid_keys)
      unknown_keys = hash.keys - [valid_keys].flatten
      raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
    end

    def present?(obj)
      !blank?(obj)
    end

    def blank?(obj)
      obj.respond_to?(:empty?) ? obj.empty? : !obj
    end

    def underscore_string(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr("-", "_").
        downcase
    end

    def node_to_value(node)
      if node.is_a?(Nokogiri::XML::Text)
        unless node.content.strip.empty?
          parse_string_value(node.name, node.content)
        end
      elsif node.is_a?(Nokogiri::XML::Element)
        if node.children.size == 1 && node.children.first.is_a?(Nokogiri::XML::Text)
          node_to_value(node.children.first)
        else
          node.children.inject({}) do |hash, child|
            if val = node_to_value(child)
              hash[underscore_string(child.name).to_sym] = parse_string_value(child.name, val)
            end
            hash
          end
        end
      end
    end

    def parse_string_value(str)
      str
    end

  end
end
