require 'vending_machine'

RSpec.describe VendingMachine do
  let(:machine) { VendingMachine.new }

  it "has suitable coins for greedy algorithm" do
    values = machine.coins.map { |coin| coin[:value] }.sort

    (1...values.size).each do |i|
      expect(values[i - 1] * 2 <= values[i]).to be_truthy
    end
  end

  describe "#calculate_change" do
    it "returns change" do
      expect(machine.calculate_change(8.76)).to eq(5.0 => 1, 2.0 => 1, 1.0 => 1, 0.5 => 1, 0.25 => 1, left: 0.01)
    end

    context "when 50 cents coins are unavailable" do
      before { machine.coins.find { |coin| coin[:value] == 0.50 }[:stock] = 0 }

      it "uses 25 cents coins instead" do
        expect(machine.calculate_change(8.76)).to eq(5.0 => 1, 2.0 => 1, 1.0 => 1, 0.25 => 3, left: 0.01)
      end
    end
  end

  describe "#select_product" do
    context "when id 0 was entered" do
      before { allow(machine).to receive(:gets).and_return("0\n") }

      it "selects the first product" do
        output = <<~EOOUTPUT
          +----+--------+-------+-------+
          | id | name   | stock | price |
          +----+--------+-------+-------+
          | 0  | good 1 | 1     | 2.5   |
          | 1  | good 2 | 1     | 1.0   |
          | 2  | good 3 | 1     | 1.0   |
          +----+--------+-------+-------+
          3 rows in set
          Enter the product's id you would like to buy:
        EOOUTPUT
        expect { machine.select_product }.to output(output).to_stdout
        expect(machine.selected_product).to eq(machine.products.first)
        expect(machine.state).to eq(:receive_money)
      end
    end

    context "when number is out of range" do
      before { allow(machine).to receive(:gets).and_return("10\n") }

      it "returns an error message" do
        expect { machine.select_product }.to output(/Number is out of range/).to_stdout
        expect(machine.state).to eq(:select_product)
      end
    end

    context "when selected product is out of stock" do
      before do
        allow(machine).to receive(:gets).and_return("0\n")
        machine.products.first[:stock] = 0
      end

      it "returns an error message" do
        expect { machine.select_product }.to output(/The product is out of stock/).to_stdout
        expect(machine.state).to eq(:select_product)
      end
    end
  end

  describe "#receive_money" do
    before { machine.selected_product = machine.products.first }

    context "when enough money were entered" do
      before { allow(machine).to receive(:gets).and_return("10\n") }

      it "sets money variable and changes the state" do
        expect { machine.receive_money }.to output("put $2.5\n").to_stdout.and change(machine, :money).by(10.0)
        expect(machine.state).to eq(:give_product)
      end
    end

    context "when not enough money were entered", :silent do
      before { allow(machine).to receive(:gets).and_return("1\n") }

      it "sets money but doesn't change state" do
        expect { machine.receive_money }.not_to change(machine, :state)
        expect(machine.money).to eq(1.0)
      end
    end

    context "when wrong value was entered" do
      before { allow(machine).to receive(:gets).and_return("foo\n") }

      it "puts an error message" do
        expect { machine.receive_money }.to output(/Wrong input/).to_stdout.and change(machine, :money).by(0.0)
      end
    end
  end

  describe "#give_product" do
    before do
      machine.selected_product = machine.products.first
      machine.money = 11.26
    end

    it "calculates the change and decreases stocks" do
      output = <<~EOOUTPUT
        Your change is:
        1 coin(s) by $5.00
        1 coin(s) by $2.00
        1 coin(s) by $1.00
        1 coin(s) by $0.50
        1 coin(s) by $0.25
        Sorry, I don't have coins to give you $0.01 change. You can you it to buy another product
      EOOUTPUT
      expect { machine.give_product }.to output(output).to_stdout
        .and change { machine.selected_product[:stock] }.by(-1)

      expect(machine.coins.map {|coin| coin[:stock]}).to all(be == 9)
      expect(machine.state).to eq(:select_product)
    end
  end

  describe "full flow" do
    before do
      call_count = 0
      allow(machine).to receive(:gets) do
        res = inputs[call_count] || raise("stop")
        call_count += 1
        res
      end
    end

    context "when selected first product and entered $1 and then $10.26" do
      let(:inputs) { %w(0 1 10.26) }

      it "gave change and left $0.01", :silent do
        expect { machine.run }.to raise_exception(RuntimeError, "stop")
          .and change { machine.products.first[:stock] }.by(-1)

        expect(machine.money).to eq(0.01)
        expect(machine.state).to eq(:select_product)
      end
    end

    context "when product was selected and operation canceled" do
      let(:inputs) { %w(0 cancel) }

      it "goes to select product state", :silent do
        expect { machine.run }.to raise_exception(RuntimeError, "stop")
        expect(machine.state).to eq(:select_product)
      end
    end

    context "when money were entered and operation canceled" do
      let(:inputs) { %w(0 1 cancel) }

      it "goes to select product state but don't loss entered money" do
        expect { machine.run }.to raise_exception(RuntimeError, "stop")
          .and output(/You have \$1\.00/).to_stdout

        expect(machine.state).to eq(:select_product)
        expect(machine.money).to eq(1.0)
      end
    end
  end
end
