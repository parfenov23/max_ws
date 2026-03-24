# frozen_string_literal: true

require "faye/websocket"
require "eventmachine"
require "json"
require "securerandom"
require "monitor"
require "timeout"
require "logger"

module MaxWs
  # WebSocket-клиент для MAX API (faye-websocket + EventMachine).
  #
  # Использование:
  #
  #   client = MaxWs::Client.new(token: ENV["MAX_WS_TOKEN"])
  #   client.send_message(chat_id: 119675094, text: "Привет!")
  #   client.history(chat_id: -68090704770355, count: 10)
  #   client.disconnect
  #
  class Client
    WS_URL = "wss://ws-api.oneme.ru/websocket"
    PROTOCOL_VERSION = 11
    KEEPALIVE_INTERVAL = 30
    RECONNECT_BASE_DELAY = 1    # секунды
    RECONNECT_MAX_DELAY  = 60   # максимальная задержка
    RECONNECT_MAX_ATTEMPTS = 10 # после этого сдаёмся

    attr_reader :profile, :raw_chats, :connected

    def initialize(token:, device_id: nil, on_push: nil, logger: nil, auto_reconnect: true)
      @token     = token.to_s.gsub(/\A"|"\z/, "")
      @device_id = device_id || SecureRandom.uuid
      @on_push   = on_push
      @logger    = logger || Logger.new($stdout, level: :info)
      @seq       = 0
      @pending   = {}
      @seen      = Set.new
      @connected = false
      @mon       = Monitor.new
      @ws        = nil
      @em_thread = nil
      @keepalive_timer = nil
      @auto_reconnect  = auto_reconnect
      @reconnect_attempts = 0
      @shutting_down = false

      extend Messages
      extend Chats
      extend Contacts
      extend Reactions

      connect
    end

    def connect(chats_count: 40, timeout: 15)
      @chats_count = chats_count
      @connect_timeout = timeout
      @shutting_down = false

      ready = Queue.new
      start_ws_connection(ready, chats_count, timeout)

      # Ждём завершения подключения
      result = Timeout.timeout(timeout) { ready.pop }
      if result == :error
        raise ApiError.new("connect_failed", @last_connect_error || "Не удалось подключиться")
      end

      @reconnect_attempts = 0
      @logger.info "[MaxWs] Подключён как: #{user_name} (id: #{user_id}), чатов: #{@raw_chats&.size}"
      self
    rescue Timeout::Error
      disconnect
      raise TimeoutError, "Таймаут подключения к #{WS_URL}"
    end

    def disconnect
      @shutting_down = true
      @connected = false
      flush_pending("disconnected")
      if EM.reactor_running?
        EM.next_tick do
          EM.cancel_timer(@keepalive_timer) if @keepalive_timer
          @ws&.close
          EM.stop
        end
      end
      @em_thread&.join(3)
      @em_thread = nil
      @logger.info "[MaxWs] Отключён"
    end

    def reconnect(**opts)
      disconnect
      @seq     = 0
      @seen    = Set.new
      @pending = {}
      @reconnect_attempts = 0
      connect(**opts)
    end

    def user_name
      return "?" unless @profile
      names = @profile.dig("contact", "names")
      return "?" unless names&.any?
      n = names.first
      [n["firstName"], n["lastName"]].compact.join(" ")
    end

    def user_id
      @profile&.dig("contact", "id")
    end

    # ── ORM-интерфейс ──

    # Коллекция чатов.
    #   client.chats                        # => ChatCollection
    #   client.chats.first                  # => Chat
    #   client.chats.find(-68090704770355)  # => Chat
    #   client.chats.find_by(title: "Ruby") # => Chat
    #   client.chats.channels               # => [Chat, ...]
    #   client.chats.search("ruby")         # => [Chat, ...]
    def chats
      Models::ChatCollection.new(self, @raw_chats)
    end

    # Текущий пользователь как Contact.
    #   client.me            # => Contact
    #   client.me.full_name  # => "Maksim Pervushin"
    def me
      Models::Contact.new(self, @profile&.dig("contact"))
    end

    # Найти контакт по телефону.
    #   client.find_contact("+79222277865") # => Contact
    def find_contact(phone)
      result = find_by_phone(phone)
      Models::Contact.new(self, result["contact"])
    end

    # Получить контакты по ID.
    #   client.contacts(7830845, 36491273) # => [Contact, ...]
    def contacts(*ids)
      result = contact_info(contact_ids: ids.flatten)
      (result["contacts"] || []).map { |c| Models::Contact.new(self, c) }
    end

    # Получить чат по ID как объект Chat.
    #   client.chat(-68090704770355) # => Chat
    def chat(chat_id)
      result = chat_info(chat_ids: [chat_id])
      c = (result["chats"] || []).first
      c ? Models::Chat.new(self, c) : nil
    end

    # Создать новый канал.
    #   client.new_channel("Мой канал") # => Chat
    def new_channel(title)
      result = create_channel(title: title)
      Models::Chat.new(self, result["chat"])
    end

    # Создать новую группу.
    #   client.new_group("Название", user_ids: [36491273]) # => Chat
    def new_group(title, user_ids: [])
      result = create_group(title: title, user_ids: user_ids)
      Models::Chat.new(self, result["chat"])
    end

    # Найти канал/пользователя по публичной ссылке.
    #   client.resolve("https://max.ru/id1911005157_gos") # => Chat или Contact
    def resolve(link)
      result = resolve_link(link)
      if result["chat"]
        Models::Chat.new(self, result["chat"])
      elsif result["contact"]
        Models::Contact.new(self, result["contact"])
      else
        result
      end
    end

    # Отправить запрос и дождаться ответа.
    def request(opcode, payload, timeout: 10)
      seq = next_seq
      promise = Queue.new
      @mon.synchronize { @pending[seq] = promise }

      send_raw(cmd: 0, seq: seq, opcode: opcode, payload: payload)

      result = Timeout.timeout(timeout) { promise.pop }
      if result.is_a?(ErrorResponse)
        raise ApiError.new(result.error, result.message)
      end
      result
    rescue Timeout::Error
      @mon.synchronize { @pending.delete(seq) }
      raise TimeoutError, "Таймаут ответа seq:#{seq} opcode:#{opcode}"
    end

    # Отправить запрос без ожидания ответа.
    def fire(opcode, payload)
      seq = next_seq
      send_raw(cmd: 0, seq: seq, opcode: opcode, payload: payload)
      seq
    end

    # Установить обработчик push-событий.
    #   client.on_push { |msg| puts "Push opcode:#{msg['opcode']}" }
    def on_push(&block)
      @on_push = block
    end

    private

    def start_ws_connection(ready, chats_count, timeout)
      @last_connect_error = nil

      if EM.reactor_running?
        setup_ws_handlers(ready, chats_count, timeout)
      else
        @em_thread = Thread.new do
          EM.run { setup_ws_handlers(ready, chats_count, timeout) }
        end
      end
    end

    def setup_ws_handlers(ready, chats_count, timeout)
      headers = { "Origin" => "https://web.max.ru" }
      @ws = Faye::WebSocket::Client.new(WS_URL, [], headers: headers)

      @ws.on :open do |_|
        @logger.info "[MaxWs] WebSocket открыт"
        perform_handshake(ready, chats_count, timeout)

        @keepalive_timer = EM.add_periodic_timer(KEEPALIVE_INTERVAL) do
          fire(1, { interactive: true }) if @connected
        end
      end

      @ws.on :message do |event|
        on_message(event.data)
      end

      @ws.on :close do |event|
        was_connected = @connected
        @connected = false
        EM.cancel_timer(@keepalive_timer) if @keepalive_timer
        flush_pending("connection lost")
        @logger.warn "[MaxWs] WS closed (code=#{event.code}, reason=#{event.reason})"

        if @shutting_down
          # Штатное отключение
        elsif @auto_reconnect
          schedule_auto_reconnect
        else
          ready.push(:error) rescue nil
        end
      end
    end

    def perform_handshake(ready, chats_count, timeout)
      # Шаг 1: Negotiation (seq:0, opcode:6)
      negotiation_promise = Queue.new
      @mon.synchronize { @pending[0] = negotiation_promise }
      send_raw(cmd: 0, seq: 0, opcode: 6, payload: {
        userAgent: {
          deviceType:      "WEB",
          locale:          "ru",
          deviceLocale:    "ru",
          osVersion:       "macOS",
          deviceName:      "Ruby",
          headerUserAgent: "MaxWs Ruby/#{RUBY_VERSION}",
          appVersion:      "26.3.6",
          screen:          "1080x1920 1.0x",
          timezone:        "Europe/Moscow"
        },
        deviceId: @device_id
      })

      # Шаг 2: Авторизация (seq:1, opcode:19)
      EM.add_timer(0.3) do
        @seq = 2
        auth_promise = Queue.new
        @mon.synchronize { @pending[1] = auth_promise }
        send_raw(cmd: 0, seq: 1, opcode: 19, payload: {
          token:        @token,
          chatsCount:   chats_count,
          interactive:  true,
          chatsSync:    0,
          contactsSync: 0,
          presenceSync: -1,
          draftsSync:   0
        })

        Thread.new do
          auth_result = Timeout.timeout(timeout) { auth_promise.pop }
          if auth_result.is_a?(ErrorResponse)
            @last_connect_error = "#{auth_result.error}: #{auth_result.message}"
            ready.push(:error)
          else
            @profile   = auth_result["profile"]
            @raw_chats = auth_result["chats"]
            @connected = true
            @reconnect_attempts = 0
            ready.push(:ok)
          end
        rescue Timeout::Error
          @last_connect_error = "Таймаут авторизации"
          ready.push(:error)
        end
      end
    end

    def schedule_auto_reconnect
      @reconnect_attempts += 1

      if @reconnect_attempts > RECONNECT_MAX_ATTEMPTS
        @logger.error "[MaxWs] Превышено максимальное число попыток переподключения (#{RECONNECT_MAX_ATTEMPTS})"
        return
      end

      delay = [RECONNECT_BASE_DELAY * (2**(@reconnect_attempts - 1)), RECONNECT_MAX_DELAY].min
      @logger.info "[MaxWs] Переподключение через #{delay}с (попытка #{@reconnect_attempts}/#{RECONNECT_MAX_ATTEMPTS})..."

      EM.add_timer(delay) do
        next unless EM.reactor_running? && !@shutting_down

        @seq  = 0
        @seen = Set.new
        ready = Queue.new

        setup_ws_handlers(ready, @chats_count || 40, @connect_timeout || 15)

        Thread.new do
          result = Timeout.timeout(@connect_timeout || 15) { ready.pop }
          if result == :ok
            @logger.info "[MaxWs] Переподключение успешно (#{user_name}, id: #{user_id})"
          end
        rescue Timeout::Error
          @logger.error "[MaxWs] Таймаут переподключения"
          schedule_auto_reconnect if EM.reactor_running? && !@shutting_down
        end
      end
    end

    def flush_pending(reason)
      orphaned = @mon.synchronize { @pending.dup.tap { @pending.clear } }
      orphaned.each_value do |promise|
        promise.push(ErrorResponse.new("disconnected", reason)) rescue nil
      end
    end

    def on_message(raw)
      return if raw.nil? || raw.empty?

      data = JSON.parse(raw)
      key = "#{data['seq']}:#{data['cmd']}"

      return if @seen.include?(key)
      @seen.add(key)
      @seen = @seen.to_a.last(5000).to_set if @seen.size > 10_000

      case data["cmd"]
      when 0 then handle_push(data)
      when 1 then handle_response(data)
      when 3 then handle_error_response(data)
      end
    rescue JSON::ParserError => e
      @logger.error "[MaxWs] JSON parse error: #{e.message}"
    rescue => e
      @logger.error "[MaxWs] on_message error: #{e.class}: #{e.message}"
    end

    def handle_push(data)
      send_ack(data)
      @on_push&.call(data)
    end

    def handle_response(data)
      promise = @mon.synchronize { @pending.delete(data["seq"]) }
      promise&.push(data["payload"])
    end

    def handle_error_response(data)
      payload = data["payload"] || {}
      promise = @mon.synchronize { @pending.delete(data["seq"]) }
      if promise
        promise.push(ErrorResponse.new(payload["error"], payload["localizedMessage"]))
      else
        @logger.error "[MaxWs] Ошибка seq:#{data['seq']}: #{payload['error']} — #{payload['localizedMessage']}"
      end
    end

    def send_ack(push_data)
      ack_payload = nil
      if push_data["opcode"] == 128
        p = push_data["payload"]
        ack_payload = { chatId: p["chatId"], messageId: p.dig("message", "id") }
      end
      send_raw(cmd: 1, seq: push_data["seq"], opcode: push_data["opcode"], payload: ack_payload)
    end

    def send_raw(cmd:, seq:, opcode:, payload:)
      packet = { ver: PROTOCOL_VERSION, cmd: cmd, seq: seq, opcode: opcode, payload: payload }
      @logger.debug "[MaxWs] >>> opcode:#{opcode} seq:#{seq}"
      if EM.reactor_running?
        EM.next_tick { @ws&.send(packet.to_json) }
      end
    end

    def next_seq
      @mon.synchronize do
        s = @seq
        @seq += 1
        s
      end
    end

    def generate_cid
      -Time.now.to_f.*(1000).to_i
    end
  end

  class TimeoutError < StandardError; end

  class ApiError < StandardError
    attr_reader :code, :localized_message
    def initialize(code, message)
      @code = code
      @localized_message = message
      super("#{code}: #{message}")
    end
  end

  ErrorResponse = Struct.new(:error, :message)
end
