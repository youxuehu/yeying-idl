# yeying-idl
管理了夜莺社区所有的proto文件，protoc是一个用于定义和生成数据结构的工具套件，主要用于序列化和反序列化数据，参考[规范](https://protobuf.dev/programming-guides/style/)

# 支持的模块
## common
定义了通用消息和类型的接口

## plugin
定义了插件相关的接口

## store
定义了分散式仓库相关的接口

## robot
定义了对话机器人相关的接口

## topic
定义了话题相关的接口

## article
定义了文章相关的接口

# 支持的协议
使用`proto3`选项会生成支持HTTP/2的代码，而使用`http`选项会生成支持HTTP/1.x的代码。 在`http`选项中，还可以添加更多的配置信息，如`http.get`、
`http.post`、`http.put`等指令，来定义接口的HTTP方法和路径。

如果要提供http服务，需要开发gateway提供服务，当前只提供grpc服务。

# 定义消息和RPC的规范：
## 使用package
坚持使用package关键字，其好处如下：
1. 组织和管理消息和服务：通过将它们归属到特定的包中，可以更好地组织和管理它们。
2. 防止命名冲突：不同package下的消息和服务可以使用相同的名称，因为它们在不同的包命名空间中。
3. 代码生成工具支持：代码生成工具可以根据指定的package生成相应的包结构，使得生成的代码更具可读性和可维护性。