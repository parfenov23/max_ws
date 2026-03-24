# frozen_string_literal: true

module MaxWs
  module Models
    class ChatMessage < Base
      attr_reader :chat_id

      def initialize(client, raw, chat_id:)
        super(client, raw)
        @chat_id = chat_id
      end

      def id
        raw["id"]
      end

      def sender_id
        raw["sender"]
      end

      # Текст сообщения.
      #   msg.text             # => "Привет жирный мир!"
      #   msg.text(format: :html)  # => "Привет <strong>жирный</strong> <em>мир!</em>"
      def text(format: :plain)
        plain = raw["text"]
        return plain unless format == :html && plain && elements.any?
        elements_to_html(plain, elements)
      end

      def type
        raw["type"]
      end

      def time
        raw["time"] ? Time.at(raw["time"] / 1000.0) : nil
      end
      alias_method :published_at, :time

      def timestamp
        raw["time"]
      end

      def elements
        raw["elements"] || []
      end

      def attaches
        raw["attaches"] || []
      end

      # Аттачменты как объекты (Photo, Video, Share, Control).
      def attachments
        attaches.map { |a| Attachment.build(client, a, chat_id: chat_id) }
      end

      # Фильтры по типу.
      def photos
        attachments.select { |a| a.type == "PHOTO" }
      end

      def videos
        attachments.select { |a| a.type == "VIDEO" }
      end

      def shares
        attachments.select { |a| a.type == "SHARE" }
      end

      def has_attachments?
        attaches.any? { |a| a["_type"] != "CONTROL" }
      end

      def edited?
        raw["status"] == "EDITED"
      end

      def views
        raw.dig("stats", "views")
      end

      def reaction_info
        raw["reactionInfo"]
      end

      # Отправитель как Contact.
      def sender
        return nil unless sender_id
        result = client.contact_info(contact_ids: [sender_id])
        c = (result["contacts"] || []).first
        c ? Contact.new(client, c) : nil
      end

      # Чат, в котором это сообщение.
      def chat
        result = client.chat_info(chat_ids: [chat_id])
        c = (result["chats"] || []).first
        c ? Chat.new(client, c) : nil
      end

      # Редактировать сообщение.
      def edit(new_text, elements: [], attachments: [])
        result = client.edit_message(
          chat_id: chat_id, message_id: id,
          text: new_text, elements: elements, attachments: attachments
        )
        @raw = result["message"] if result["message"]
        self
      end

      # Удалить сообщение.
      def delete(for_me: false)
        client.delete_message(chat_id: chat_id, message_ids: [id], for_me: for_me)
        true
      end

      # Поставить реакцию.
      def react(emoji = "👍")
        client.add_reaction(chat_id: chat_id, message_id: id, emoji: emoji)
      end

      # Убрать реакцию.
      def unreact
        client.remove_reaction(chat_id: chat_id, message_id: id)
      end

      # Получить реакции.
      def reactions
        result = client.message_reactions(chat_id: chat_id, message_ids: [id])
        (result["messagesReactions"] || {})[id] || {}
      end

      # Детальный список кто поставил реакции.
      def reaction_details(count: 50)
        client.reaction_details(chat_id: chat_id, message_id: id, count: count)
      end

      # Статистика просмотров.
      def view_stats
        result = client.message_views(chat_id: chat_id, message_ids: [id])
        result.dig("stats", id)
      end

      # Контекст вокруг сообщения.
      def context(forward: 15, backward: 15)
        result = client.message_context(
          chat_id: chat_id, message_id: id,
          forward: forward, backward: backward
        )
        (result["messages"] || []).map { |m| ChatMessage.new(client, m, chat_id: chat_id) }
      end

      def to_s
        "[#{time&.strftime('%H:%M')}] #{text&.slice(0, 100)}"
      end

      private

      ELEMENT_TAGS = {
        "STRONG"        => "strong",
        "BOLD"          => "strong",
        "EMPHASIZED"    => "em",
        "ITALIC"        => "em",
        "STRIKETHROUGH" => "s",
        "UNDERLINE"     => "u",
        "QUOTE"         => "blockquote",
        "CODE"          => "code",
        "MONOSPACE"     => "code",
        "MONOSPACED"    => "code",
        "PRE"           => "pre",
      }.freeze

      def elements_to_html(plain, elems)
        chars = plain.chars
        events = []

        sorted = elems
          .select { |e| e["type"] && e["length"].is_a?(Integer) }
          .map { |e| e["from"] ? e : e.merge("from" => 0) }
          .sort_by { |e| [e["from"], -e["length"]] }

        sorted.each_with_index do |el, idx|
          from   = el["from"]
          length = el["length"]
          to     = from + length

          case el["type"]
          when "LINK"
            url = el.dig("attributes", "url") || ""
            events << [from, :open,  idx, "<a href=\"#{escape_html(url)}\">"]
            events << [to,   :close, idx, "</a>"]
          when "USER_MENTION"
            events << [from, :open,  idx, "<span class=\"mention\">"]
            events << [to,   :close, idx, "</span>"]
          else
            tag = ELEMENT_TAGS[el["type"]]
            next unless tag
            events << [from, :open,  idx, "<#{tag}>"]
            events << [to,   :close, idx, "</#{tag}>"]
          end
        end

        events.sort_by! { |pos, type, pri, _| [pos, type == :close ? 0 : 1, type == :close ? -pri : pri] }

        result = []
        char_idx = 0
        event_idx = 0

        while char_idx <= chars.length
          while event_idx < events.length && events[event_idx][0] == char_idx
            result << events[event_idx][3]
            event_idx += 1
          end
          result << escape_html(chars[char_idx]) if char_idx < chars.length
          char_idx += 1
        end

        result.join.gsub("\n", "<br>")
      end

      def escape_html(str)
        str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def inspect_attrs
        "id=#{id} chat_id=#{chat_id} time=#{time&.strftime('%Y-%m-%d %H:%M')} text=#{text&.slice(0, 50).inspect}"
      end
    end
  end
end
