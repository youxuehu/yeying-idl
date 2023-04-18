#!/bin/sh

# before running the script on macos, you should install protobuf with command `brew install protobuf`
base_name="${0##*/}"
current_directory=$(
  cd "$(dirname "$0")" || exit 1
  pwd
)

usage() {
  printf "Usage: %s\n \
    -a <Specify the app name, such as slot, yeying, canal, odsn, spiderman and so on\n \
    -m <Specify the mode name, such as aigc, handshake or empty\n \
    -v <Specify the mode version, default v1 \n \
    -l <Specify language to generate code, such go, javascript, python and so on>\n \
    " "${base_name}"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

version=v1
# For macos`s getopt, reference: https://formulae.brew.sh/formula/gnu-getopt
while getopts ":ha:m:v:l:" o; do
  case "${o}" in
  a)
    app_name=${OPTARG}
    ;;
  m)
    model_name=${OPTARG}
    ;;
  v)
    version=${OPTARG}
    ;;
  l)
    language=${OPTARG}
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

echo "generate code for app=${app_name} with language=${language}, version=${version}, model=${model_name}"

if [ -z "${app_name}" ]; then
  echo "Please specify the app name to generate!"
  usage
fi

if [ -z "${language}" ]; then
  echo "Please specify the language to generate!"
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

check_python_dependency() {
  module_check_and_install protobuf-init
  module_check_and_install grpcio
  module_check_and_install grpcio-tools
}

cd "${current_directory}"/.. || exit 1
runtime_directory=$(pwd)

target_dir="${runtime_directory}"/target
rm -rf "${target_dir}"
output_dir="${target_dir}/${language}"
mkdir -p "${output_dir}"
protoc_dir="${target_dir}/protoc"
mkdir -p "${protoc_dir}"

if [ "${app_name}" == "odsn" ]; then
  protoc_dir="${runtime_directory}/${app_name}/v1"
  output_dir="${target_dir}/js"
  openapi_dir="${target_dir}/openapi"
  go_dir="${target_dir}/go"

  mkdir -p "${go_dir}"
  mkdir -p "${output_dir}"
  mkdir -p "${openapi_dir}"

  protoc -I include/googleapis --proto_path="${protoc_dir}" \
    --go_out="${go_dir}" \
    --go-grpc_out="${go_dir}" \
    --grpc-gateway_out="${go_dir}" --grpc-gateway_opt logtostderr=true --grpc-gateway_opt generate_unbound_methods=true \
    --openapiv2_out=:"${openapi_dir}" --openapiv2_opt logtostderr=true \
    --js_out=import_style=commonjs,binary:"${output_dir}" \
    "${protoc_dir}"/*.proto
elif [ "${app_name}" == "spiderman" ] && [ "${language}" == "python" ]; then
  check_python_dependency

  python_dir="${target_dir}/python"
  mkdir -p "${python_dir}"
  echo "proto directory=${protoc_dir}"

  # use the command for help, python -m grpc.tools.protoc -h
  python3 -m grpc_tools.protoc -I"${protoc_dir}" \
    --python_out="${python_dir}" \
    --pyi_out="${python_dir}" \
    --grpc_python_out="${python_dir}" \
    --init_python_out="${python_dir}" \
    --init_python_opt=imports=protobuf+grpcio \
    "${protoc_dir}/${app_name}"/v1/*.proto
elif [ "${app_name}" == "slot" ] && [ "${language}" == "python" ]; then
  check_python_dependency
  mkdir -p "${protoc_dir}/${app_name}/pb"

  IFS=',' read -ra arr <<< "${model_name}"
  for name in "${arr[@]}"; do
    ln -s "${runtime_directory}/${name}" "${protoc_dir}/${app_name}/pb/${name}"
    # use the command for help, python -m grpc.tools.protoc -h
    python3 -m grpc_tools.protoc -I"${protoc_dir}" \
      --python_out="${output_dir}" \
      --pyi_out="${output_dir}" \
      --grpc_python_out="${output_dir}" \
      --init_python_out="${output_dir}" \
      --init_python_opt=imports=protobuf+grpcio \
      "${protoc_dir}/${app_name}/pb/${name}/${version}"/*.proto
  done
elif [ "${app_name}" == "yeying" ] && [ "${language}" == "javascript" ]; then
  installed=$(npm -g ls | grep grpc-tools)
  if [ -z "${installed}" ]; then
    npm install -g grpc-tools
  fi
  mkdir -p "${protoc_dir}/${app_name}/pb"
  mkdir -p "${protoc_dir}/include"

  ln -s "${runtime_directory}/third_party/googleapis/google" "${protoc_dir}/include/google"

  IFS=',' read -ra arr <<< "${model_name}"
  for name in "${arr[@]}"; do
    ln -s "${runtime_directory}/${name}" "${protoc_dir}/${app_name}/pb/${name}"

  #  this method is not working currently, or you must deploy envoy proxy firstly.
  #  protoc -I third_party/googleapis --proto_path="${protoc_dir}" \
  #    --js_out=import_style=commonjs,binary:"${output_dir}" \
  #    --grpc-web_out=import_style=commonjs,mode=grpcwebtext:"${output_dir}" \
  #    "${protoc_dir}"/*.proto

  grpc_tools_node_protoc -I"${protoc_dir}/include" --proto_path="${protoc_dir}/${app_name}" \
    --js_out=import_style=commonjs,binary:"${output_dir}" \
    --grpc_out=grpc_js:"${output_dir}" \
    --plugin=protoc-gen-grpc=$(which grpc_tools_node_protoc_plugin) \
    "${protoc_dir}/${app_name}/pb/${name}/${version}"/*.proto
  done
else
  echo "not supported, app name=${app_name}, language=${language}"
fi
