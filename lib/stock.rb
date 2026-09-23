class Stock
  attr_reader :symbol, :quantity, :price
  def initialize(symbol:, quantity: 0)
    @symbol = symbol.to_s.upcase.to_sym
    @quantity = quantity
    @price = nil
  end
  def current_price(last_available_price)
    @price = last_available_price
    self
  end
  def market_value
    raise "No se ha seteado el precio actual para la acción: #{symbol}" if price.nil?
    quantity * price
  end
  def adjust_quantity(delta_shares)
    @quantity += delta_shares
  end
  def to_s
    "#{symbol}: #{quantity} acciones @ #{price.inspect}"
  end
end
