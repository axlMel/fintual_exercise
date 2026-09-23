require_relative "stock"
MIN_TRADE_VALUE = 1.0
class Portfolio
  def initialize
    @holdings = {}
    @allocations = {}
  end
  def add_holding(stock)
    @holdings[stock.symbol] = stock 
  end
  def set_allocation(symbol, percentage)
    symbol = symbol.to_s.upcase.to_sym
    validate_allocations!(symbol, percentage)
    @allocations[symbol] = percentage
  end
  def total_value
    @holdings.values.sum(&:market_value)
  end
  def rebalance
    target_total = total_value
 
    @allocations.filter_map do |symbol, target_pct|
      stock = @holdings[symbol]
      price = stock&.price
 
      raise "No hay precio disponible para #{symbol}, no se puede rebalancear" if price.nil?
 
      current_value = stock&.market_value || 0
      target_value = target_total * target_pct
      diff_value = target_value - current_value
 
      next if diff_value.abs < MIN_TRADE_VALUE
 
      shares = (diff_value.abs / price).floor
      next if shares.zero? 
 
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
      delta = order[:action] == :buy ? order[:shares] : -order[:shares]
      stock.adjust_quantity(delta)
    end
  end

  private
  def validate_allocations!(symbol, percentage)
    raise ArgumentError, "El porcentaje debe estar entre 0 y 1" unless (0..1).cover?(percentage)
    total = @allocations.reject { |s, _| s == symbol }.values.sum + percentage
    raise ArgumentError, "La suma de la asignación de activos no puede superar el 100%" if total > 1.0001
  end
end
