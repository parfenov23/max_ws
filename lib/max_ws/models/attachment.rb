# frozen_string_literal: true

module MaxWs
  module Models
    # Фабрика аттачментов — создаёт нужный подкласс по _type.
    module Attachment
      def self.build(client, raw, chat_id: nil)
        case raw["_type"]
        when "PHOTO"   then Photo.new(client, raw)
        when "VIDEO"   then Video.new(client, raw, chat_id: chat_id)
        when "SHARE"   then Share.new(client, raw)
        when "CONTROL" then Control.new(client, raw)
        else                Unknown.new(client, raw)
        end
      end

      # ── PHOTO ──
      class Photo < Base
        def type
          "PHOTO"
        end

        def photo_id
          raw["photoId"]
        end

        def width
          raw["width"]
        end

        def height
          raw["height"]
        end

        # URL картинки (через baseUrl + photoToken).
        def url
          raw["baseUrl"]
        end

        # Base64 превью (маленький webp для моментального отображения).
        def preview_data
          raw["previewData"]
        end

        def dimensions
          "#{width}x#{height}"
        end

        private

        def inspect_attrs
          "photo_id=#{photo_id} #{dimensions}"
        end
      end

      # ── VIDEO ──
      class Video < Base
        attr_reader :chat_id

        def initialize(client, raw, chat_id: nil)
          super(client, raw)
          @chat_id = chat_id
        end

        def type
          "VIDEO"
        end

        def video_id
          raw["videoId"]
        end

        def token
          raw["token"]
        end

        def width
          raw["width"]
        end

        def height
          raw["height"]
        end

        # Длительность в секундах.
        def duration
          (raw["duration"] || 0) / 1000.0
        end

        # Длительность в формате MM:SS.
        def duration_formatted
          total = duration.round
          "%d:%02d" % [total / 60, total % 60]
        end

        def thumbnail_url
          raw["thumbnail"]
        end

        def preview_data
          raw["previewData"]
        end

        def dimensions
          "#{width}x#{height}"
        end

        # Получить прямые ссылки на видео (opcode 83).
        #   video.urls # => { "MP4_720" => "https://...", "EXTERNAL" => "https://..." }
        def urls(message_id:)
          client.video_url(
            video_id:   video_id,
            token:      token,
            chat_id:    chat_id,
            message_id: message_id
          )
        end

        private

        def inspect_attrs
          "video_id=#{video_id} #{dimensions} duration=#{duration_formatted}"
        end
      end

      # ── SHARE (превью ссылки) ──
      class Share < Base
        def type
          "SHARE"
        end

        def title
          raw["title"]
        end

        def description
          raw["description"]
        end

        def url
          raw["url"]
        end

        def image
          img = raw["image"]
          img ? Photo.new(client, img) : nil
        end

        private

        def inspect_attrs
          "title=#{title&.slice(0, 40).inspect} url=#{url}"
        end
      end

      # ── CONTROL (системное событие) ──
      class Control < Base
        def type
          "CONTROL"
        end

        def event
          raw["event"]
        end

        def chat_type
          raw["chatType"]
        end

        def user_ids
          raw["userIds"] || []
        end

        private

        def inspect_attrs
          "event=#{event}"
        end
      end

      # ── Unknown ──
      class Unknown < Base
        def type
          raw["_type"] || "UNKNOWN"
        end

        private

        def inspect_attrs
          "type=#{type} keys=#{raw.keys.join(",")}"
        end
      end
    end
  end
end
