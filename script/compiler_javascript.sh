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

# app_type 必须是 browser 或 nodejs
if [[ ! "$app_type" =~ ^(browser|nodejs)$ ]]; then
    echo -e "${COLOR_RED}Error: app_type must be 'browser' or 'nodejs'${COLOR_NC}"
    exit 1
fi

directory_target="${directory_runtime}"/target

function prepare_for_compile() {
  # 编译结构输出目录
  dir_output="${directory_target}/${app_type}/javascript"
  mkdir -p "${dir_output}"

  # 需要编译的proto文件所在位置
  dir_compile="${directory_target}/proto"
  mkdir -p "${dir_compile}"

  # 源proto文件所在位置
  dir_api_source="${directory_runtime}/yeying/api"
  dir_api_target="${dir_compile}/yeying/api"
  mkdir -p "${dir_api_target}"
}

# 安装浏览器插件
function install_browser_plugins() {
  if ! command -v protoc-gen-js &>/dev/null; then
    echo -e "${COLOR_BLUE}Installing protoc-gen-js...${COLOR_NC}"
    npm install -g protoc-gen-js --quiet || {
      echo -e "${COLOR_RED}Failed to install protoc-gen-js${COLOR_NC}"
      exit 1
    }
  fi

  if ! command -v protoc-gen-grpc-web &>/dev/null; then
    echo -e "${COLOR_BLUE}Installing protoc-gen-grpc-web...${COLOR_NC}"
    npm install -g protoc-gen-grpc-web --quiet || {
      echo -e "${COLOR_RED}Failed to install protoc-gen-grpc-web${COLOR_NC}"
      exit 1
    }
  fi
}

# 安装 Node.js 插件
function install_nodejs_plugins() {
  if ! command -v grpc_tools_node_protoc_plugin &>/dev/null; then
    echo -e "${COLOR_BLUE}Installing grpc-tools...${COLOR_NC}"
    npm install -g grpc-tools --quiet || {
      echo -e "${COLOR_RED}Failed to install grpc-tools${COLOR_NC}"
      exit 1
    }
  fi
}


echo "create directories for compile(javascript)"
prepare_for_compile

if [ "${app_type}" == "browser" ]; then
  install_browser_plugins

  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    echo "Compile client module=${name} for browser"
    ln -s "${dir_api_source}/${name}" "${dir_api_target}/${name}"
    if [[ ${name} == "llm" ]]; then
      echo "Compile module=${name} to text"
      # grpcweb和grpcwebtext的本质区别是在接受服务器的流式响应时，grpcweb会转变为非流式的形式，一致性收所有消息。
      if ! protoc --proto_path="${dir_compile}" \
        --js_out=import_style=commonjs,binary:"${dir_output}" \
        --grpc-web_out=import_style=commonjs,mode=grpcwebtext:"${dir_output}" \
        "${dir_api_target}/${name}"/*.proto; then
        echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=javascript ${COLOR_NC}"
        exit 1
      fi
    else
      echo "Compile module=${name} to binary"
      if ! protoc --proto_path="${dir_compile}" \
        --js_out=import_style=commonjs,binary:"${dir_output}" \
        --grpc-web_out=import_style=commonjs,mode=grpcweb:"${dir_output}" \
        "${dir_api_target}/${name}"/*.proto; then
        echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=javascript ${COLOR_NC}"
        exit 1
      fi
    fi
  done
elif [ "${app_type}" == "nodejs" ]; then
  install_nodejs_plugins

  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    echo "Compile client module=${name} for nodejs"
    ln -s "${dir_api_source}/${name}" "${dir_api_target}/${name}"
    if ! protoc --proto_path="${dir_compile}" \
      --js_out=import_style=commonjs,binary:"${dir_output}" \
      --grpc_out=grpc_js:"${dir_output}" \
      --plugin=protoc-gen-grpc=$(which grpc_tools_node_protoc_plugin) \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=javascript ${COLOR_NC}"
      exit 1
    fi
  done
fi

echo -e "${COLOR_BLUE}Finished of compile with type=${app_type}, language=javascript ${COLOR_NC}"