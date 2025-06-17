#!/usr/bin/env bash


COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_NC='\033[0m'

directory_runtime="$1"
app_type="$2"
module="$3"


if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "${COLOR_RED}Usage: $0 <directory_runtime> <app_type> <module> ${COLOR_NC}"
    exit 1
fi

directory_target="${directory_runtime}"/target

function prepare_for_compile() {
  # 编译结构输出目录
  dir_output="${directory_target}/${app_type}/python"
  mkdir -p "${dir_output}"

  # 需要编译的proto文件所在位置
  dir_compile="${directory_target}/proto"
  mkdir -p "${dir_compile}"

  # 源proto文件所在位置
  dir_api_source="${directory_runtime}/yeying/api"
  dir_api_target="${dir_compile}/yeying/api"
  mkdir -p "${dir_api_target}"
}


function module_check_and_install() {
  #/dev/null 是一个特殊的文件，写入到它的内容都会被丢弃
  if pip3 show "$1" >/dev/null 2>&1; then
    echo "The $1 module has been installed"
  else
    echo "Try to install $1 module"
    pip3 install "$1" --break-system-packages -q || {
      echo -e "${COLOR_RED}Failed to install $1 ${COLOR_NC}"
      exit 1
    }
  fi
}

function check_python_dependency() {
  module_check_and_install protobuf-init
  module_check_and_install grpcio
  module_check_and_install grpcio-tools
}


echo "check python environments"
check_python_dependency

echo "create directories for compile(python)"
prepare_for_compile


IFS=',' read -ra arr <<<"${module}"
for name in "${arr[@]}"; do
  ln -sf "${dir_api_source}/${name}" "${dir_api_target}/${name}"
  # use the command for help, python -m grpc.tools.protoc -h
  # 1、使用protoc编译protobuf文件只会生成相应编程语言的protobuf文件，而使用grpc_tools.protoc编译protobuf文件会生成相应编程语言的
  # protobuf文件和与gRPC相关的服务端和客户端代码
  # 2、如果需要在生成的代码里面自动带上__init__.py文件需要带上参数init_python_out
  if [[ ${name} == "common" ]]; then
    if ! python3 -m grpc_tools.protoc -I"${dir_compile}" \
      --python_out="${dir_output}" \
      --pyi_out="${dir_output}" \
      --init_python_out="${dir_output}" \
      --init_python_opt=imports=protobuf \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=python ${COLOR_NC}"
      exit 1
    fi
  else
    if ! python3 -m grpc_tools.protoc -I"${dir_compile}" \
      --python_out="${dir_output}" \
      --pyi_out="${dir_output}" \
      --grpc_python_out="${dir_output}" \
      --init_python_out="${dir_output}" \
      --init_python_opt=imports=protobuf+grpcio \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=python ${COLOR_NC}"
      exit 1
    fi
  fi
done
echo -e "${COLOR_BLUE}Finished of compile with type=${app_type}, language=python ${COLOR_NC}"