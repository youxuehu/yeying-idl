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
  dir_output="${directory_target}/${app_type}/java"
  mkdir -p "${dir_output}"

  # 需要编译的proto文件所在位置
  dir_compile="${directory_target}/proto"
  mkdir -p "${dir_compile}"

  # 源proto文件所在位置
  dir_api_source="${directory_runtime}/yeying/api"
  dir_api_target="${dir_compile}/yeying/api"
  mkdir -p "${dir_api_target}"
}

echo "create directories for compile(java)"
prepare_for_compile

# 字符串分割，解析成数组
IFS=',' read -ra arr <<<"${module}"
# 遍历数组
for name in "${arr[@]}"; do
  set -x
  echo "Compile client module=${name} for java"
  echo "dir_api_source=${dir_api_source}"
  echo "dir_api_target=${dir_api_target}"
  if [ ! -d "${dir_api_target}/apps" ]; then
    mkdir -p "${dir_api_target}/apps"
  fi

  ln -sf "${dir_api_source}/${name}" "${dir_api_target}/${name}"

  if ! protoc --proto_path="${dir_compile}" \
    --java_out="${dir_output}" \
    --grpc-java_out="${dir_output}" \
    "${dir_api_target}/${name}"/*.proto; then
    echo -e "${COLOR_RED}Fail to compile module=${name} for type=${app_type}, language=java ${COLOR_NC}"
    exit 1
  fi
  set +x
done
echo -e "${COLOR_BLUE}Finished of compile with type=${app_type}, language=java ${COLOR_NC}"
