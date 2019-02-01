# encoding: utf-8

require 'open-uri'
require 'net/http'
require 'net/https'
require 'json'

class Watcher

  def initialize(check_url)
    @check_url = check_url
    @logger = Logger.new(STDOUT)
    @messages = {
        content_error: 'Söker fel sida!',
        found_accommodation: 'Bostäder har publicerats!',
        notification_sent: 'Notis framgångsrikt skickad!'
    }

    start_check
  end

  def start_check
    last_length = 0

    loop do
      begin
        res = open(@check_url, 'User-Agent' => 'bostad-direkt-bot').read

        res_length = res.length
        step_size = (last_length - res_length).abs

        unless res.include?('Alla korridorrum är reserverade till studenter som för')
          @logger.warning(@messages[:content_error])
          send_push(@messages[:content_error])
          break
        end

        if step_size > 10
          last_length = res_length
          @logger.info(@messages[:found_accommodation])
          send_push(@messages[:found_accommodation])
        end
      rescue OpenURI::HTTPError => e
        @logger.error(e.message)
      end

      sleep 30
    end
  end

  private

  def send_push(title)
    uri = URI('https://api.pushbullet.com/v2/pushes')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    req = Net::HTTP::Post.new(uri)
    req.add_field 'Content-Type', 'application/json; charset=utf-8'
    req.add_field 'Access-Token', 'haha-no-stop'
    req.body = JSON.dump(type: 'link', url: @check_url, title: title)

    begin
      http.request(req)
      @logger.info(@messages[:notification_sent])
    rescue Net::HTTPError => e
      @logger.error(e.message)
    end
  end

end

Watcher.new('https://www.studentbostader.se/sv/sok-bostad/lediga-bostader?egenskaper=SNABB')
