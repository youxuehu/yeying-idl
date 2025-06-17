#!/usr/bin/env bash
# protoc[https://github.com/protocolbuffers/protobuf/releases]
# protoc-gen-ts_proto[https://github.com/stephenh/ts-proto]
#
# grpc_tools_node_protoc[https://github.com/grpc/grpc-node/tree/master/packages/grpc-tools]封装了protoc，以及各种生成客户端和
# 服务端代码的插件:
# 1. protoc-gen-js
# 2.

COLOR_RED='\033[1;31m'
COLOR_BLUE='\033[1;34m'
COLOR_NC='\033[0m'


# before running the script on macos, you should install protobuf with command `brew install protobuf`
base_name="${0##*/}"
directory_script=$(
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
    -m <Specify the module name, such as agent,identity,user,asset,store,certificate or multiple module with comma separated>\n \
    -l <Specify language to generate code, such go,javascript,python,typescript and so on>\n \
    -g <Specify compile with grpc gateway\n \
    " "${base_name}"
    exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

gateway=0
# For macos`s getopt, reference: https://formulae.brew.sh/formula/gnu-getopt
while getopts ":ht:m:l:g" o; do
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
  g)
    gateway=1
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

echo "Generate code for app_type=${app_type} with language=${language}, module=${module}, gateway=${gateway}"
if [ ${gateway} -eq 0 ]; then
  echo -e "${COLOR_BLUE}grpc gateway not open. ${COLOR_NC}"
else
  echo -e "${COLOR_BLUE}grpc gateway open. ${COLOR_NC}"
fi

if [ -z "${app_type}" ]; then
  echo -e "${COLOR_RED}Please specify the app type to generate!${COLOR_NC}"
  usage
fi

if [ -z "${language}" ]; then
  echo -e "${COLOR_RED}Please specify the language to generate!${COLOR_NC}"
  usage
fi


cd "${directory_script}"/.. || exit 1
directory_runtime=$(pwd)


# 编译前清空历史
directory_target="${directory_runtime}"/target
if [ -d "${directory_target}" ]; then
  rm -rf "${directory_target}"
fi
mkdir -p "${directory_target}"
echo -e "clean history comiple directory: ${directory_target}"

if [ "${app_type}" = "server" ] && [ "${language}" = "go" ]; then
  bash "${directory_script}"/compiler_go.sh "${directory_runtime}" "${app_type}" "${module}" "${gateway}"
elif [ "${app_type}" = "server" ] && [ "${language}" = "python" ]; then
  bash "${directory_script}"/compiler_python.sh "${directory_runtime}" "${app_type}" "${module}"
elif [ "${app_type}" = "browser" ] && [ "${language}" = "javascript" ]; then
  bash "${directory_script}"/compiler_javascript.sh "${directory_runtime}" "${app_type}" "${module}"
elif [ "${app_type}" = "nodejs" ] && [ "${language}" = "javascript" ]; then
  bash "${directory_script}"/compiler_javascript.sh "${directory_runtime}" "${app_type}" "${module}"
elif [ "${app_type}" = "browser" ] && [ "${language}" = "typescript" ]; then
  bash "${directory_script}"/compiler_typescript.sh "${directory_runtime}" "${app_type}" "${module}"
elif [ "${app_type}" = "nodejs" ] && [ "${language}" = "typescript" ]; then
  bash "${directory_script}"/compiler_typescript.sh "${directory_runtime}" "${app_type}" "${module}"
elif [ "${app_type}" = "zuoyepigai" ] && [ "${language}" = "java" ]; then
  bash "${directory_script}"/compiler_java.sh "${directory_runtime}" "${app_type}" "${module}"
else
  echo -e "${COLOR_RED}not supported, app type=${app_type}, language=${language}${COLOR_NC}"
  exit 1
fi
echo -e "${COLOR_BLUE}Compile protoc successfully.${COLOR_NC}"
