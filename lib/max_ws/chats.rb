# frozen_string_literal: true

module MaxWs
  module Chats
    # Получить информацию о чатах/каналах по ID.
    #   client.chat_info(chat_ids: [-68090704770355])
    def chat_info(chat_ids:)
      request(48, { chatIds: Array(chat_ids) })
    end

    # Создать группу (CHAT).
    #   client.create_group(title: "Название", user_ids: [123037163])
    def create_group(title:, user_ids: [])
      request(64, {
        message: {
          cid:      generate_cid,
          attaches: [{
            _type:    "CONTROL",
            event:    "new",
            chatType: "CHAT",
            title:    title,
            userIds:  user_ids
          }]
        },
        notify: true
      })
    end

    # Создать канал (CHANNEL).
    #   client.create_channel(title: "Мой канал")
    def create_channel(title:)
      request(64, {
        message: {
          cid:      generate_cid,
          attaches: [{
            _type:    "CONTROL",
            event:    "new",
            chatType: "CHANNEL",
            title:    title,
            userIds:  []
          }]
        },
        notify: true
      })
    end

    # Изменить название, описание и/или опции чата/канала.
    #   client.update_chat(chat_id: -123, theme: "Новое название", description: "Описание")
    #   client.update_chat(chat_id: -123, options: { "JOIN_REQUEST" => true })
    def update_chat(chat_id:, theme: nil, description: nil, owner: nil, options: nil)
      payload = { chatId: chat_id }
      payload[:theme]       = theme       if theme
      payload[:description] = description if description
      payload[:owner]       = owner       if owner
      payload[:options]     = options     if options
      request(55, payload)
    end

    # Передать права владельца.
    #   client.transfer_ownership(chat_id: -123, new_owner_id: 36491273)
    def transfer_ownership(chat_id:, new_owner_id:)
      update_chat(chat_id: chat_id, owner: new_owner_id)
    end

    # Добавить участников в чат/канал.
    #   client.add_members(chat_id: -123, user_ids: [36491273])
    def add_members(chat_id:, user_ids:, show_history: true)
      request(77, {
        chatId:      chat_id,
        userIds:     Array(user_ids),
        showHistory: show_history,
        operation:   "add"
      })
    end

    # Удалить участника из чата/канала.
    #   client.remove_member(chat_id: -123, user_ids: [36491273])
    def remove_member(chat_id:, user_ids:)
      request(77, {
        chatId:    chat_id,
        userIds:   Array(user_ids),
        operation: "remove"
      })
    end

    # Назначить администратором (permissions: 255 = все права).
    #   client.add_admin(chat_id: -123, user_ids: [36491273])
    def add_admin(chat_id:, user_ids:, permissions: 255)
      request(77, {
        chatId:      chat_id,
        userIds:     Array(user_ids),
        type:        "ADMIN",
        operation:   "add",
        permissions: permissions
      })
    end

    # Снять права администратора.
    #   client.remove_admin(chat_id: -123, user_ids: [36491273])
    def remove_admin(chat_id:, user_ids:)
      request(77, {
        chatId:    chat_id,
        userIds:   Array(user_ids),
        type:      "ADMIN",
        operation: "remove"
      })
    end

    # Получить список участников.
    #   client.members(chat_id: -123, count: 50)
    def members(chat_id:, count: 50, marker: 0)
      request(59, {
        type:   "MEMBER",
        chatId: chat_id,
        marker: marker,
        count:  count
      })
    end

    # Получить заявки на вступление.
    #   client.join_requests(chat_id: -123)
    def join_requests(chat_id:, count: 50)
      request(59, {
        query:  "",
        type:   "JOIN_REQUEST",
        chatId: chat_id,
        count:  count
      })
    end

    # Принять заявку на вступление.
    #   client.accept_join(chat_id: -123, user_ids: [36491273])
    def accept_join(chat_id:, user_ids:, show_history: true)
      request(77, {
        chatId:      chat_id,
        userIds:     Array(user_ids),
        showHistory: show_history,
        operation:   "add",
        type:        "JOIN_REQUEST"
      })
    end

    # Отклонить заявку на вступление.
    #   client.reject_join(chat_id: -123, user_ids: [36491273])
    def reject_join(chat_id:, user_ids:)
      request(77, {
        chatId:    chat_id,
        userIds:   Array(user_ids),
        operation: "remove",
        type:      "JOIN_REQUEST"
      })
    end

    # Вступить в чат по invite-ссылке.
    #   client.join_by_link(link: "join/erVTFNCbrAB...")
    def join_by_link(link:)
      request(57, { link: link })
    end

    # Получить превью чата по invite-ссылке (без вступления).
    #   client.preview_link(link: "join/erVTFNCbrAB...")
    def preview_link(link:)
      request(89, { link: link })
    end

    # Покинуть чат/канал.
    #   client.leave_chat(chat_id: -123)
    def leave_chat(chat_id:)
      request(58, { chatId: chat_id })
    end

    # Подписаться на push-события чата.
    #   client.subscribe_chat(chat_id: -123)
    def subscribe_chat(chat_id:)
      request(75, { chatId: chat_id, subscribe: true })
    end

    # Отписаться от push-событий чата.
    #   client.unsubscribe_chat(chat_id: -123)
    def unsubscribe_chat(chat_id:)
      request(75, { chatId: chat_id, subscribe: false })
    end

    # Поиск чатов.
    #   client.search_chats(query: "Ruby", count: 10)
    #   client.search_chats(query: "Ruby", type: "CHANNEL")
    def search_chats(query:, count: 20, type: "ALL")
      request(60, { query: query, count: count, type: type })
    end

    # Глобальный поиск.
    #   client.global_search(query: "ключевое слово", count: 20)
    def global_search(query:, count: 20)
      request(68, { query: query, count: count })
    end

    # Настройки уведомлений чата (DND).
    #   client.mute_chat(chat_id: -123)        # мьют навсегда
    #   client.unmute_chat(chat_id: -123)       # снять мьют
    def mute_chat(chat_id:)
      request(22, { settings: { chats: { chat_id.to_s => { dontDisturbUntil: -1 } } } })
    end

    def unmute_chat(chat_id:)
      request(22, { settings: { chats: { chat_id.to_s => { dontDisturbUntil: 0 } } } })
    end

    # Общие чаты с пользователем.
    #   client.common_chats(user_ids: [36491273])
    def common_chats(user_ids:, marker: nil)
      payload = { userIds: Array(user_ids) }
      payload[:marker] = marker if marker
      request(198, payload)
    end

    # Получить URL для загрузки файла.
    #   client.upload_url(count: 1)
    def upload_url(count: 1)
      request(80, { count: count })
    end

    # Получить ссылки на видео.
    #   client.video_url(video_id: "...", token: "...", chat_id: -123, message_id: "...")
    def video_url(video_id:, token:, chat_id:, message_id:)
      request(83, {
        videoId:   video_id,
        token:     token,
        chatId:    chat_id,
        messageId: message_id
      })
    end
  end
end