require 'aws-sdk-states'
require 'json'

class ApiEndpoint
  class << self
    COCKTAILS = [
      'margarita',
      'mojito',
      'bloody mary',
      'pina colada',
    ]

    def process(event:, context:)
      order = JSON.parse(event['body']).slice('name', 'callback').merge('recipe' => [])
      
      unless COCKTAILS.include?(order['name'])
        return json_response(422, { message: '🤷' })
      end

      state_machine_client.start_execution(
        state_machine_arn: ENV.fetch('STATE_MACHINE_ARN'),
        name: "#{order['name']}-#{Time.now.strftime("%F-%H-%M-%S-%L")}",
        input: JSON.generate(order))

      json_response(202, { message: '👍' })
    end

    def json_response(code, body = {})
      {
        'statusCode' => code,
        'headers' => {
          'Content-Type' => 'application/json'
        },
        'body' => JSON.generate(body)
      }
    end

    def state_machine_client
      @state_machine_client ||= Aws::States::Client.new
    end
  end
end
