#!/bin/bash

set -e

root_dir="$(cd `dirname $0` && pwd)/.."
build_dir="${root_dir}/.build"

mkdir -p ${build_dir}

webhook_image_tag="webhook"

echo '--- Building and Packaging lambda functions'
sam build \
  --use-container \
  --base-dir=${root_dir}/app \
  --build-dir=${build_dir} \
  --template=${root_dir}/app/template.yaml

sam package \
  --s3-bucket=${LAMBDA_S3_BUCKET_NAME} \
  --template-file=${build_dir}/template.yaml \
  --output-template-file=${build_dir}/packaged-template.yaml

echo '--- Building and Pushing docker images'
eval $(aws --region ap-southeast-2 ecr get-login --no-include-email)
docker build -t ${DOCKER_REPO}:${webhook_image_tag} "${root_dir}/app/steps/webhook/"
docker tag ${DOCKER_REPO}:${webhook_image_tag} ${DOCKER_REGISTRY}/${DOCKER_REPO}:${webhook_image_tag}
docker push ${DOCKER_REGISTRY}/${DOCKER_REPO}:${webhook_image_tag}

echo '--- Deploying'
aws cloudformation deploy \
  --stack-name=${STACK_NAME} \
  --template-file=${build_dir}/packaged-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides WebhookImage=${DOCKER_REGISTRY}/${DOCKER_REPO}:${webhook_image_tag} \
  --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
  echo '--- The application has been deployed'
  rest_api_id=$(aws apigateway get-rest-apis | jq -r '.items[] | select(.name == "step-functions-example") | .id')

  echo "https://${rest_api_id}.execute-api.ap-southeast-2.amazonaws.com/Dev"
fi
