module Opal
  class Builder
    # Sprockets compatible CacheStore
    class CacheStore
      attr_reader :environment

      def initialize(environment)
        @environment = environment
      end

      def store(key, contents, requires)
        environment.cache_set("opal/#{key}.cache", {
          :contents => contents, :requires => requires})
      end

      def retrieve(key)
        if obj = environment.cache_get("opal/#{key}.cache")
          return CachedAsset.new(obj)
        else
          nil
        end
      end
    end
  end
end
