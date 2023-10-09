#!/bin/sh

# before running the script on macos, you should install protobuf with command `brew install protobuf`
base_name="${0##*/}"
current_directory=$(
  cd "$(dirname "$0")" || exit 1
  pwd
)

# idl的编译工作不再感知上层应用，只需要告诉上层应用类型即可，在编译的时候，还需要考虑不同的语言、不同文件和包路径的处理。整个编译工作分两步：
# 1、创建proto编译环境，生成结构化的proto文件目录；
# 2、执行proto编译命令，由上层的应用来处理编译后的文件存放的位置；
# TODO: 未来演进的方向，针对不同语言生成独立的包，提供开箱即用的使用体验，目前还需要应用层对具体的模块做独立适配。

# 参数说明，-m参数中如果指定的多个模块之间存在依赖关系，请把被依赖模块写到前面，否则可能提示找不到模块
usage() {
  printf "Usage: %s\n \
    -t <Specify the application type for the interface: server or client>\n \
    -m <Specify the module name, such as robot, user, store, or multiple module with comma separated>\n \
    -l <Specify language to generate code, such go, javascript, python and so on>\n \
    " "${base_name}"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

# For macos`s getopt, reference: https://formulae.brew.sh/formula/gnu-getopt
while getopts ":ht:m:l:" o; do
  case "${o}" in
  t)
    app_type=${OPTARG}
    ;;
  m)
    module=${OPTARG}
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

echo "Generate code for app_type=${app_type} with language=${language}, module=${module}"

if [ -z "${app_type}" ]; then
  echo "Please specify the app type to generate!"
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
  module_check_and_install googleapis-common-protos
  module_check_and_install protobuf-init
  module_check_and_install grpcio
  module_check_and_install grpcio-tools
}

cd "${current_directory}"/.. || exit 1
runtime_directory=$(pwd)

# 编译前清空历史
target_dir="${runtime_directory}"/target
if [ -d "${target_dir}" ]; then
  rm -rf "${target_dir}"
fi
mkdir -p "${target_dir}"

# 编译结构输出目录
output_dir="${target_dir}/${app_type}/${language}"
mkdir -p "${output_dir}"

# 需要编译的proto文件所在位置
compile_dir="${target_dir}/proto"
mkdir -p "${compile_dir}"

# 源proto文件所在位置
api_source_dir="${runtime_directory}/yeying/api"
api_target_dir="${compile_dir}/yeying/api"
mkdir -p "${api_target_dir}"

if [ "${app_type}" == "server" ] && [ "${language}" == "go" ]; then
  # 指定编译依赖的proto，grpc使用的http2协议，浏览器使用http1.x协议，尽可能的兼容http1.x，使用google提供protoc生成http1.x的代码，但是
  # 在实际项目中需要依赖对应的库，go的库是google.golang.org/genproto
  ln -s "${runtime_directory}/third_party/googleapis/google" "${compile_dir}/google"

  # 从module参数中获得需要编译的模块，编译模块以逗号隔开, 参数里面的模块顺序也代表了编译的顺序
  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    ln -s "${api_source_dir}/${name}" "${api_target_dir}/${name}"
    echo "Compile module=${name}"

    # 在哪个路径下搜索.proto文件, 可以用-I<path>，也可以使用--proto_path=<path>
    if ! protoc --proto_path="${compile_dir}" \
      --go_out="${output_dir}" \
      --go-grpc_out="${output_dir}" \
      --grpc-gateway_out="${output_dir}" --grpc-gateway_opt logtostderr=true \
      --grpc-gateway_opt generate_unbound_methods=true \
      "${api_target_dir}/${name}"/*.proto; then
      echo "Fail to compile module=${name} for type=${app_type}, language=${language}"
      exit 1
    fi
  done
elif [ "${app_type}" == "server" ] && [ "${language}" == "python" ]; then
  check_python_dependency
  ln -s "${runtime_directory}/third_party/googleapis/google" "${compile_dir}/google"
  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    ln -s "${api_source_dir}/${name}" "${api_target_dir}/${name}"
    # use the command for help, python -m grpc.tools.protoc -h
    # 1、使用protoc编译protobuf文件只会生成相应编程语言的protobuf文件，而使用grpc_tools.protoc编译protobuf文件会生成相应编程语言的
    # protobuf文件和与gRPC相关的服务端和客户端代码
    # 2、如果需要在生成的代码里面自动带上__init__.py文件需要带上参数init_python_out
    if ! python3 -m grpc_tools.protoc -I"${compile_dir}" \
      --python_out="${output_dir}" \
      --pyi_out="${output_dir}" \
      --grpc_python_out="${output_dir}" \
      --init_python_out="${output_dir}" \
      --init_python_opt=imports=protobuf+grpcio \
      "${api_target_dir}/${name}"/*.proto; then
      echo "Fail to compile module=${name} for type=${app_type}, language=${language}"
      exit 1
    fi
  done
elif [ "${app_type}" == "client" ] && [ "${language}" == "javascript" ]; then
  installed=$(npm -g ls | grep grpc-tools)
  if [ -z "${installed}" ]; then
    npm install -g grpc-tools
  fi

  ln -s "${runtime_directory}/third_party/googleapis/google" "${compile_dir}/google"
  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    echo "Compile module=${name}"
    ln -s "${api_source_dir}/${name}" "${api_target_dir}/${name}"

    #  this method is not working currently, or you must deploy envoy proxy firstly.
    #  protoc -I third_party/googleapis --proto_path="${compile_dir}" \
    #    --js_out=import_style=commonjs,binary:"${output_dir}" \
    #    --grpc-web_out=import_style=commonjs,mode=grpcwebtext:"${output_dir}" \
    #    "${compile_dir}"/*.proto

    if ! grpc_tools_node_protoc --proto_path="${compile_dir}" \
      --js_out=import_style=commonjs,binary:"${output_dir}" \
      --grpc_out=grpc_js:"${output_dir}" \
      --plugin=protoc-gen-grpc=$(which grpc_tools_node_protoc_plugin) \
      "${compile_dir}/google/api/annotations.proto" \
      "${compile_dir}/google/api/http.proto" \
      "${api_target_dir}/${name}"/*.proto; then
        echo "Fail to compile module=${name} for type=${app_type}, language=${language}"
        exit 1
    fi
  done
else
  echo "not supported, app type=${app_type}, language=${language}"
  exit 1
fi
echo "Compile protoc successfully."
