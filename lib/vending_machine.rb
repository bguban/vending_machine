require 'hirb'

class VendingMachine
  include Hirb::Console
  class Cancel < Exception; end

  # amount of different types of coins
  COINS = [
    { value: 0.25, stock: 10 },
    { value: 0.50, stock: 10 },
    { value: 1.00, stock: 10 },
    { value: 2.00, stock: 10 },
    { value: 5.00, stock: 10 }
  ].freeze

  PRODUCTS = [
    { name: "good 1", stock: 1, price: 2.50 },
    { name: "good 2", stock: 1, price: 1.00 },
    { name: "good 3", stock: 1, price: 1.00 }
  ].freeze

  attr_accessor :products, :coins, :selected_product, :money, :state

  def initialize(products = PRODUCTS.map(&:dup))
    @products = products
    @coins = COINS.map(&:dup)
    @state = :select_product
    @money = 0.00
  end

  def run
    loop do
      begin
        send state
      rescue Cancel
        printf("You have $%0.2f", money) if money > 0
        self.state = :select_product
      end
    end
  end

  def select_product
    table products.each_with_index.map { |product, i| product.merge(id: i) }, fields: [:id, :name, :stock, :price]
    puts "Enter the product's id you would like to buy:"
    self.selected_product = products[read_input.to_i]
    return puts("Number is out of range") if selected_product.nil?
    return puts("The product is out of stock") if selected_product[:stock] <= 0

    self.state = :receive_money
  end

  def receive_money
    return self.state = :give_product if money >= selected_product[:price]

    puts "put $#{selected_product[:price] - money}"
    input = read_input.to_f
    return puts("Wrong input") if input <= 0

    self.money += input
    self.state = :give_product if money >= selected_product[:price]
  end

  def give_product
    puts "Your change is:"
    change = calculate_change(money - selected_product[:price])
    self.money = change.delete(:left)
    change.each { |value, amount| printf("%d coin(s) by $%0.2f\n", amount, value) }
    selected_product[:stock] -= 1
    coins.each { |coin| coin[:stock] -= change[coin[:value]] || 0 }
    puts "Sorry, I don't have coins to give you $#{money} change. You can you it to buy another product" if money > 0.0
    self.state = :select_product
  end

  def calculate_change(amount)
    amount = (amount * 100).to_i
    change = {}
    coins.sort_by { |coin| coin[:value] }.reverse.each do |coin|
      value = (coin[:value] * 100).to_i
      next if amount / coin[:value] < 1

      coins = [amount / value, coin[:stock]].min
      change[coin[:value]] = coins if coins > 0
      amount -= value * coins
    end

    change[:left] = amount / 100.0
    change
  end

  def read_input
    input = gets.chomp
    raise Cancel if input == "cancel"

    input
  end
end
