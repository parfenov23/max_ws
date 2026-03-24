# frozen_string_literal: true

module MaxWs
  module Models
    class Chat < Base
      def id
        raw["id"]
      end

      def type
        raw["type"]
      end

      def title
        raw["title"]
      end

      def description
        raw["description"]
      end

      def access
        raw["access"]
      end

      def link
        raw["link"]
      end

      def participants_count
        raw["participantsCount"]
      end

      def owner_id
        raw["owner"]
      end

      def modified_at
        raw["modified"] ? Time.at(raw["modified"] / 1000.0) : nil
      end

      def options
        raw["options"] || {}
      end

      def channel?
        type == "CHANNEL"
      end

      def group?
        type == "CHAT"
      end

      def public?
        access == "PUBLIC"
      end

      def private?
        access == "PRIVATE"
      end

      def unread_count
        raw["newMessages"] || 0
      end

      # Заявка на вступление включена?
      def join_request?
        options["JOIN_REQUEST"] == true
      end

      def sign_admin?
        options["SIGN_ADMIN"] == true
      end

      def only_admin_can_add?
        options["ONLY_ADMIN_CAN_ADD_MEMBER"] == true
      end

      # ── Сообщения ──

      def messages(count: 30, from: nil, reactions: false)
        result = client.history(chat_id: id, count: count, from: from)
        msgs = (result["messages"] || []).map { |m| ChatMessage.new(client, m, chat_id: id) }
        enrich_reactions(msgs) if reactions && msgs.any?
        msgs
      end

      def all_messages(batch_size: 50)
        Enumerator.new do |y|
          cursor = (Time.now.to_f * 1000).to_i
          loop do
            result = client.history(chat_id: id, count: batch_size, from: cursor)
            msgs = result["messages"] || []
            break if msgs.empty?
            msgs.each { |m| y << ChatMessage.new(client, m, chat_id: id) }
            oldest = msgs.last["time"]
            break if oldest.nil? || oldest >= cursor
            cursor = oldest - 1
          end
        end.lazy
      end

      def send_message(text, **opts)
        result = client.send_message(chat_id: id, text: text, **opts)
        ChatMessage.new(client, result["message"], chat_id: id)
      end

      def typing
        client.typing(chat_id: id)
      end

      def mark_read(message_id: nil)
        unless message_id
          msgs = messages(count: 1)
          message_id = msgs.first&.id
        end
        client.mark_read(chat_id: id, message_id: message_id) if message_id
      end

      # ── Участники ──

      def members(count: 50, marker: 0)
        result = client.members(chat_id: id, count: count, marker: marker)
        (result["members"] || []).map { |m| Member.new(client, m) }
      end

      def all_members(batch_size: 50)
        Enumerator.new do |y|
          marker = 0
          loop do
            result = client.members(chat_id: id, count: batch_size, marker: marker)
            batch = result["members"] || []
            break if batch.empty?
            batch.each { |m| y << Member.new(client, m) }
            marker += batch.size
            break if batch.size < batch_size
          end
        end.lazy
      end

      def join_requests(count: 50)
        result = client.join_requests(chat_id: id, count: count)
        (result["members"] || []).map { |m| Member.new(client, m) }
      end

      def add_members(user_ids, show_history: true)
        client.add_members(chat_id: id, user_ids: user_ids, show_history: show_history)
      end

      def remove_member(user_ids)
        client.remove_member(chat_id: id, user_ids: user_ids)
      end

      def accept_join(user_ids, show_history: true)
        client.accept_join(chat_id: id, user_ids: user_ids, show_history: show_history)
      end

      def reject_join(user_ids)
        client.reject_join(chat_id: id, user_ids: user_ids)
      end

      def add_admin(user_ids, permissions: 255)
        client.add_admin(chat_id: id, user_ids: user_ids, permissions: permissions)
      end

      def remove_admin(user_ids)
        client.remove_admin(chat_id: id, user_ids: user_ids)
      end

      # ── Управление чатом ──

      def update(title: nil, description: nil, options: nil)
        result = client.update_chat(
          chat_id: id, theme: title, description: description, options: options
        )
        @raw = result["chat"] if result["chat"]
        self
      end

      def enable_join_request
        update(options: { "JOIN_REQUEST" => true })
      end

      def disable_join_request
        update(options: { "JOIN_REQUEST" => false })
      end

      def transfer_ownership(new_owner_id)
        client.transfer_ownership(chat_id: id, new_owner_id: new_owner_id)
      end

      def leave
        client.leave_chat(chat_id: id)
      end

      def subscribe
        client.subscribe_chat(chat_id: id)
      end

      def unsubscribe
        client.unsubscribe_chat(chat_id: id)
      end

      def mute
        client.mute_chat(chat_id: id)
      end

      def unmute
        client.unmute_chat(chat_id: id)
      end

      def reload
        result = client.chat_info(chat_ids: [id])
        fresh = (result["chats"] || []).first
        @raw = fresh if fresh
        self
      end

      def to_s
        "[#{type}] #{title} (#{participants_count} участн.)"
      end

      private

      def enrich_reactions(msgs)
        ids = msgs.map(&:id).compact
        return if ids.empty?
        result = client.message_reactions(chat_id: id, message_ids: ids)
        reactions_map = result["messagesReactions"] || {}
        msgs.each do |msg|
          ri = reactions_map[msg.id]
          msg.raw["reactionInfo"] = ri if ri && !ri.empty?
        end
      end

      def inspect_attrs
        "id=#{id} type=#{type} title=#{title.inspect} participants=#{participants_count}"
      end
    end
  end
end
