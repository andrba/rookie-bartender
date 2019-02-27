SparkleFormation.new(:step) do
  transform 'AWS::Serverless-2016-10-31'

  parameters do
    webhook_image do
      type 'String'
      description 'Webhook docker image path'
    end
  end

  resource_name = 'RookieBartender'

  globals do
    function do
      memory_size 128
      timeout 3
    end
  end

  alcohol_lambda = resources.__send__("#{resource_name}Alcohol") do
    type 'AWS::Serverless::Function'
    properties do
      runtime 'ruby2.5'
      handler 'lambda.Alcohol.process'
      code_uri 'steps/alcohol/'
    end
  end

  soft_drink_lambda = resources.__send__("#{resource_name}SoftDrink") do
    type 'AWS::Serverless::Function'
    properties do
      runtime 'nodejs8.10'
      handler 'lambda.handler'
      code_uri 'steps/soft-drink/'
    end
  end

  # fruit_lambda = resources.__send__("#{resource_name}Fruit") do
  #   type 'AWS::Serverless::Function'
  #   properties do
  #     handler 'lambda'
  #     runtime 'go1.x'
  #     code_uri 'steps/fruit/'
  #   end
  # end

  webhook_activity = resources.__send__("#{resource_name}WebhookActivity") do
    type 'AWS::StepFunctions::Activity'
    properties do
      name "#{resource_name}Webhook"
    end
  end

  vpc = dynamic!(:ec2_vpc, resource_name) do
    properties do
      cidr_block "10.99.0.0/16"
    end
  end

  internet_gateway = dynamic!(:ec2_internetgateway, resource_name) do
  end

  dynamic!(:ec2_vpc_gateway_attachment, resource_name) do
    properties do
      vpc_id ref!(vpc.resource_name!)
      internet_gateway_id ref!(internet_gateway.resource_name!)
    end
  end

  public_subnet = dynamic!(:ec2_subnet, "#{resource_name}_public") do
    properties do
      vpc_id ref!(vpc.resource_name!)
      cidr_block "10.99.0.0/24"
    end
  end

  public_routetable = dynamic!(:ec2_routetable, "#{resource_name}_public") do
    properties do
      vpc_id ref!(vpc.resource_name!)
    end
  end

  dynamic!(:ec2_subnetroutetableassociation, "#{resource_name}_public_subnet_association") do
    properties do
      subnet_id ref!(public_subnet.resource_name!)
      route_table_id ref!(public_routetable.resource_name!)
    end
  end

  dynamic!(:ec2_route, "#{resource_name}_public") do
    properties do
      destination_cidr_block '0.0.0.0/0'
      gateway_id ref!(internet_gateway.resource_name!)
      route_table_id ref!(public_routetable.resource_name!)
    end
  end

  cluster = resources.__send__("#{resource_name}Cluster") do
    type "AWS::ECS::Cluster"
  end

  webhook_log_group = resources.__send__("#{resource_name}LogGroup") do
    type "AWS::Logs::LogGroup"
    properties do
      log_group_name "/fargate/#{resource_name}/webhook"
    end
  end

  webhook_task_execution_role = dynamic!(:iam_role, "#{resource_name}WebhookTaskExecution") do
    properties do
      assume_role_policy_document registry!(:policy_document_header, ["ecs-tasks.amazonaws.com"])
      path '/'
      managed_policy_arns ['arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy']
      policies [
        {
          "PolicyName": 'WebhookTaskExecutionPolicy',
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
                ],
                "Resource": [
                  "arn:aws:states:*:*:activity:#{resource_name}Webhook"
                ]
              }
            ]
          }
        }
      ]
    end
  end

  webhook_task_role = dynamic!(:iam_role, "#{resource_name}WebhookTaskRole") do
    properties do
      assume_role_policy_document registry!(:policy_document_header, ["ecs-tasks.amazonaws.com", "states.amazonaws.com"])
      path '/'
      policies [
        {
          "PolicyName": 'WebhookTaskRolePolicy',
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "states:DescribeActivity",
                  "states:DeleteActivity",
                  "states:GetActivityTask",
                  "states:SendTaskSuccess",
                  "states:SendTaskFailure",
                  "states:SendTaskHeartbeat"
                ],
                "Resource": [
                  "arn:aws:states:*:*:activity:#{resource_name}Webhook"
                ]
              }
            ]
          }
        }
      ]
    end
  end

  webhook_task_definition = resources.__send__("#{resource_name}WebhookTask") do
    type 'AWS::ECS::TaskDefinition'
    properties do 
      cpu 256
      memory '0.5GB'
      task_role_arn attr!(webhook_task_role.resource_name!, 'Arn')
      execution_role_arn attr!(webhook_task_execution_role.resource_name!, 'Arn')
      network_mode 'awsvpc'
      requires_compatibilities ['FARGATE','EC2']
      container_definitions(
        [
          {
            "Name" => "Webhook",
            "Image" => ref!("WebhookImage"),
            "Environment" => [
              {
                "Name" => "ACTIVITY_ARN",
                "Value" => ref!(webhook_activity.resource_name!)
              }
            ],
            "LogConfiguration": {
              "LogDriver": "awslogs",
              "Options": {
                "awslogs-group": ref!(webhook_log_group.resource_name!),
                "awslogs-region": "ap-southeast-2",
                "awslogs-stream-prefix": "webhook"
              }
            }
          }
        ]
      )
    end
  end

  state_machine_execution_role = dynamic!(:iam_role, "#{resource_name}StateMachineExecution") do
    properties do
      assume_role_policy_document registry!(:policy_document_header, ["states.amazonaws.com"])
      path '/'
      policies [
        {
          "PolicyName": "StatesExecutionPolicy",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "lambda:InvokeFunction"
                ],
                "Resource": [
                  attr!(alcohol_lambda.resource_name!, 'Arn'),
                  attr!(soft_drink_lambda.resource_name!, 'Arn')
                ]
              },
              {
                "Effect": "Allow",
                "Action": [
                  "ecs:RunTask",
                  "ecs:StopTask"
                ],
                "Resource": ref!(webhook_task_definition.resource_name!)
              },
              {
                "Effect": "Allow",
                "Action": [
                  "ecs:DescribeTasks"
                ],
                "Resource": "*"
              },
              {
                "Effect": "Allow",
                "Action": [
                  "events:PutTargets",
                  "events:PutRule",
                  "events:DescribeRule"
                ],
                "Resource": [
                  "arn:aws:events:*:*:rule/StepFunctionsGetEventsForECSTaskRule"
                ]
              },
              {
                "Effect": "Allow",
                "Action": [ 
                  "iam:PassRole"
                ],
                "Resource": [
                  attr!(webhook_task_execution_role.resource_name!, "Arn"),
                  attr!(webhook_task_role.resource_name!, "Arn")
                ]
              }
            ]
          }
        }
      ]
    end
  end

  state_machine_params = {
    resource_name: resource_name,
    alcohol_lambda_arn: attr!(alcohol_lambda.resource_name!, "Arn"),
    soft_drink_lambda_arn: attr!(soft_drink_lambda.resource_name!, "Arn"),
    webhook_activity_arn: ref!(webhook_activity.resource_name!),
    cluster_arn: attr!(cluster.resource_name!, "Arn"),
    subnet_ref: ref!(public_subnet.resource_name!),
    webhook_task_definition_ref: ref!(webhook_task_definition.resource_name!)
  }

  state_machine = resources.__send__("#{resource_name}StateMachine") do
    type "AWS::StepFunctions::StateMachine"
    properties do
      definition_string sub!(
        File.read("./state-machine.json"),
        **state_machine_params
      )
      role_arn attr!(state_machine_execution_role.resource_name!, 'Arn')
    end
  end

  api_gateway = resources.__send__("#{resource_name}ApiGateway") do
    type "AWS::Serverless::Api"
    properties do
      stage_name "Dev" # ???
    end
  end

  api_endpoint_lambda_role = dynamic!(:iam_role, "#{resource_name}ApiEndpointLambdaRole") do
    properties do
      assume_role_policy_document registry!(:policy_document_header, ["lambda.amazonaws.com", "states.ap-southeast-2.amazonaws.com"])
      managed_policy_arns ['arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole']
      policies [
        {
          "PolicyName": "StateMachineExecutionPolicy",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "states:StartExecution"
                ],
                "Resource": ref!(state_machine.resource_name!)
              }
            ]
          }
        }
      ]
    end
  end

  api_endpoint_lambda = resources.__send__("#{resource_name}ApiEndpointLambda") do
    type 'AWS::Serverless::Function'
    properties do
      runtime 'ruby2.5'
      handler 'lambda.ApiEndpoint.process'
      code_uri 'api/'
      description 'Api Endpoint'
      role attr!(api_endpoint_lambda_role.resource_name!, 'Arn')
      environment do
        camel_keys_set!(:auto_disable)
        Variables(
          { 'STATE_MACHINE_ARN' => ref!(state_machine.resource_name!) }
        )
      end
      events do
        post do
          type 'Api'
          properties do
            rest_api_id ref!(api_gateway.resource_name!)
            path '/'
            method 'post'
          end
        end
      end
    end
  end
end
