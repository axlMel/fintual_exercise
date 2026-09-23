require_relative "../lib/portfolio"
 
RSpec.describe Portfolio do
  let(:portfolio) { Portfolio.new }
 
  describe "#total_value" do
    it "suma el valor de mercado de todas las posiciones" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 10).current_price(100))
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 5).current_price(200))
 
      # 10*100 + 5*200 = 2000
      expect(portfolio.total_value).to eq(2000)
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
 
      # Total = 2000. Target AAPL = 1200 (12 acciones). Target META = 800 (4 acciones)
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
 
    it "ignora diferencias menores a MIN_TRADE_VALUE para no generar ruido" do
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 6).current_price(100))
      portfolio.set_allocation(:AAPL, 1.0)
      # 600 actual vs 600 objetivo -> sin diferencia
 
      expect(portfolio.rebalance).to eq([])
    end
  end
 
  describe "#rebalance!" do
    it "ejecuta las órdenes y deja las cantidades actualizadas" do
      portfolio.add_holding(Stock.new(symbol: :META, quantity: 10).current_price(200))
      portfolio.add_holding(Stock.new(symbol: :AAPL, quantity: 0).current_price(100))
      portfolio.set_allocation(:AAPL, 0.6)
      portfolio.set_allocation(:META, 0.4)
 
      portfolio.rebalance!
 
      expect(portfolio.instance_variable_get(:@holdings)[:AAPL].quantity).to eq(12)
      expect(portfolio.instance_variable_get(:@holdings)[:META].quantity).to eq(4)
    end
  end
 
  describe "#set_allocation" do
    it "lanza un error si la suma de allocations supera 100%" do
      portfolio.set_allocation(:AAPL, 0.6)
      expect { portfolio.set_allocation(:META, 0.5) }.to raise_error(ArgumentError, /100%/)
    end
  end
end