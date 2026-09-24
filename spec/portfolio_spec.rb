# frozen_string_literal: true
 
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
      portfolio.update_price(:AAPL, 100)
      portfolio.set_allocation(:AAPL, 1.0)
 
      expect(portfolio.rebalance).to eq([])
    end
 
    it "puede dejar cash negativo cuando una venta redondea a 0 acciones pero una compra sí ejecuta" do
      # AAPL es el único holding ($100, 1 acción). El rebalanceo ideal pide
      # vender $40 de AAPL para llegar a 60%, pero $40 < 1 acción a $100 ->
      # esa venta se redondea a 0 y NO se ejecuta. META (nueva, via
      # update_price) sí alcanza para comprar 2 acciones ($40 a $20 c/u).
      # Resultado: se gastan $40 que nunca se recuperaron de la venta.
      # Esto es intencional y está fuera de alcance (SPEC.md no valida
      # fondos suficientes), pero lo dejo documentado explícitamente,
      # no asumido como imposible.
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 1).current_price(100))
      portfolio.update_price(:META, 20)
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      orders = portfolio.rebalance
      expect(orders.map { |o| o[:symbol] }).to eq([:META]) # AAPL no genera orden
 
      portfolio.rebalance!
 
      expect(portfolio.cash).to eq(-40)
    end
 
    it "estimated_value corresponde exactamente a shares * price (sin comisiones ni spread)" do
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(200))
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 0).current_price(100))
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      aapl_order = portfolio.rebalance.find { |o| o[:symbol] == :AAPL }
 
      expect(aapl_order[:estimated_value]).to eq(aapl_order[:shares] * 100)
    end
 
    it "vende un holding por completo en una sola llamada, incluso con ruido de punto flotante" do
      # 15 * 1.10 = 16.5; 16.5 / 1.10 da 14.999999999999998 en Float puro,
      # lo que antes truncaba a 14 acciones vendidas en vez de 15.
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 15).current_price(1.10))
      # Sin allocation -> objetivo 0%, se debe vender TODO en una sola pasada
 
      order = portfolio.rebalance.find { |o| o[:symbol] == :AAPL }
 
      expect(order).to include(action: :sell, shares: 15)
    end
 
    it "calcula la cantidad exacta de acciones a comprar a pesar de ruido de punto flotante" do
      # Total = $4.00 (AAPL $0.10 x 40, sin allocation -> se liquida).
      # Target META (30%) = $1.20; 1.20 / 0.10 da 11.999999999999998 en
      # Float puro, lo que antes truncaba a 11 en vez de 12.
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 40).current_price(0.10))
      portfolio.update_price(:META, 0.10)
      portfolio.set_allocation(:META, 0.30)
      # AAPL queda con peso implícito 0 (se vende) porque no tiene allocation propia
 
      order = portfolio.rebalance.find { |o| o[:symbol] == :META }
 
      expect(order).to include(action: :buy, shares: 12)
    end
 
    it "NO redondea hacia arriba una fracción genuina cercana a un entero (caso adversarial)" do
      # Total = $400 (4 AAPL a $100). Con weight = 0.4999999 (7 decimales de
      # precisión real, no ruido), el target para META es $199.99996 ->
      # 1.9999996 acciones EXACTAS de fracción genuina. Debe dar floor = 1,
      # no 2 (un round() a decimales fijos redondearía esto mal).
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 4).current_price(100))
      portfolio.update_price(:META, 100)
      portfolio.set_allocation(:META, 0.4999999)
 
      order = portfolio.rebalance.find { |o| o[:symbol] == :META }
 
      expect(order).to include(action: :buy, shares: 1)
    end
 
    it "no sobrepasa la cantidad de acciones existentes al vender un holding muy grande" do
      # Con un epsilon puramente relativo (sin tope), 1_000_000_000 * 1e-9 = 1.0
      # de epsilon, suficiente para empujar un valor YA EXACTO (mil millones)
      # al siguiente entero y proponer vender una acción de más. El tope
      # absoluto (EPSILON_ABSOLUTE_CAP) evita este overshoot.
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 1_000_000_000).current_price(1))
      # Sin allocation -> objetivo 0%, se debe vender exactamente lo que existe
 
      order = portfolio.rebalance.find { |o| o[:symbol] == :AAPL }
 
      expect(order).to include(action: :sell, shares: 1_000_000_000)
      expect { portfolio.rebalance! }.not_to raise_error
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
 
    it "rechaza un precio infinito" do
      stock = Stock.new(symbol: :AAPL, quantity: 1)
      expect { stock.current_price(Float::INFINITY) }.to raise_error(ArgumentError, /price/)
    end
 
    it "rechaza una cantidad negativa o no entera al crear el Stock" do
      expect { Stock.new(symbol: :AAPL, quantity: -1) }.to raise_error(ArgumentError, /quantity/)
      expect { Stock.new(symbol: :AAPL, quantity: 1.5) }.to raise_error(ArgumentError, /quantity/)
    end
 
    it "no permite que adjust_quantity deje la posición en negativo" do
      stock = Stock.new(symbol: :AAPL, quantity: 5)
      expect { stock.adjust_quantity(-10) }.to raise_error(ArgumentError, /vender más acciones/)
    end
 
    it "rechaza un delta fraccionario en adjust_quantity" do
      stock = Stock.new(symbol: :AAPL, quantity: 5)
      expect { stock.adjust_quantity(0.5) }.to raise_error(ArgumentError, /delta_shares/)
    end
  end
 
  describe "#update_price con precio inválido" do
    it "no deja un Stock a medio crear en el portfolio si el precio es inválido" do
      expect { portfolio.update_price(:META, 0) }.to raise_error(ArgumentError)
 
      # META no debería haber quedado registrado: total_value no debe fallar
      # por un holding "fantasma" sin precio.
      expect(portfolio.total_value).to eq(0)
    end
  end
end