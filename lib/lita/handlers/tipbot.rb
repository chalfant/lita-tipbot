require 'hipchat-api'
require 'digest'
require 'httparty'
require 'json'

module Lita
  module Handlers
    class TipbotApi
      attr_accessor :base_url, :auth_token, :log

      def initialize(params)
        @base_url   = params[:url]
        @auth_token = params[:auth_token]
        @log        = params[:log]
      end

      def rest_get(url)
        headers = {
          'Authorization' => auth_token,
          'Accept' => 'application/json'
        }
        HTTParty.get(url, headers: headers)
      end

      def rest_post(url, payload)
        headers = {
          'Authorization' => auth_token,
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
        HTTParty.post(url, headers: headers, body: payload)
      end

      def register(hash)
        url = "#{base_url}/wallet/#{hash}/register"
        resp = rest_get url
        resp.body
      end

      def address(hash)
        url = "#{base_url}/wallet/#{hash}"
        resp = rest_get url
        data = JSON.parse resp.body
        data['address']
      end

      def balance(hash)
        url = "#{base_url}/wallet/#{hash}/balance"
        resp = rest_get url
        data = JSON.parse resp.body
        data['balance'] # TODO: check for NaN
      end

      def history(hash)
        url = "#{base_url}/wallet/#{hash}/history"
        resp = rest_get url
        resp.body
      end

      def tip(src_hash, dest_hash, amount)
        url = "#{base_url}/wallet/tip"

        payload = {
          from:   src_hash,
          to:     dest_hash,
          amount: amount
        }.to_json

        resp = rest_post url, payload
        resp.body
      end

      def withdraw(src_hash, dest_address)
        url = "#{base_url}/wallet/#{src_hash}/withdraw/#{dest_address}"
        resp = rest_get url
        data = JSON.parse(resp.body)
        data['message']
      end
    end

    class Tipbot < Handler
      # TODO: store user's hash in redis for later lookup?

      config :hipchat_api_token
      config :tipbot_auth_token
      config :tipbot_url
      config :emails_to_exclude

      route(/^tipbot register/i, :register, help: {
        "tipbot register" => "register to use tipbot (only needed if you have never been tipped)"
      })

      route(/^tipbot address/i, :address, help: {
        "tipbot address" => "show the address you can send coins to for tipping"
      })

      route(/^tipbot balance/i, :balance, help: {
        "tipbot balance" => "show your current balance"
      })

      route(/^tipbot history/i, :history, help: {
        "tipbot history" => "show transaction history"
      })

      route(/^tipbot tip (.\S*) (.\d*)/i, :tip, help: {
        "tipbot tip @mentionName amount" => "tip someone coins e.g. tipbot tip @ExampleUser 10"
      })

      route(/^tipbot withdraw (.*)/i, :withdraw, help: {
        "tipbot withdraw personalAddress" => "withdraw your tips into your personal wallet"
      })

      route(/^tipbot make it rain/i, :make_it_rain, help: {
        "tipbot make it rain" => "tip every active participant in the room"
      })

      route(/^tipbot make it wayne/i, :make_it_wayne)
      route(/^tipbot make it blaine/i, :make_it_blaine)
      route(/^tipbot make it crane/i, :make_it_crane)
      route(/^tipbot make it reign/i, :make_it_reign)

      def register(response)
        hash = user_hash(response.user.mention_name)

        log.info "Registering #{hash}"
        body = tipbot_api.register hash

        log.debug "register response: #{body}"
        # TODO: check for errors
        response.reply "You have been registered."
      end

      def address(response)
        hash = user_hash(response.user.mention_name)
        response.reply tipbot_api.address(hash)
      end

      def balance(response)
        hash = user_hash(response.user.mention_name)
        response.reply tipbot_api.balance(hash).to_s
      end

      def history(response)
        hash = user_hash(response.user.mention_name)
        response.reply tipbot_api.history(hash)
      end

      def tip(response)
        recipient, amount = response.match_data[1..2]
        from_hash = user_hash(response.user.mention_name)
        to_hash   = user_hash(recipient.slice(1..-1))
        tipbot_api.tip(from_hash, to_hash, amount)
        response.reply "Tip sent! Such kind shibe."
      end

      def withdraw(response)
        src_hash     = user_hash(response.user.mention_name)
        dest_address = response.match_data[1]

        resp = tipbot_api.withdraw(src_hash, dest_address)
        response.reply resp
      end

      def make_it_rain(response)
        images = [
          "http://disinfo.s3.amazonaws.com/wp-content/uploads/2013/12/make-it-rain-1jk6.jpg",
          "http://voice.instructure.com/Portals/166399/images/scrooge-mcduck-make-it-rain.jpeg",
          "http://cdn01.dailycaller.com/wp-content/uploads/2012/10/Big-Bird-Makin-It-Rain-e1349457102996.jpeg",
          "http://i.imgur.com/jSaI0pv.jpg",
          "http://i.imgur.com/0Rz84wK.gif"
        ]

        response.reply([
          "#{response.user.name} is makin' it rain!",
          images.sample
        ])

        src_hash = user_hash(response.user.mention_name)
        room_jid = response.message.source.room
        users    = active_room_members room_jid

        users.shuffle.each do |user|
          # skip tipper
          next if user['mention_name'] == response.user.mention_name

          log.info "tipping #{user['email']}"

          dest_hash = hash_email user['email']
          log.debug "SRC  HASH: #{src_hash}"
          log.debug "DEST HASH: #{dest_hash}"
          log.debug "NAME:      #{user['name']}"

          response.reply "A coin for #{user['name']}!"
          tipbot_api.tip src_hash, dest_hash, 1
        end
      end

      # haphazardly give some percentage of people in the room 1-50 doge
      def make_it_wayne(response)
        images = [
          "http://a4.files.saymedia-content.com/image/upload/c_fill,g_face,h_300,q_80,w_300/MTE5NTU2MzE2NDIxMTk1Mjc1.jpg",
          "http://www.whale.to/c/9_23_09_wayne_newton_kabik-14-570.jpg",
          "http://www.aceshowbiz.com/images/wennpic/wayne-newton-2013-american-music-awards-01.jpg",
          "http://thestarsurgery.com/wp-content/uploads/2013/06/Wayne-Newton.jpg",
          "http://www.mtv.com/crop-images/2013/08/27/WayneNewton_cr_EthanMiller_2009.jpg"
        ]

        response.reply([
          "Watch out! #{response.user.name} is makin' it Wayne!",
          images.sample
        ])

        src_hash = user_hash(response.user.mention_name)
        room_jid = response.message.source.room
        users    = active_room_members room_jid

        # wayne's generosity typically runs out before everyone gets a tip
        max_recipients = Random.rand(1..users.size)

        max_recipients.times do

          # wayne has had a few too many and forgets who he has already tipped
          user = users.sample

          log.info "tipping #{user['email']}"

          dest_hash = hash_email user['email']
          log.debug "SRC  HASH: #{src_hash}"
          log.debug "DEST HASH: #{dest_hash}"
          log.debug "NAME:      #{user['name']}"

          amount = Random.rand(1..50)
          response.reply "#{amount} for #{user['name']}!"

          tipbot_api.tip src_hash, dest_hash, amount
        end
      end

      # give a random person a random amount of 1-200 doge
      def make_it_blaine(response)
        images = [
          "http://cdn.images.express.co.uk/img/dynamic/79/590x/444280_1.jpg",
          "http://currentbuzz.my/Documents/Article/508176/TV%20street%20magician%20David%20Blaine_i2_cdnds_net.jpg",
          "http://i.dailymail.co.uk/i/pix/2012/10/08/article-2214386-15633B31000005DC-349_306x423.jpg",
          "http://i.telegraph.co.uk/multimedia/archive/01394/blaine_1394717c.jpg",
          "http://i.ytimg.com/vi/fqJ0GaVU344/hqdefault.jpg"
        ]

        response.reply([
          "What's that behind your ear? #{response.user.name} is makin' it Blaine!",
          images.sample
        ])

        src_hash = user_hash(response.user.mention_name)
        room_jid = response.message.source.room
        users    = active_room_members room_jid

        user = users.sample
        amount = Random.rand(1..200)

        log.info "tipping #{user['email']}"

        dest_hash = hash_email user['email']
        log.debug "SRC  HASH: #{src_hash}"
        log.debug "DEST HASH: #{dest_hash}"
        log.debug "NAME:      #{user['name']}"

        response.reply "Someone just received #{amount}!"
        tipbot_api.tip src_hash, dest_hash, amount
      end

      # give a random person a random amount of 1-32 doge
      def make_it_crane(response)
        images = [
          "http://upload.wikimedia.org/wikipedia/en/6/68/Frasier_Crane_Shrink_Wrap_radio_station_KACL.jpg",
          "http://0.media.dorkly.cvcdn.com/47/63/8525949c344ca18f060a73d22e4cafde-dr-frasier-crane.jpg",
          "http://rushthefence.com/content/images/2014/Mar/Morgan_Bateson.jpg",
          "https://38.media.tumblr.com/97d26f1f5c3979b5d0ca26a49490c946/tumblr_mk8hl1u5va1s2n8qho1_500.png",
          "http://snakkle.wpengine.netdna-cdn.com/wp-content/uploads/2012/09/kelsey-grammer-cheers-tv-1985-photo-GC.jpg"
        ]

        response.reply([
          "#{response.user.name} is makin' it Frasier Crane!",
          images.sample
        ])

        src_hash = user_hash(response.user.mention_name)
        room_jid = response.message.source.room
        users    = active_room_members room_jid

        user = users.sample
        amount = Random.rand(1..32)

        log.info "tipping #{user['email']}"

        dest_hash = hash_email user['email']
        log.debug "SRC  HASH: #{src_hash}"
        log.debug "DEST HASH: #{dest_hash}"
        log.debug "NAME:      #{user['name']}"

        response.reply "#{user['name']} just received #{amount}!"
        tipbot_api.tip src_hash, dest_hash, amount
      end

      # give a random person a random amount of 1-32 doge
      def make_it_reign(response)
        images = [
          "http://i.imgur.com/WOzIWAs.gif",
          "http://i.imgur.com/QlhuS09.gif",
          "http://i.imgur.com/8RC90ul.gif"
        ]

        response.reply([
          "#{response.user.name} is makin' it Reign!",
          images.sample
        ])

        src_hash = user_hash(response.user.mention_name)
        room_jid = response.message.source.room
        users    = active_room_members room_jid

        user = users.sample
        amount = Random.rand(1..32)

        log.info "tipping #{user['email']}"

        dest_hash = hash_email user['email']
        log.debug "SRC  HASH: #{src_hash}"
        log.debug "DEST HASH: #{dest_hash}"
        log.debug "NAME:      #{user['name']}"

        response.reply "#{user['name']} just received #{amount}!"
        tipbot_api.tip src_hash, dest_hash, amount
      end

      attr_writer :hipchat_api, :tipbot_api

      def hipchat_api
        if @hipchat_api.nil?
          @hipchat_api = HipChat::API.new(config.hipchat_api_token)
        end
        @hipchat_api
      end

      def tipbot_api
        if @tipbot_api.nil?
          params = {
            url: config.tipbot_url,
            auth_token: config.tipbot_auth_token,
            log: log
          }
          @tipbot_api = TipbotApi.new(params)
        end
        @tipbot_api
      end

      def user_hash(mention_name)
        user_data = hipchat_api.users_list
        user = user_data['users'].select {|u| u['mention_name'] == mention_name}.first
        hash_email user['email']
      end

      def hash_email(email)
        Digest::MD5.hexdigest email
      end

      # TODO: many of these methods could be useful to other handlers

      # return a list of hipchat api v1 user hashes
      # exclude any user with email in config.emails_to_exclude
      # exclude any non-active user
      # TODO: dont make an api call for every participant
      # instead: make one call for all users, then check
      # to see if each is an active participant
      def active_room_members(room_jid)
        log.debug "looking up room jid: #{room_jid}"
        data = room_data(room_jid)
        log.debug "room_data: #{data.inspect}"
        results = []
        data['participants'].each do |p|
          user = hipchat_api.users_show(p['user_id'])
          next if user['user']['status'] != 'available'
          next if exclude_user? user['user']
          results << user['user']
        end
        results
      end

      def exclude_user?(user_hash)
        config.emails_to_exclude.include?(user_hash['email'])
      end

      def room_data(room_jid)
        room_id = room_id_from_jid room_jid
        data = hipchat_api.rooms_show room_id
        log.debug "room #{room_id} data: #{data.inspect}"
        data['room']
      end

      def room_id_from_jid(room_jid)
        data = hipchat_api.rooms_list
        log.debug "all room data: #{data.inspect}"
        room = data['rooms'].select {|r| r['xmpp_jid'] == room_jid}.first
        room.nil? ? nil : room['room_id']
      end

    end

    Lita.register_handler(Tipbot)
  end
end
