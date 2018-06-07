class MACD
    attr_accessor :macd,:signal
    def initialize(value,w,params)
        @value = value
        @macd = []
        @signal = []
        @n_s,@n_l,@n_sig = params
        @w = w

        @ema_s = Array.new(@n_s-1,nil)
        @ema_s.push(value[0..@n_s-1].inject(:+) / @n_s.to_f)
        for i in @n_s..value.length-1 do
            @ema_s.push(@ema_s[i-1]+(2.0/(@n_s+1).to_f)*(value[i]-@ema_s[i-1]))
        end

        @ema_l = Array.new(@n_l-1,nil)
        @ema_l.push(value[0..@n_l-1].inject(:+)/@n_l.to_f)
        for i in @n_l..value.length-1 do
            @ema_l.push(@ema_l[i-1]+(2.0/(@n_l+1).to_f)*(value[i]-@ema_l[i-1]))
        end

        @macd = @ema_s.zip(@ema_l).map{|a,b| 
            if b.nil?
                nil
            else
                a-b
            end
        }
        @signal = Array.new(@n_l+@n_sig-1,nil)
        @macd[(@n_l+@n_sig)..@macd.length-1].each_cons(@n_sig) do |arr|
            @signal.push(arr.inject(:+)/@n_sig.to_f)
        end
    end

    def update_signal(d)
        # オリジナルデータの最初を削除して末尾に新しいデータを追加
        @value.shift
        @value.push(d)

        # macd,ema,signalの先頭要素の削除
        @macd.shift
        @signal.shift
        @ema_s.shift
        @ema_l.shift

        # macd,signalの末尾の取得
        macd_old = @macd.last
        signal_old = @signal.last

        # 新しい値
        tmp_s = @value.last+(2.0/(@n_s+1).to_f)*(@value.last-@ema_s.last)
        tmp_l = @value.last+(2.0/(@n_l+1).to_f)*(@value.last-@ema_l.last)
        macd_new = tmp_s - tmp_l
        signal_new = (@macd.last(@n_sig-1).inject(:+)+macd_new)/@n_sig.to_f

        # 新しい要素の追加
        @ema_s.push(tmp_s)
        @ema_l.push(tmp_l)
        @macd.push(macd_new)
        @signal.push(signal_new)

        window = @macd.last(@w+1).zip(@signal.last(@w+1)).map{ |i,j|
            i-j
        }
        trade_sig = []
        window.each_cons(2){ |i,j|
            if i * j >= 0
                trade_sig.push(0)
            else
                if i > 0
                    trade_sig.push(-1)
                else
                    trade_sig.push(1)
                end
            end
        }
        return trade_sig.inject(:+)
    end
end