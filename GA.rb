class GA

    def initialize(data, iter, candidate, rank,w)
        @data = data
        @min = 2 # パラメータの値のmin
        @max = 30 # パラメータの値のmax
        @param_num = 5 # パラメータの数
        @candidate_length = candidate # 生成する候補の数
        @rank_length = rank # 上位何個の候補をとっておくか
        @iter = iter # 繰り返し回数
        @w = w
    end

    # 制約を満たしていない部分の変更
    def change(vec, prob=0.5)
        if vec[0] == @min
            vec[1] += 2
        elsif vec[0] == @max
            vec[0] -= 2
        elsif rand(0..1.0) < prob
            vec[0] -= 1
        else
            vec[1] += 1
        end
    end

    # 突然変異
    def mutation(vec, prob=0.5)
        i = rand(0..@param_num-1)
        case vec[i]
        when @min
            vec[i] += 1
        when @max
            vec[i] -= 1
        else
            if rand(0..1.0) < prob
                vec[i] += 1
            else
                vec[i] -= 1
            end
        end
        change(vec) if vec[0] == vec[1]
        return vec
    end

    # 制約を満たしているかのチェック
    def check(vec)
        if vec[0] > vec[1]
            vec[0], vec[1] = vec[1], vec[0]
        elsif vec[0] == vec[1]
            change(vec)
        end
    end

    # 交叉
    def crossover(vec1, vec2)
        i = rand(1..@param_num-2)
        vec1[i..-1], vec2[i..-1] = vec2[i..-1], vec1[i..-1]
        check(vec1)
        check(vec2)
        return vec1, vec2
    end

    # ランダムな初期値の生成
    def generate_list(list_length)
        list = []
        list_length.times do
            candidate = []
            @param_num.times do
                candidate.push(rand(@min..@max))
            end
            check(candidate)
            list.push(candidate)
        end
        return list
    end

    # GAの実行
    def genetic_optimize(prob=0.4)
        list = generate_list(@candidate_length)
        list.sort_by! {|cand| -costf(cand)}
        list = list[0..@rank_length-1]
        list = list + generate_list(((@candidate_length-@rank_length)*0.1).to_i)
        @iter.times do
            while list.length < @candidate_length
                if rand(0..1.0) < prob
                    list.push(mutation(list[rand(0..@rank_length-1)].dup))
                else
                    i1 = rand(0..@rank_length-1)
                    i2 = rand(0..@rank_length-1)
                    while i1 == i2
                    i2 = rand(0..@rank_length-1)
                    end
                    candidate1, candidate2 = crossover(list[i1].dup, list[i2].dup)
                    list.push(candidate1)
                    list.push(candidate2)
                end
            end

            list.sort_by! {|cand| -costf(cand)}
            list = list[0..@rank_length-1]
        end
        return list[0]
    end

    # ストキャスティクスのシグナル計算
    def stoc_trade_sig(params)
        p_D = []
        n,m = params

        p_D=Array.new(n+m-2,nil)
        for i in n+m-2..@data.length-1
            window = @data[i-n-m+2..i]
            u_sum = 0.0
            l_sum = 0.0
            window.each_cons(n) do |arr|
              u_sum += arr.last - arr.min
              l_sum += arr.max - arr.min
            end
            p_D.push((u_sum/l_sum)*100)
        end
        
        trade = Array.new(n+m,nil)
        for i in n+m .. p_D.length-1
            if p_D[i] > 80 then
                trade.push(-1)
            elsif p_D[i] < 20 then
                trade.push(1)
            else
                trade.push(0)
            end
        end
        trade
    end

    # MACDのシグナル計算
    def macd_trade_sig(params,w)      
        macd = []
        signal = []
        n_s, n_l, n_sig = params

        ema_s = Array.new(n_s-1,nil)
        ema_s.push(@data[0..n_s-1].inject(:+) / n_s.to_f)
        for i in n_s..@data.length-1 do
            ema_s.push(ema_s[i-1]+(2.0/(n_s+1).to_f)*(@data[i]-ema_s[i-1]))
        end

        ema_l = Array.new(n_l-1,nil)
        ema_l.push(@data[0..n_l-1].inject(:+)/n_l.to_f)
        for i in n_l..@data.length-1 do
            ema_l.push(ema_l[i-1]+(2.0/(n_l+1).to_f)*(@data[i]-ema_l[i-1]))
        end

        macd = ema_s.zip(ema_l).map{|a,b| 
            if b.nil?
                nil
            else
                a-b
            end
        }
        signal = Array.new(n_l+n_sig-2,nil)
        macd[n_l-1..macd.length-1].each_cons(n_sig) do |arr|
            signal.push(arr.inject(:+)/n_sig.to_f)
        end
        
        trade = Array.new(n_l+n_sig,nil)
        for i in n_l+n_sig .. macd.length-1
            if (macd[i-1] - signal[i-1]) >= 0
                if (macd[i] - signal[i]) < 0
                    trade.push(-1)
                else
                    trade.push(0)
                end
            # ゴールデンクロス
            elsif (macd[i-1] - signal[i-1]) < 0
                if (macd[i] - signal[i]) >= 0
                    trade.push(1)
                else
                    trade.push(0)
                end
            # 何もない
            else
                trade.push(0)
            end
        end
        w_trade = trade[0..n_l+n_sig+w-2].dup
        trade[n_l+n_sig+w-1..trade.length-1].each_cons(w){|k|
            w_trade.push(k.inject(:+))
        }
        w_trade
    end
          
    # パラメーターに対するコスト関数
    def costf(params)
        positions = []
        status = 0
        macd_sig = 0
        stoc_sig = 0
        sum = 0
        lower = 0.01
        upper = 0.005
        # MACDを計算するやつ
        macd = macd_trade_sig(params[0..2],@w)
        # Stochasticを計算するやつ
        stoc = stoc_trade_sig(params[3..4])
        #データに対して売買結果を計算
        for i in [params[1..2].inject(:+),params[3..4].inject(:+)].max .. @data.length-1 do
            ltp = @data[i]
            # signalの更新
            macd_sig = macd[i]
            stoc_sig = stoc[i]
          
            # statusの確認
            case status
            # 買いポジション
            when 1 then
                #売るタイミング
                if (positions[0] / ltp - 1.0 > upper && macd_sig == -1) || 
                    (1.0 - positions[0] / ltp > lower && (macd_sig == -1 || stoc_sig == -1)) then
                    sum += positions[0] - ltp
                    positions = []
                    status = 0
                end
            # ノーポジション
            when 0 then
                #シグナルからエントリーのタイミングをみる
                # 両方1なら買いエントリー, -1なら売りエントリー
                if (macd_sig == 1 && stoc_sig == 1) then
                    positions.push(ltp)
                    status = 1
                elsif (macd_sig == -1 && stoc_sig == -1) then
                    positions.push(ltp)
                    status = 0
                end
            # 売りポジション
            when -1 then
                #買うタイミング
                if (positions[0] / ltp -1 > upper  && macd_sig == 1) ||
                    (positions[0]/ltp - 1.0 > lower && (macd_sig == 1 || stoc_sig == 1)) then
                    sum += positions[0] - ltp
                    positions = []
                    status = -1
                end
            end
        end
        sum/100
    end

    def data_update(d)
        @data.shift
        @data.push(d)
    end
end