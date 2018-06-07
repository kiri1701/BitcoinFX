class Stochastic
    attr_accessor :p_D
    
    def initialize(value,params)
        @value = value
        @p_D = []
        @n,@m = params

        @p_D=Array.new(@n+@m-3,nil)
        for i in @n+@m-2..@value.length-1
            window = value[i-@n-@m+2..i]
            u_sum = 0.0
            l_sum = 0.0
            window.each_cons(@n) do |arr|
              u_sum += arr.last - arr.min
              l_sum += arr.max - arr.min
            end
            @p_D.push((u_sum/l_sum)*100)
        end
    end

    def update_signal(d)
        # オリジナルデータの最初を削除して末尾に新しいデータを追加
        @value.shift
        @value.push(d)

        # p_Dの先頭要素の削除
        @p_D.shift

        # 新しい値
        window = @value.last(@n+@m-1)
        u_sum = 0.0
        l_sum = 0.0
        window.each_cons(@n) do |arr|
            u_sum += arr.last - arr.min
            l_sum += arr.max - arr.min
        end
        p_D_new = u_sum/l_sum * 100
        
        # 新しい要素の追加
        @p_D.push(p_D_new)

        # シグナルの確認
        # 買われすぎ
        if p_D_new >= 80
            return -1
        # 売られすぎ
        elsif p_D_new <= 20
            return 1
        # 何もない
        else
            return 0
        end
    end
end