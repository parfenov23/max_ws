# frozen_string_literal: true

module MaxWs
  module Models
    # Коллекция чатов с удобными методами поиска.
    #
    #   client.chats.first
    #   client.chats.find(-68090704770355)
    #   client.chats.find_by(title: "Ruby")
    #   client.chats.channels
    #   client.chats.groups
    #   client.chats.search("Ruby")
    #
    class ChatCollection
      include Enumerable

      def initialize(client, raw_chats = [])
        @client = client
        @items  = (raw_chats || []).map { |c| Chat.new(client, c) }
      end

      def each(&block)
        @items.each(&block)
      end

      def size
        @items.size
      end
      alias_method :length, :size
      alias_method :count, :size

      def [](index)
        @items[index]
      end

      def first(n = nil)
        n ? @items.first(n) : @items.first
      end

      def last(n = nil)
        n ? @items.last(n) : @items.last
      end

      def empty?
        @items.empty?
      end

      # Найти чат по ID.
      def find(chat_id)
        @items.find { |c| c.id == chat_id } || fetch_remote(chat_id)
      end

      # Найти чат по атрибутам.
      def find_by(**attrs)
        @items.find do |chat|
          attrs.all? { |k, v| chat.raw[k.to_s] == v || chat.raw[camelize(k)] == v }
        end
      end

      # Все совпадения по атрибутам.
      def where(**attrs)
        @items.select do |chat|
          attrs.all? { |k, v| chat.raw[k.to_s] == v || chat.raw[camelize(k)] == v }
        end
      end

      def channels
        @items.select(&:channel?)
      end

      def groups
        @items.select(&:group?)
      end

      # Поиск по названию (подстрока, case-insensitive).
      def search(query)
        q = query.downcase
        @items.select { |c| c.title&.downcase&.include?(q) }
      end

      # Серверный поиск чатов.
      def remote_search(query, count: 20, type: "ALL")
        result = @client.search_chats(query: query, count: count, type: type)
        (result["result"] || []).map { |r| Chat.new(@client, r["chat"]) }
      end

      # Глобальный поиск.
      def global_search(query, count: 20)
        result = @client.global_search(query: query, count: count)
        (result["result"] || []).map { |r| Chat.new(@client, r["chat"]) }
      end

      def to_s
        "#<ChatCollection size=#{size}>"
      end

      def inspect
        "#<ChatCollection size=#{size} chats=#{@items.first(3).map(&:inspect)}#{size > 3 ? ' ...' : ''}>"
      end

      private

      def fetch_remote(chat_id)
        result = @client.chat_info(chat_ids: [chat_id])
        c = (result["chats"] || []).first
        c ? Chat.new(@client, c) : nil
      rescue
        nil
      end

      def camelize(sym)
        s = sym.to_s
        parts = s.split("_")
        parts[0] + parts[1..].map(&:capitalize).join
      end
    end
  end
end
