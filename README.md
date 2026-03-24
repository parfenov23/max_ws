# MaxWs

WebSocket-клиент для [MAX](https://max.ru) messenger API. ORM-like интерфейс для чатов, сообщений, контактов и реакций.

## Установка

```ruby
# Gemfile
gem "max_ws", git: "https://github.com/parfenov23/max_ws.git"
```

## Быстрый старт

```ruby
require "max_ws"

client = MaxWs::Client.new(token: ENV["MAX_WS_TOKEN"])

# Текущий пользователь
client.me.full_name  # => "Maksim Pervushin"

# Чаты
client.chats.channels.each { |ch| puts "#{ch.title} (#{ch.participants_count})" }

# Отправка сообщения
client.send_message(chat_id: 119675094, text: "Привет!")

# Получить чат по ID
chat = client.chat(-68090704770355)
chat.title              # => "Ruby Channel"
chat.participants_count # => 1234
chat.messages(count: 5) # => [ChatMessage, ...]

# История сообщений
chat.all_messages.first(100).each { |msg| puts msg }

# Участники
chat.members.each { |m| puts "#{m.name} online=#{m.online?}" }

# Контакты
contact = client.find_contact("+79222277865")
contact.full_name  # => "Ivan Petrov"

# Реакции
msg = chat.messages.first
msg.react("👍")
msg.reactions  # => {"counters"=>[{"count"=>2, "reaction"=>"👍"}]}

client.disconnect
```

## API

### Client

```ruby
client = MaxWs::Client.new(
  token:          "...",       # обязательный: токен авторизации
  device_id:      nil,         # опционально: UUID устройства
  on_push:        nil,         # опционально: callback для push-событий
  logger:         nil,         # опционально: Logger
  auto_reconnect: true         # опционально: автопереподключение
)

client.user_name    # имя пользователя
client.user_id      # ID пользователя
client.me           # => Contact
client.chats        # => ChatCollection
client.chat(id)     # => Chat
client.contacts(id) # => [Contact, ...]
client.disconnect
client.reconnect
```

### Сообщения

```ruby
client.send_message(chat_id:, text:, elements: [], attaches: [])
client.edit_message(chat_id:, message_id:, text:)
client.delete_message(chat_id:, message_ids:)
client.history(chat_id:, count: 30)
client.mark_read(chat_id:, message_id:)
client.typing(chat_id:)
```

### Чаты и каналы

```ruby
client.chat_info(chat_ids: [...])
client.create_channel(title:)
client.create_group(title:, user_ids:)
client.update_chat(chat_id:, theme:, description:, options:)
client.add_members(chat_id:, user_ids:)
client.remove_member(chat_id:, user_ids:)
client.join_by_link(link:)
client.leave_chat(chat_id:)
client.search_chats(query:, type: "ALL")
```

### Контакты

```ruby
client.contact_info(contact_ids: [...])
client.find_by_phone(phone)
client.presence(contact_ids: [...])
client.resolve_link(link)
```

### Реакции

```ruby
client.add_reaction(chat_id:, message_id:, emoji: "👍")
client.remove_reaction(chat_id:, message_id:)
client.message_reactions(chat_id:, message_ids:)
```

### ORM-модели

- `MaxWs::Models::Chat` — чат/канал с методами `messages`, `members`, `send_message`, `update`, `leave` и др.
- `MaxWs::Models::ChatMessage` — сообщение с `text(format: :html)`, `photos`, `videos`, `edit`, `delete`, `react`
- `MaxWs::Models::Contact` — контакт с `full_name`, `presence`, `common_chats`
- `MaxWs::Models::Member` — участник с `online?`, `last_seen`
- `MaxWs::Models::ChatCollection` — коллекция (Enumerable) с `find`, `find_by`, `where`, `channels`, `groups`, `search`
- `MaxWs::Models::Attachment` — фабрика: `Photo`, `Video`, `Share`, `Control`

## Push-события

```ruby
client = MaxWs::Client.new(token: "...", on_push: ->(data) {
  if data["opcode"] == 128  # новое сообщение
    puts "New message in chat #{data.dig('payload', 'chatId')}"
  end
})

# Подписка на конкретный чат
client.subscribe_chat(chat_id: -123)
```

## Зависимости

- Ruby >= 3.1
- [faye-websocket](https://github.com/faye/faye-websocket-ruby) ~> 0.11
- [eventmachine](https://github.com/eventmachine/eventmachine) ~> 1.2

## Лицензия

MIT
