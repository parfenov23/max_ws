# frozen_string_literal: true

module MaxWs
  module Reactions
    # Поставить реакцию на сообщение.
    #   client.add_reaction(chat_id: 119675094, message_id: "116...", emoji: "👍")
    def add_reaction(chat_id:, message_id:, emoji: "👍")
      request(178, {
        chatId:    chat_id,
        messageId: message_id,
        reaction:  { reactionType: "EMOJI", id: emoji }
      })
    end

    # Убрать свою реакцию с сообщения.
    #   client.remove_reaction(chat_id: 119675094, message_id: "116...")
    def remove_reaction(chat_id:, message_id:)
      request(179, {
        chatId:    chat_id,
        messageId: message_id
      })
    end

    # Получить реакции по списку сообщений.
    #   client.message_reactions(chat_id: 119675094, message_ids: ["116...", "116..."])
    def message_reactions(chat_id:, message_ids:)
      request(180, {
        chatId:     chat_id,
        messageIds: Array(message_ids)
      })
    end

    # Детальный список реакций на сообщение.
    #   client.reaction_details(chat_id: 119675094, message_id: "116...", count: 50)
    def reaction_details(chat_id:, message_id:, count: 50)
      request(181, {
        chatId:    chat_id,
        messageId: message_id,
        count:     count
      })
    end
  end
end