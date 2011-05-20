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

  end
end
