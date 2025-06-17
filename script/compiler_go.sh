#!/usr/bin/env bash


COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_NC='\033[0m'

directory_runtime="$1"
app_type="$2"
module="$3"
gateway="$4"

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "${COLOR_RED}Usage: $0 <directory_runtime> <app_type> <module> <gateway>${COLOR_NC}"
    exit 1
fi

# gateway 必须是 0 或 1
if [[ ! "$4" =~ ^(0|1)$ ]]; then
    echo "${COLOR_RED}Error: gateway must be 0 or 1${COLOR_NC}"
    exit 1
fi

directory_target="${directory_runtime}"/target

function prepare_for_compile() {
  # 编译结构输出目录
  dir_output="${directory_target}/${app_type}/go"
  mkdir -p "${dir_output}"

  # 需要编译的proto文件所在位置
  dir_compile="${directory_target}/proto"
  mkdir -p "${dir_compile}"

  # 源proto文件所在位置
  dir_api_source="${directory_runtime}/yeying/api"
  dir_api_target="${dir_compile}/yeying/api"
  mkdir -p "${dir_api_target}"
}

echo "create directories for compile(go)"
prepare_for_compile

# 指定编译依赖的proto，grpc使用的http2协议，浏览器使用http1.x协议，尽可能的兼容http1.x，使用google提供protoc生成http1.x的代码，但是
# 在实际项目中需要依赖对应的库，go的库是google.golang.org/genproto
# 从module参数中获得需要编译的模块，编译模块以逗号隔开, 参数里面的模块顺序也代表了编译的顺序
IFS=',' read -ra arr <<<"${module}"
for name in "${arr[@]}"; do
  ln -sf "${dir_api_source}/${name}" "${dir_api_target}/${name}"
  echo "Compile module=${name}"

  # 在哪个路径下搜索.proto文件, 可以用-I<path>，也可以使用--proto_path=<path>
  if [ "${gateway}" -eq 0 ]; then
    if ! protoc --proto_path="${dir_compile}" \
      --go_out="${dir_output}" \
      --go-grpc_out="${dir_output}" \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=go ${COLOR_NC}"
      exit 1
    fi
  else
    if ! protoc --proto_path="${dir_compile}" \
      --go_out="${dir_output}" \
      --grpc-gateway_out="${dir_output}" --grpc-gateway_opt logtostderr=true \
      --grpc-gateway_opt generate_unbound_methods=true \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=go ${COLOR_NC}"
      exit 1
    fi
  fi
done
echo -e "${COLOR_BLUE}Finished of compile with type=${app_type}, language=go ${COLOR_NC}"