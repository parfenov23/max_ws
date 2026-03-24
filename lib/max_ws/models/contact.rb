# frozen_string_literal: true

module MaxWs
  module Models
    class Contact < Base
      def id
        raw["id"]
      end

      def name
        names_entry&.dig("name")
      end

      def first_name
        names_entry&.dig("firstName")
      end

      def last_name
        names_entry&.dig("lastName")
      end

      def full_name
        [first_name, last_name].compact.join(" ")
      end

      def phone
        raw["phone"]
      end

      def photo_id
        raw["photoId"]
      end

      def photo_url
        raw["baseUrl"]
      end

      def options
        raw["options"] || []
      end

      def status
        raw["accountStatus"]
      end

      # Онлайн-статус.
      #   client.me.presence # => { seen: Time, online: true/false }
      def presence
        result = client.presence(contact_ids: [id])
        p = result.dig("presence", id.to_s)
        return nil unless p
        { seen: p["seen"] ? Time.at(p["seen"]) : nil, online: p["status"] == 3 }
      end

      # Общие чаты с этим контактом.
      #   contact.common_chats # => [Chat, ...]
      def common_chats
        result = client.common_chats(user_ids: [id])
        (result["commonChats"] || []).map { |c| Chat.new(client, c) }
      end

      # Получить свежие данные с сервера.
      def reload
        result = client.contact_info(contact_ids: [id])
        fresh = (result["contacts"] || []).find { |c| c["id"] == id }
        @raw = fresh if fresh
        self
      end

      private

      def names_entry
        (raw["names"] || []).first
      end

      def inspect_attrs
        "id=#{id} name=#{full_name.inspect}"
      end
    end
  end
end
