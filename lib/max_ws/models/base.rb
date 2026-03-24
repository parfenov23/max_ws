# frozen_string_literal: true

module MaxWs
  module Models
    # Базовый класс моделей. Хранит ссылку на WS-клиент и сырые данные.
    class Base
      attr_reader :raw, :client

      def initialize(client, raw = {})
        @client = client
        @raw    = raw || {}
      end

      def inspect
        "#<#{self.class.name} #{inspect_attrs}>"
      end

      private

      def inspect_attrs
        ""
      end
    end
  end
end
