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
  dir_output="${directory_target}/${app_type}/typescript"
  mkdir -p "${dir_output}"

  # 需要编译的proto文件所在位置
  dir_compile="${directory_target}/proto"
  mkdir -p "${dir_compile}"

  # 源proto文件所在位置
  dir_api_source="${directory_runtime}/yeying/api"
  dir_api_target="${dir_compile}/yeying/api"
  mkdir -p "${dir_api_target}"
}

# 安装 protoc 插件
function install_plugin_browser() {
  if ! command -v protoc-gen-es &>/dev/null; then
    echo -e "${COLOR_BLUE}Installing @bufbuild/protoc-gen-es...${COLOR_NC}"
    npm install -g @bufbuild/protoc-gen-es --quiet
  else
    echo -e "${COLOR_BLUE}@bufbuild/protoc-gen-es is already installed.${COLOR_NC}"
  fi
}

function install_plugin_nodejs() {
  if ! command -v protoc-gen-ts_proto &>/dev/null; then
    echo -e "${COLOR_BLUE}Installing ts-proto...${COLOR_NC}"
    npm install -g ts-proto --quiet
  else
    echo -e "${COLOR_BLUE}ts-proto is already installed.${COLOR_NC}"
  fi
}


echo "create directories for compile(typescript)"
prepare_for_compile


if [ "${app_type}" == "browser" ]; then
  install_plugin_browser

  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    echo "Compile client module=${name} for browser"
    ln -sf "${dir_api_source}/${name}" "${dir_api_target}/${name}"

    echo -e "${COLOR_BLUE}Compile module=${name} to binary ${COLOR_NC}"
    if ! protoc --proto_path="${dir_compile}" \
      --es_out="${dir_output}" \
      --es_opt=target=ts \
      --es_opt=json_types=true \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=typescript ${COLOR_NC}"
      exit 1
    fi

  done
elif [ "${app_type}" == "nodejs" ]; then
  # Project [ts-proto](https://github.com/stephenh/ts-proto) goes a different way and replaces the built-in CommonJS
  # code generation by a generator that outputs idiomatic TypeScript. reference [sample](https://medium.com/@torsten.schlieder/grpc-with-node-b73f51c54b12)
  install_plugin_nodejs

  IFS=',' read -ra arr <<<"${module}"
  for name in "${arr[@]}"; do
    echo -e "${COLOR_BLUE}Compile client module=${name} for nodejs ${COLOR_NC}"
    ln -sf "${dir_api_source}/${name}" "${dir_api_target}/${name}"
    # esModuleInterop=true
    # 作用：解决默认导入（import foo from 'module'）与 CommonJS 模块的兼容性问题。
    # oneof=unions
    # 作用：为 Protocol Buffers 的 oneof 字段生成 联合类型（Discriminated Union）。
    if ! protoc --proto_path="${dir_compile}" \
      --plugin=protoc-gen-ts_proto=$(which protoc-gen-ts_proto) \
      --ts_proto_out="${dir_output}" \
      --ts_proto_opt=esModuleInterop=true \
      --ts_proto_opt=oneof=unions \
      --ts_proto_opt=outputServices=grpc-js \
      "${dir_api_target}/${name}"/*.proto; then
      echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=typescript ${COLOR_NC}"
      exit 1
    fi
  done
fi

echo -e "${COLOR_BLUE}Finished of compile with type=${app_type}, language=typescript ${COLOR_NC}"