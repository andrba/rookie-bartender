class Alcohol
  class << self
    SPIRITS = %w[
      Rum
      Tequila
      Vodka
      Gin
      Whisky
    ]

    def process(event:, context:)
      event.merge!('recipe' => event['recipe'] << SPIRITS.sample)
    end
  end
end
