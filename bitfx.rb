class BitFlyerAPI
  require "net/http"
  require "uri"
  require "openssl"
  require 'json'

  # product_code = "FX_BTC_JPY"
  def initialize key, secret
    @key = key
    @secret = secret
  end

  def call_api(key, secret, method, uri, body="")
    # timestamp = string型の現在日時のUNIX時間
    timestamp = Time.now.to_i.to_s

    text = timestamp + method + uri.request_uri + body
    sign = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, text)

    options = if method == "GET"
      Net::HTTP::Get.new(uri.request_uri, initheader = {
        "ACCESS-KEY" => key,
        "ACCESS-TIMESTAMP" => timestamp,
        "ACCESS-SIGN" => sign,
      });
    else
      Net::HTTP::Post.new(uri.request_uri, initheader = {
        "ACCESS-KEY" => key,
        "ACCESS-TIMESTAMP" => timestamp,
        "ACCESS-SIGN" => sign,
        "Content-Type" => "application/json"
      });
    end
    options.body = body if body != ""

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    response = https.request(options)
    JSON.parse(response.body) if response.body != ""
  end

  # 板情報
  def board(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/getboard"
    uri.query = "product_code=" + product_code

    call_api(@key,@secret, "GET", uri)
  end

  # Ticker
  def ticker(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/getticker"
    uri.query = "product_code=" + product_code

    call_api(@key, @secret, "GET", uri)
  end

  # 建玉の状態を取得
  def positions(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/me/getpositions"
    uri.query = "product_code=" + product_code

    call_api(@key, @secret, "GET", uri)
  end

  # 約定履歴を取得
  def executions(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = '/v1/executions'
    uri.query = 'product_code=' + product_code
    call_api(@key, @secret, "GET", uri)   
  end

  # 証拠金を取得
  def collatera
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/me/getcollateral"
  
    call_api(@key, @secret, "GET", uri)
  end

  # オープンな注文一覧
  def childorder(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = '/v1/me/getchildorders'
    uri.query = 'product_code=' + product_code + '&child_order_state=ACTIVE'
    call_api(@key, @secret, "GET", uri) 
  end

  # 注文をキャンセル
  def cansel_order(product_code,id)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = '/v1/me/cancelchildorder'
    params = {
      "product_code" => product_code,
      "child_order_id" => id
    }
    body = JSON.generate(params)
    call_api(@key, @secret, "POST", uri, body)
  end

  # 全ての注文をキャンセル
  def cancel_all_orders(product_code)
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = '/v1/me/cancelallchildorders'
    params = {
      "product_code"=> product_code
    }
    body = JSON.generate(params)

    call_api(@key, @secret, "POST", uri, body)
  end

  # 新規注文 type= "LIMIT" or "MARKET"
  def send_order size, price, signal, type
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/me/sendchildorder"
    params = {
      "product_code"=> "FX_BTC_JPY",
      "child_order_type"=> type,
      "side"=> signal,
      "price" => price,
      "size" => size,
      "minute_to_expire"=> 10000,
      "time_in_force"=> "GTC"
    }
     
    body = JSON.generate(params)
    call_api(@key, @secret, "POST", uri, body)
  end

  # 特殊注文を出す
  def send_parent_order size, buy_price, sell_price, trigger_price
    uri = URI.parse("https://api.bitflyer.jp")
    uri.path = "/v1/me/sendparentorder"
    params = {
      "order_method"=>"IFD", 
      "minute_to_expire"=>10000, 
      "time_in_force"=>"GTC", 
      "parameters"=>[
        {
          "product_code"=>"FX_BTC_JPY", 
          "condition_type"=>"LIMIT", 
          "side"=>"BUY", 
          "price"=>buy_price, 
          "size"=>size
        }, 
        {
          "product_code"=>"FX_BTC_JPY", 
          "condition_type"=>"STOP_LIMIT", 
          "side"=>"SELL", 
          "price"=>sell_price, 
          "trigger_price"=>trigger_price, 
          "size"=>size
        }
      ]
    }

    body = JSON.generate(params)
    call_api(@key, @secret, "POST", uri, body)
  end
end