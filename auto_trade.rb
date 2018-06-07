require "net/http"
require "uri"
require "openssl"
require 'json'
require 'date'
require './bitfx'
require './macd'
require './stochastic'
require './GA'

# APIに必要なコード
# 1分間に約10回までに制限されることがある
INTERVAL_TIME = 60
product_code = "FX_BTC_JPY"
# key = API key
# secret = API Secret
key = ARGV[0]
secret = ARGV[1]
lower = 0.01
upper = 0.005
size = 0.02
w = 5

# BitflyerのAPIを叩くやつ
bit_api = BitFlyerAPI.new(key,secret)

# 初期データの作成
t = Time.now
sleep INTERVAL_TIME-t.sec
t = Time.now
timestamp = t.to_i.to_s
period = INTERVAL_TIME.to_s
uri = URI.parse("https://api.cryptowat.ch/markets/bitflyer/btcfxjpy/ohlc")
uri.query = "periods=" + period + "&before=" + timestamp
res = Net::HTTP.get(uri)
data = JSON.parse(res)['result'][period]
value = []
for d in data do
    value.push(d[4].to_f)
end

# GAを計算してパラメータを準最適化する
ga = GA.new(value,4,7,3,w)
params = ga.genetic_optimize
p params
# MACDを計算するやつ
macd = MACD.new(value,w,params[0..2])
# Stochasticを計算するやつ
stoc = Stochastic.new(value, params[3..4])

# status 1:買いポジション, 0:ノーポジ, -1:売りポジション
# sig 1:買い, 0:なし, -1:売り　のシグナル
# count: 損得の回数の合計
status = 0
macd_sig = 0
stoc_sig = 0
count = 0

begin
    sleep INTERVAL_TIME - Time.now.sec
    loop do
        # APIで情報を得る
        ticker = bit_api.ticker(product_code)
        ltp = ticker["ltp"]
        # オープンな注文のリスト
        orders = bit_api.childorder(product_code)
        # 建玉のリスト
        positions = bit_api.positions(product_code)

        # statusの更新
        if positions != [] then
            if positions[0]["side"] == "BUY" then
                status = 1
            elsif positions[0]["side"] == "SELL" then
                status = -1
            else
                status = 0
            end
        else
            status = 0
        end

        # データの更新
        ga.data_update(ltp)
        macd_sig = macd.update_signal(ltp)
        stoc_sig = stoc.update_signal(ltp)

        # puts "orders: #{orders}"
        # puts "positions: #{positions}"
        
        puts "status: #{status}"
        puts "macd: #{macd_sig}"
        puts "stochastic #{stoc_sig}"

        # statusの確認
        case status
        # 買いポジション
        when 1 then
            #得している
            if (positions[0]["price"].to_f / ltp - 1.0 > upper) && (macd_sig == -1)
                    bit_api.cancel_all_childorders(product_code) if orders != []
                    bit_api.send_order size, ltp, "SELL", "LIMIT"
                    count += 1
                    puts "action: SELL"
                    puts "pnl: #{positions[0]["pnl"].to_s}"
            # 損している
            elsif (1.0 - positions[0]["price"].to_f/ltp > lower) && (macd_sig == -1 || stoc_sig == -1)
                    bit_api.cancel_all_childorders(product_code) if orders != []
                    bit_api.send_order size, ltp, "SELL", "LIMIT"
                    count -= 1
                    puts "action: SELL"
                    puts "pnl: #{positions[0]["pnl"].to_s}"
            end
        # ノーポジション
        when 0 then
            #シグナルからエントリーのタイミングをみる
            # 両方1なら買いエントリー, -1なら売りエントリー
            if (macd_sig == 1 && stoc_sig == 1) then
                bit_api.cancel_all_childorders(product_code) if orders != []
                bit_api.send_order size, ltp, "BUY", "LIMIT"
                puts "action: BUY"
                puts "price: #{ltp.to_s}"
            elsif (macd_sig == -1 && stoc_sig == -1) then
                bit_api.cancel_all_childorders(product_code) if orders != []
                bit_api.send_order size, ltp, "SELL", "LIMIT"
                puts "action: SELL"
                puts "price: #{ltp.to_s}"
            end
        # 売りポジション
        when -1 then
            #得している
            if (positions[0]["price"].to_f / ltp - 1.0 > upper)  && (macd_sig == 1) then
                    bit_api.cancel_all_childorders(product_code) if orders != []
                    bit_api.send_order size, ltp, "BUY", "LIMIT"
                    count += 1
                    puts "action: BUY"
                    puts "pnl: #{positions[0]["pnl"].to_s}"
            # 損している
            elsif (1.0 - positions[0]["price"].to_f/ltp > lower) && (macd_sig == 1 || stoc_sig == 1) then
                    bit_api.cancel_all_childorders(product_code) if orders != []
                    bit_api.send_order size, ltp, "BUY", "LIMIT"
                    count -= 1
                    puts "action: BUY"
                    puts "pnl: #{positions[0]["pnl"].to_s}"
            end
        end
        
        # 損した回数が得した回数より3小さくなったらパラメータを変える
        if count < -3 then
            params = GA.genetic_optimize
            macd = MACD.new(value,params[0..2])
            stoc = Stochastic.new(value, params[3..4])
            count = 0
            puts "params reset"
        end
        # INTERVAL_TIMEで更新できるように待機
        sleep INTERVAL_TIME-Time.now.sec
    end
rescue => e
    p e.message
    p e.backtrace
    retry
end