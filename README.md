# Rookie Bartender

This is a sample application that demonstrates how [AWS Step Functions](https://docs.aws.amazon.com/step-functions/index.html) can be used for executing various tasks.

A POST request to an API endpoint will execute a state machine which eventually will send a recipe of a requested cocktail to the provided callback.

The state machine consists of the following steps:

![Rookie Bartender](https://user-images.githubusercontent.com/2174682/53533061-6a182a80-3b4d-11e9-8566-5f421de64f75.png)

Each step is a lambda function that takes the state from the previous step and adds a component to the recipe. Each step is written in a different language just for the purpose of demonstrating the flexibility of Step Functions. The final webhook step is executed by a Fargate container.

### Local Development:

Run the following command after updating `stack/stack.rb`

```
./scripts/template.sh
```

The following commands must be executed inside the `app` folder. Alternatively, every command will require specifying the location of `template.yaml` file.

Run a local api-gateway instance:

```
sam local start-api
```

Invoke a lambda function:

```
echo '{"name":"test","recipe":[],"callback":"fake.host"}' | sam local invoke RookieBartenderAlcohol
```

### Specs

Pending...

### Deployment

Requires AWS credentials in order to interact with AWS services.

```
export STACK_NAME="rookie-bartender"
export LAMBDA_S3_BUCKET_NAME="rookie-bartender-s3-bucket"
export DOCKER_REGISTRY="XXXXXXXXXX.dkr.ecr.ap-southeast-2.amazonaws.com"
export DOCKER_REPO=${STACK_NAME}

./scripts/deploy.sh
```

The script will build all lambda functions and the webhook docker image, push them to AWS and deploy cloudformation stack.

Upon successful creation/update of the stack, the deploy command will output the url of an api endpoint that accepts POST requests.

### Running

Sending a request to the endpoint will trigger the state machine process which results in sending a callback to the supplied url:

```
curl -X POST \
  <ENDPOINT_URL> \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "margarita",
    "callback": "<CALLBACK_URL>"
  }'
```
