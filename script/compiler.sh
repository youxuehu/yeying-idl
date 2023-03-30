#!/bin/sh

# before running the script on macos, you should install protobuf with command `brew install protobuf`
base_name="${0##*/}"
current_directory=$(
  cd "$(dirname "$0")" || exit 1
  pwd
)

usage() {
  printf "Please specify the app name, such canal, odsn, and so on\n"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

cd "${current_directory}"/.. || exit 1
runtime_directory=$(pwd)

target_dir="${runtime_directory}"/target
mkdir -p "${target_dir}"
if [ "$1" == "odsn" ]; then
  rm -rf "${target_dir}"

  proto_dir="${runtime_directory}/$1/v1"
  js_dir="${target_dir}/js"
  openapi_dir="${target_dir}/doc/openapi"
  go_dir="${target_dir}/go"

  mkdir -p "${go_dir}"
  mkdir -p "${js_dir}"
  mkdir -p "${openapi_dir}"

  protoc -I include/googleapis --proto_path="${proto_dir}" \
    --go_out="${go_dir}" \
    --go-grpc_out="${go_dir}" \
    --grpc-gateway_out="${go_dir}" --grpc-gateway_opt logtostderr=true --grpc-gateway_opt generate_unbound_methods=true \
    --openapiv2_out=:"${openapi_dir}" --openapiv2_opt logtostderr=true \
    --js_out=import_style=commonjs,binary:"${js_dir}" \
    "${proto_dir}"/*.proto
fi
