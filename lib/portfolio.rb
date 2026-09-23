require_relative "stock"
class Portfolio
  MIN_TRADE_VALUE = 1.0
  ALLOCATION_SUM_EPSILON = 1e-9
  def initialize
    @holdings = {}
    @allocations = {}
    @cash = 0
  end

  def add_holding(stock)
    if @holdings.key?(stock.symbol)
      raise ArgumentError, "#{stock.symbol} ya existe en el portfolio; usa update_price o ajusta la cantidad directamente"
    end
 
    @holdings[stock.symbol] = stock
  end

  def update_price(symbol, price)
    symbol = symbol.to_s.upcase.to_sym
    stock = @holdings[symbol] ||= Stock.new(symbol: symbol)
    stock.current_price(price)
  end

  def set_allocation(symbol, target_weight)
    symbol = symbol.to_s.upcase.to_sym
    validate_target_weight!(target_weight)
    validate_total_allocation!(symbol, target_weight)
    @allocations[symbol] = target_weight
  end

  attr_reader :cash

  def total_value
    @holdings.values.sum(&:market_value) + cash
  end

  def rebalance
    portfolio_value = total_value
    symbols = (@holdings.keys | @allocations.keys)
 
    symbols.filter_map do |symbol|
      target_weight = @allocations.fetch(symbol, 0)
      stock = @holdings[symbol]
      current_value = stock&.market_value || 0
 
      next if target_weight.zero? && current_value.zero?
 
      price = stock&.price
      if price.nil?
        raise "No hay precio para #{symbol}. Usa update_price(#{symbol.inspect}, precio) antes de rebalancear."
      end
 
      target_value = portfolio_value * target_weight
      diff_value = target_value - current_value
 
      next if diff_value.abs < self.class::MIN_TRADE_VALUE
 
      shares = (diff_value.abs / price).floor
      next if shares.zero? # la diferencia en plata no alcanza para 1 acción completa
 
      {
        symbol: symbol,
        action: diff_value.positive? ? :buy : :sell,
        shares: shares,
        estimated_value: (shares * price).round(2)
      }
    end
  end
 
  def rebalance!
    rebalance.each do |order|
      stock = @holdings[order[:symbol]] ||= Stock.new(symbol: order[:symbol])
 
      if order[:action] == :buy
        stock.adjust_quantity(order[:shares])
        @cash -= order[:estimated_value]
      else
        stock.adjust_quantity(-order[:shares])
        @cash += order[:estimated_value]
      end
    end
  end

  private
  def validate_target_weight!(target_weight)
    return if (0..1).cover?(target_weight)
 
    raise ArgumentError, "El peso objetivo debe estar entre 0 y 1 (recibido: #{target_weight.inspect})"
  end
 
  def validate_total_allocation!(symbol, target_weight)
    total = @allocations.reject { |s, _| s == symbol }.values.sum + target_weight
    return if total <= 1.0 + ALLOCATION_SUM_EPSILON
 
    raise ArgumentError, "La suma de allocations no puede superar 100% (da #{(total * 100).round(4)}%)"
  end
end
