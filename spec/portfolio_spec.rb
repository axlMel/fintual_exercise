require_relative "../lib/portfolio"
 
RSpec.describe Portfolio do
  let(:portfolio) { Portfolio.new }
 
  describe "#total_value" do
    it "suma el valor de mercado de todas las posiciones más el cash" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(100))
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 5).current_price(200))
 
      # 10*100 + 5*200 + 0 cash = 2000
      expect(portfolio.total_value).to eq(2000)
    end
  end
 
  describe "#add_holding" do
    it "lanza un error si el símbolo ya existe, en vez de pisarlo en silencio" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(100))
 
      expect {
        portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 5).current_price(90))
      }.to raise_error(ArgumentError, /ya existe/)
    end
  end
 
  describe "#update_price" do
    it "permite registrar el precio de un símbolo que aún no está en holdings" do
      portfolio.update_price(:META, 200)
      portfolio.set_allocation(:META, 1.0)
 
      orders = portfolio.rebalance
 
      # No hay dinero (total_value = 0), así que no hay nada que comprar todavía
      expect(orders).to eq([])
    end
  end
 
  describe "#rebalance" do
    it "recomienda vender lo que sobra y comprar lo que falta según la allocation objetivo" do
      # Portfolio actual: 100% META (2000 en META, 0 en AAPL)
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(200))
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 0).current_price(100))
 
      # Objetivo: 60% AAPL, 40% META
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      orders = portfolio.rebalance
 
      # Total = 2000. Target AAPL = 1200 (12 acciones). Target META = 800 (4 acciones, vender 6)
      aapl_order = orders.find { |o| o[:symbol] == :AAPL }
      meta_order = orders.find { |o| o[:symbol] == :META }
 
      expect(aapl_order).to include(action: :buy, shares: 12)
      expect(meta_order).to include(action: :sell, shares: 6)
    end
 
    it "no genera órdenes si el portfolio ya está balanceado" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 6).current_price(100))
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 2).current_price(200))
      # Total = 1000. AAPL = 600 (60%), META = 400 (40%) -> ya calza
 
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      expect(portfolio.rebalance).to eq([])
    end
 
    it "vende por completo un holding que no tiene allocation objetivo" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(100))
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 5).current_price(200))
      # Total = 2000. Solo AAPL tiene allocation -> META debería venderse entera
      portfolio.set_allocation(:AAPL, 1.0)
 
      orders = portfolio.rebalance
      meta_order = orders.find { |o| o[:symbol] == :META }
 
      expect(meta_order).to include(action: :sell, shares: 5)
    end
 
    it "ignora diferencias menores a MIN_TRADE_VALUE (umbral realmente ejercido)" do
      # Total = 999.70. Con estos pesos, cada símbolo queda a ~$0.10 de su
      # target exacto (diferencia real y distinta de cero, pero bajo el
      # umbral de $1) -> no debería generar ninguna orden.
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(33.34))
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(66.63))
      portfolio.set_allocation(:AAPL, 0.3334)
      portfolio.set_allocation(:META, 0.6666)
 
      expect(portfolio.rebalance).to eq([])
    end
 
    it "redondea hacia abajo cuando la diferencia no alcanza para una acción completa" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(100))
      portfolio.update_price(:META, 100)
      portfolio.set_allocation(:AAPL, 0.85)
      portfolio.set_allocation(:META, 0.15)
      # Total = 1000. Target META = 150 -> 1.5 acciones -> debe redondear a 1
 
      meta_order = portfolio.rebalance.find { |o| o[:symbol] == :META }
 
      expect(meta_order).to include(action: :buy, shares: 1)
    end
 
    it "el rebalanceo NO se degrada al ejecutarse dos veces seguidas (cash estable)" do
      # 100 acciones a $1 = $100, objetivo 50% -> vende 50, quedan 50 en cash
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 100).current_price(1))
      portfolio.set_allocation(:AAPL, 0.5)
 
      portfolio.rebalance!
      first_orders = portfolio.rebalance
 
      # Sin el fix de cash explícito, esto generaría una segunda venta de ~25 acciones
      expect(first_orders).to eq([])
    end
 
    it "no genera compras si el portfolio no tiene ni holdings ni cash (nada que invertir)" do
      # Nota: como los pesos objetivo suman <= 100% y total_value = holdings + cash,
      # rebalance! nunca puede dejar el cash en negativo en una sola ejecución: el
      # dinero que gasta en compras es, como máximo, el mismo total_value del que
      # provienen los targets. Este test documenta el caso borde "sin plata todavía".
      portfolio.update_price(:AAPL, 100)
      portfolio.set_allocation(:AAPL, 1.0)
 
      expect(portfolio.rebalance).to eq([])
    end
 
    it "estimated_value corresponde exactamente a shares * price (sin comisiones ni spread)" do
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(200))
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 0).current_price(100))
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      aapl_order = portfolio.rebalance.find { |o| o[:symbol] == :AAPL }
 
      expect(aapl_order[:estimated_value]).to eq(aapl_order[:shares] * 100)
    end
  end
 
  describe "#rebalance!" do
    it "ejecuta las órdenes y deja cantidades y cash actualizados" do
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(200))
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 0).current_price(100))
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      portfolio.rebalance!
 
      expect(portfolio.instance_variable_get(:@holdings)[:AAPL].quantity).to eq(12)
      expect(portfolio.instance_variable_get(:@holdings)[:META].quantity).to eq(4)
      # Compró 1200 (AAPL) y vendió 1200 (META) -> cash neto no cambia
      expect(portfolio.cash).to eq(0)
    end
  end
 
  describe "#set_allocation" do
    it "acepta que la suma llegue exactamente a 100%" do
      portfolio.set_allocation(:AAPL, 0.6)
      expect { portfolio.set_allocation(:META, 0.4) }.not_to raise_error
    end
 
    it "lanza un error si la suma de allocations supera 100%" do
      portfolio.set_allocation(:AAPL, 0.6)
      expect { portfolio.set_allocation(:META, 0.5) }.to raise_error(ArgumentError, /100%/)
    end
  end
 
  describe "Stock" do
    it "rechaza un precio <= 0" do
      stock = Stock.new(symbol: :AAPL, quantity: 1)
      expect { stock.current_price(0) }.to raise_error(ArgumentError, /price/)
      expect { stock.current_price(-10) }.to raise_error(ArgumentError, /price/)
    end
 
    it "rechaza una cantidad negativa o no entera al crear el Stock" do
      expect { Stock.new(symbol: :AAPL, quantity: -1) }.to raise_error(ArgumentError, /quantity/)
      expect { Stock.new(symbol: :AAPL, quantity: 1.5) }.to raise_error(ArgumentError, /quantity/)
    end
 
    it "no permite que adjust_quantity deje la posición en negativo" do
      stock = Stock.new(symbol: :AAPL, quantity: 5)
      expect { stock.adjust_quantity(-10) }.to raise_error(ArgumentError, /vender más acciones/)
    end
  end
end