# frozen_string_literal: true

module MaxWs
  module Contacts
    # Получить данные контактов по ID.
    #   client.contact_info(contact_ids: [7830845, 36491273])
    def contact_info(contact_ids:)
      request(32, { contactIds: Array(contact_ids) })
    end

    # Статус онлайн пользователей.
    #   client.presence(contact_ids: [7830845])
    def presence(contact_ids:)
      request(35, { contactIds: Array(contact_ids) })
    end

    # Поиск контакта по телефону.
    #   client.find_by_phone("+79222277865")
    def find_by_phone(phone)
      request(46, { phone: phone })
    end

    # Разрешить публичную ссылку (пользователь или канал).
    #   client.resolve_link("https://max.ru/channelname")
    def resolve_link(link)
      request(89, { link: link })
    end
  end
end