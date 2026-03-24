# frozen_string_literal: true

module MaxWs
  module Messages
    # Отправить текстовое сообщение.
    #   client.send_message(chat_id: 119675094, text: "Привет!")
    #   client.send_message(chat_id: 119675094, text: "Жирный текст", elements: [{ type: "STRONG", from: 0, length: 6 }])
    def send_message(chat_id:, text:, elements: [], attaches: [], notify: true)
      request(64, {
        chatId:  chat_id,
        message: {
          text:     text,
          cid:      generate_cid,
          elements: elements,
          attaches: attaches
        },
        notify: notify
      })
    end

    # Редактировать сообщение.
    #   client.edit_message(chat_id: -123, message_id: "116215598830594055", text: "Новый текст")
    def edit_message(chat_id:, message_id:, text:, elements: [], attachments: [])
      request(67, {
        chatId:      chat_id,
        messageId:   message_id,
        text:        text,
        elements:    elements,
        attachments: attachments
      })
    end

    # Удалить сообщение(я).
    #   client.delete_message(chat_id: -123, message_ids: ["116215598830594055"])
    #   client.delete_message(chat_id: -123, message_ids: ["116215598830594055"], for_me: true)
    def delete_message(chat_id:, message_ids:, for_me: false)
      message_ids = Array(message_ids)
      request(66, {
        chatId:     chat_id,
        messageIds: message_ids,
        forMe:      for_me
      })
    end

    # Загрузить историю сообщений.
    #   client.history(chat_id: -68090704770355, count: 30)
    #   client.history(chat_id: -68090704770355, from: 1773307670092, forward: 30, backward: 30)
    def history(chat_id:, count: 30, from: nil, forward: 0, backward: nil)
      backward ||= count
      from     ||= (Time.now.to_f * 1000).to_i
      request(49, {
        chatId:      chat_id,
        from:        from,
        forward:     forward,
        backward:    backward,
        getMessages: true
      })
    end

    # Отметить сообщение прочитанным.
    #   client.mark_read(chat_id: 119675094, message_id: "116215414115928785")
    def mark_read(chat_id:, message_id:, mark: nil)
      mark ||= (Time.now.to_f * 1000).to_i
      request(50, {
        type:      "READ_MESSAGE",
        chatId:    chat_id,
        messageId: message_id,
        mark:      mark
      })
    end

    # Индикатор набора текста.
    #   client.typing(chat_id: 119675094)
    #   client.typing(chat_id: 119675094, type: nil) # остановить
    def typing(chat_id:, type: "TEXT")
      fire(65, { chatId: chat_id, type: type })
    end

    # Получить контекст вокруг сообщения.
    #   client.message_context(chat_id: -123, message_id: "116...", forward: 10, backward: 10)
    def message_context(chat_id:, message_id:, forward: 15, backward: 15, attach_types: [])
      request(51, {
        chatId:      chat_id,
        messageId:   message_id,
        attachTypes: attach_types,
        forward:     forward,
        backward:    backward
      })
    end

    # Получить статистику просмотров сообщений.
    #   client.message_views(chat_id: -123, message_ids: ["116..."])
    def message_views(chat_id:, message_ids:)
      request(74, {
        chatId:     chat_id,
        messageIds: Array(message_ids)
      })
    end

    # Получить превью ссылки.
    #   client.link_preview("https://max.ru/channelname")
    def link_preview(url)
      request(70, { text: url })
    end
  end
end