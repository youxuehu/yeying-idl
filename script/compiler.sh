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

module_check_and_install() {
  #/dev/null 是一个特殊的文件，写入到它的内容都会被丢弃
  if pip3 show "$1" >/dev/null 2>&1; then
    echo "The $1 module has been installed"
  else
    echo "Try to install $1 module"
    pip3 install "$1"
  fi
}

cd "${current_directory}"/.. || exit 1
runtime_directory=$(pwd)

target_dir="${runtime_directory}"/target
mkdir -p "${target_dir}"
if [ "$1" == "odsn" ]; then
  rm -rf "${target_dir}"

  proto_dir="${runtime_directory}/$1/v1"
  js_dir="${target_dir}/js"
  openapi_dir="${target_dir}/openapi"
  go_dir="${target_dir}/go"
  python_dir="${target_dir}/python"

  mkdir -p "${go_dir}"
  mkdir -p "${js_dir}"
  mkdir -p "${openapi_dir}"
  mkdir -p "${python_dir}"

  protoc -I include/googleapis --proto_path="${proto_dir}" \
    --go_out="${go_dir}" \
    --go-grpc_out="${go_dir}" \
    --grpc-gateway_out="${go_dir}" --grpc-gateway_opt logtostderr=true --grpc-gateway_opt generate_unbound_methods=true \
    --openapiv2_out=:"${openapi_dir}" --openapiv2_opt logtostderr=true \
    --js_out=import_style=commonjs,binary:"${js_dir}" \
    --python_out=pyi_out:"${python_dir}" \
    "${proto_dir}"/*.proto
elif [ "$1" == "gateway" ]; then
  rm -rf "${target_dir}"
  module_check_and_install protobuf-init
  module_check_and_install grpcio
  module_check_and_install grpcio-tools

  proto_dir="${runtime_directory}"
  python_dir="${target_dir}/python"

  mkdir -p "${python_dir}"
  echo "proto directory=${proto_dir}"

  # use the command for help, python -m grpc.tools.protoc -h
  python3 -m grpc_tools.protoc --proto_path="${proto_dir}" \
    --python_out="${python_dir}" \
    --grpc_python_out="${python_dir}" \
    --init_python_out="${python_dir}" \
    --init_python_opt=imports=protobuf+grpcio+grpclib \
    "${proto_dir}/$1"/pb/v1/*.proto
fi
