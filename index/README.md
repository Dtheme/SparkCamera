# SparkCamera 代码索引

这个目录包含了 SparkCamera 项目的代码索引，用于快速查找和导航代码。

## 目录结构

- `index.json`: 存储代码索引数据
- `generate_index.py`: 生成和更新索引的 Python 脚本
- `README.md`: 本说明文件

## 索引内容

索引包含以下内容:

1. 类和结构体
2. 协议
3. 扩展
4. 重要方法
5. 属性
6. 枚举
7. 常量

## 使用方法

1. 更新索引:
```bash
python3 generate_index.py
```

2. 查看索引:
直接打开 `index.json` 文件

## 索引格式

```json
{
    "classes": {
        "类名": {
            "file": "文件路径",
            "line": 行号,
            "methods": ["方法列表"],
            "properties": ["属性列表"]
        }
    },
    "protocols": {
        "协议名": {
            "file": "文件路径",
            "line": 行号,
            "methods": ["方法列表"]
        }
    },
    "extensions": {
        "扩展名": {
            "file": "文件路径",
            "line": 行号,
            "methods": ["方法列表"]
        }
    }
}
``` 