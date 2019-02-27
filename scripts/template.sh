#!/bin/bash

set -e

root_dir="$(cd `dirname $0` && pwd)/.."

echo '--- Generating template'
$(cd ${root_dir}/stack && bundle exec sfn print --file stack.rb > ${root_dir}/app/template.yaml)
