class Stock
  attr_reader :symbol, :quantity, :price
  def initialize(symbol:, quantity: 0)
    validate_quantity!(quantity)
    @symbol = symbol.to_s.upcase.to_sym
    @quantity = quantity
    @price = nil
  end

  def current_price(price)
    validate_price!(price)
    @price = price
    self
  end

  def market_value
    raise "No se ha seteado el precio actual para la acción: #{symbol}" if price.nil?
    quantity * price
  end

  def adjust_quantity(delta_shares)
    new_quantity = quantity + delta_shares
    raise ArgumentError, "No se pueden vender más acciones de las que se poseen (#{symbol})" if new_quantity.negative?
 
    @quantity = new_quantity
  end

  def to_s
    "#{symbol}: #{quantity} acciones @ #{price.inspect}"
  end

  private

  def validate_quantity!(quantity)
    return if quantity.is_a?(Integer) && quantity >= 0
    raise ArgumentError, "quantity debe ser un entero >= 0 (recibido: #{quantity.inspect})"
  end
 
  def validate_price!(price)
    return if price.is_a?(Numeric) && price.positive?
    raise ArgumentError, "price debe ser un número > 0 (recibido: #{price.inspect})"
  end
end
