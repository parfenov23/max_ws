# frozen_string_literal: true

module MaxWs
  module Models
    class Member < Base
      def contact
        Contact.new(client, raw["contact"] || {})
      end

      def id
        contact.id
      end

      def name
        contact.full_name
      end

      def online?
        raw.dig("presence", "status") == 3
      end

      def last_seen
        ts = raw.dig("presence", "seen")
        ts ? Time.at(ts) : nil
      end

      private

      def inspect_attrs
        "id=#{id} name=#{name.inspect} online=#{online?}"
      end
    end
  end
end
