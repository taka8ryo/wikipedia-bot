class LinebotController < ApplicationController
  require 'line/bot'
  require 'wikipedia'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)

    events.each { |event|
      if event.message['text'] != nil
        # LINEで送られてきた文書を取得
        word = event.message['text']
        # 日本語版Wikipediaを利用する
        Wikipedia.Configure {
          domain 'ja.wikipedia.org'
          path   'w/api.php'
        }
      end

      # wikipediaから情報取得
      page = Wikipedia.find(word)

      # 概要とURLを返す
      response = page.summary + "\n" + page.fullurl

      case event
      # メッセージが送信された場合
      when Line::Bot::Event::Message
        case event.type
        # メッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: response
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end
end