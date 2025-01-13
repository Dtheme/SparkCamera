#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import re
from typing import Dict, List, Any

class SwiftIndexer:
    def __init__(self):
        self.index = {
            "classes": {},
            "protocols": {},
            "extensions": {},
            "enums": {},
            "structs": {},
            "constants": {}
        }
        
    def parse_file(self, file_path: str) -> None:
        """解析单个 Swift 文件"""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 解析类
        class_pattern = r'class\s+(\w+).*?{'
        for match in re.finditer(class_pattern, content):
            class_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            # 解析方法
            methods = self._parse_methods(content[match.start():])
            
            # 解析属性
            properties = self._parse_properties(content[match.start():])
            
            self.index["classes"][class_name] = {
                "file": file_path,
                "line": line_number,
                "methods": methods,
                "properties": properties
            }
            
        # 解析协议
        protocol_pattern = r'protocol\s+(\w+).*?{'
        for match in re.finditer(protocol_pattern, content):
            protocol_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            methods = self._parse_methods(content[match.start():])
            
            self.index["protocols"][protocol_name] = {
                "file": file_path,
                "line": line_number,
                "methods": methods
            }
            
        # 解析扩展
        extension_pattern = r'extension\s+(\w+).*?{'
        for match in re.finditer(extension_pattern, content):
            extension_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            methods = self._parse_methods(content[match.start():])
            
            self.index["extensions"][extension_name] = {
                "file": file_path,
                "line": line_number,
                "methods": methods
            }
            
        # 解析枚举
        enum_pattern = r'enum\s+(\w+).*?{'
        for match in re.finditer(enum_pattern, content):
            enum_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            cases = self._parse_enum_cases(content[match.start():])
            
            self.index["enums"][enum_name] = {
                "file": file_path,
                "line": line_number,
                "cases": cases
            }
            
        # 解析结构体
        struct_pattern = r'struct\s+(\w+).*?{'
        for match in re.finditer(struct_pattern, content):
            struct_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            properties = self._parse_properties(content[match.start():])
            
            self.index["structs"][struct_name] = {
                "file": file_path,
                "line": line_number,
                "properties": properties
            }
            
        # 解析常量
        constant_pattern = r'let\s+(\w+)\s*:\s*\w+'
        for match in re.finditer(constant_pattern, content):
            constant_name = match.group(1)
            line_number = content[:match.start()].count('\n') + 1
            
            self.index["constants"][constant_name] = {
                "file": file_path,
                "line": line_number
            }
    
    def _parse_methods(self, content: str) -> List[str]:
        """解析方法"""
        method_pattern = r'func\s+(\w+)'
        methods = []
        for match in re.finditer(method_pattern, content):
            methods.append(match.group(1))
        return methods
    
    def _parse_properties(self, content: str) -> List[str]:
        """解析属性"""
        property_pattern = r'(let|var)\s+(\w+)'
        properties = []
        for match in re.finditer(property_pattern, content):
            properties.append(match.group(2))
        return properties
    
    def _parse_enum_cases(self, content: str) -> List[str]:
        """解析枚举 cases"""
        case_pattern = r'case\s+(\w+)'
        cases = []
        for match in re.finditer(case_pattern, content):
            cases.append(match.group(1))
        return cases
    
    def index_directory(self, directory: str) -> None:
        """索引整个目录"""
        for root, _, files in os.walk(directory):
            for file in files:
                if file.endswith('.swift'):
                    file_path = os.path.join(root, file)
                    self.parse_file(file_path)
    
    def save_index(self, output_file: str) -> None:
        """保存索引到文件"""
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.index, f, indent=4, ensure_ascii=False)

def main():
    # 创建索引器
    indexer = SwiftIndexer()
    
    # 获取项目根目录
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # 索引 SparkCamera 目录
    spark_camera_dir = os.path.join(project_root, 'SparkCamera')
    indexer.index_directory(spark_camera_dir)
    
    # 保存索引
    output_file = os.path.join(project_root, 'index', 'index.json')
    indexer.save_index(output_file)
    
    print(f"索引已生成并保存到: {output_file}")

if __name__ == '__main__':
    main() 